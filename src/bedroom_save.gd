extends RefCounted
# Permanent local guest slot. Counts are compatibility views of the v9 ledger.
const Draft = preload("res://src/creator/character_draft.gd")
const Progress = preload("res://src/tutorial_progress.gd")
const Rewards = preload("res://src/monster_rewards.gd")
const Cosmetics = preload("res://src/cosmetic_catalog.gd")
const Resources = preload("res://src/combat_resources.gd")
const Stats = preload("res://src/character_stats.gd")
const APPEARANCE = ["hair", "hair_color", "eyes", "skin"]
const Inventory = preload("res://src/inventory_catalog.gd")
const ShopCatalog = preload("res://src/shop_catalog.gd")
const ITEMS = Inventory.LABELS
const VERSION := 12
const Relic = preload("res://src/hidden_relic.gd")
const MAX_COUNT := 999
const ACTION_SCENES = {
	"read_envelope":"starter_region", "guild_assign_blacksmith":"guild_interior",
	"blacksmith_claim_starter":"blacksmith_interior", "guild_after_blacksmith":"guild_interior",
	"apothecary_claim_gift":"apothecary_interior", "guild_after_apothecary":"guild_interior",
	"general_store_claim_keepsake":"general_store_interior", "guild_after_general_store":"guild_interior",
	"guild_assign_first_combat":"guild_interior", "guild_complete_first_combat":"guild_interior",
	"guild_assign_forest_patrol":"guild_interior", "guild_complete_forest_patrol":"guild_interior"
}
const SUPPLIES := "tutorial.blacksmith.upgrade_supplies"
const MANA_GIFT := "tutorial.apothecary.mana_potions"
const RING_GIFT := "tutorial.general_store.keepsake_ring"
const COMBAT_REWARD := "tutorial.guild.first_combat_gold"
const FOREST_REWARD := "guild.west_forest_patrol.gold"
const FIRST_ENCOUNTER := "south_meadow_slimes"
const COMBAT_EVENT := "first_combat_completed"
const UPGRADE_EVENT := "blacksmith_upgrade_applied"
var path := "user://bedroom_guest_v1.json"
var character: Dictionary = {}
var character_id := ""
var bag := Inventory.empty_inventory()
var chest := Inventory.empty_inventory()
var equipped_weapon := ""
var equipped_armor := ""
var equipped_ring := ""
var chest_gold := 0
var wallet_gold := 0
var wallet_sigils := 0
var progression := Rewards.initial()
var cosmetics := Cosmetics.initial()
var cosmetic_receipts: Dictionary = {}
var hidden_relic: Dictionary = {}
var gold_seeded := false
var item_ledger: Array = []
var upgrade_entitlements: Dictionary = {}
var acquisition_receipts: Dictionary = {}
var purchase_receipts: Dictionary = {}
var tutorial := Progress.initial_state()
var stats := Stats.initial_state()
var combat := Resources.initial_state(stats)
var consumption_receipts: Dictionary = {}
var awake := true
var location := {"scene":"bedroom", "position":[535.0,670.0]}
var error := ""

func draft_from(value: Dictionary):
	var draft = Draft.new()
	draft.set_base(str(value.get("base", "")))
	draft.hair = str(value.get("hair", ""))
	draft.hair_color = str(value.get("hair_color", ""))
	draft.eyes = str(value.get("eyes", ""))
	draft.skin = str(value.get("skin", ""))
	draft.character_class = str(value.get("class", ""))
	draft.username = str(value.get("username", ""))
	return draft

func create(value: Dictionary) -> bool:
	if not character.is_empty() or value.get("base", "") not in ["male", "female"] or not draft_from(value).validate().is_empty():
		return false
	var previous := snapshot()
	character = value.duplicate(true)
	character_id = _new_id()
	hidden_relic = Relic.initial()
	item_ledger = []
	upgrade_entitlements = {}
	acquisition_receipts = {}
	purchase_receipts = {}
	tutorial = Progress.initial_state()
	stats = Stats.initial_state()
	combat = Resources.initial_state(stats)
	consumption_receipts = {}
	chest_gold = 100
	wallet_gold = 0
	wallet_sigils = 0
	progression = Rewards.initial()
	cosmetics = Cosmetics.initial()
	cosmetic_receipts = {}
	gold_seeded = true
	location = {"scene":"bedroom", "position":[535.0,670.0]}
	awake = true
	_add_stack("healing_potion", 5, "chest", "starter", "starter.healing")
	_add_stack(Inventory.starter_weapon(character["class"]), 1, "chest", "starter", "starter.weapon")
	_add_stack(Inventory.starter_armor(character["class"]), 1, "equipped_armor", "starter", "starter.armor")
	_sync_views()
	return _commit(previous)

# Read-only detached view. Class and equipment do not change the core baseline.
func get_stat_summary() -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _stat_failure("invalid_save", "Your local save is not ready to assign stats.")
	return Stats.summary(stats)

func preview_stat_allocation(deltas, expected_revision) -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _stat_failure("invalid_save", "Your local save is not ready to assign stats.")
	var result := Stats.preview_allocation(stats, deltas, expected_revision)
	# Keep candidate state internal; the menu receives detached computed values.
	result.erase("next_state")
	return result

func allocate_stat_points(deltas, expected_revision) -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _stat_failure("invalid_save", "Your local save is not ready to assign stats.")
	var plan := Stats.preview_allocation(stats, deltas, expected_revision)
	if not plan.ok: return plan
	var previous := snapshot()
	stats = plan.next_state.duplicate(true)
	if not _commit(previous): return _stat_failure("save_failed", error)
	var result := Stats.summary(stats)
	result.code = "allocated"
	result.message = "%d stat points assigned." % plan.points_assigned
	result["points_assigned"] = plan.points_assigned
	return result

# Future progression/service boundary, never connected to a menu, debug button,
# tutorial reward, or timer. Only a legitimate earned-level system may call it.
func advance_character_level(target_level, expected_revision) -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _stat_failure("invalid_save", "Your local save is not ready to record a level.")
	var plan := Stats.plan_level_advance(stats, target_level, expected_revision)
	if not plan.ok or plan.get("duplicate", false): return plan
	var previous := snapshot()
	stats = plan.next_state.duplicate(true)
	progression.base_level = int(target_level)
	if not _commit(previous): return _stat_failure("save_failed", error)
	var result := Stats.summary(stats)
	result.code = "level_recorded"
	result.message = "Character level recorded."
	result["points_awarded"] = plan.points_awarded
	return result

# Unconnected future gameplay boundary. A real loot/refill service must verify
# evidence first. Storage-chest open/transfer and tutorial actions never call it.
func record_luck_event(event_id, source_id, kind, refill_id, expected_revision) -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _stat_failure("invalid_save", "Your local save is not ready to record Luck experience.")
	var plan := Stats.plan_luck_event(stats, event_id, source_id, kind, refill_id, expected_revision)
	if not plan.ok or not plan.has("next_state"): return plan
	var previous := snapshot()
	stats = plan.next_state.duplicate(true)
	if not _commit(previous): return _stat_failure("save_failed", error)
	var result := Stats.summary(stats)
	result.code = "luck_recorded"
	result.message = "Earned Luck experience recorded."
	result["duplicate"] = false
	result["luck_xp_awarded"] = plan.luck_xp_awarded
	return result

func _stat_failure(code: String, message: String) -> Dictionary:
	var result := Stats.summary(stats)
	result.ok = false
	result.code = code
	result.message = message
	return result

# Gameplay checkpoint: HP/MP and cooldowns survive scene changes/reload. Failed
# writes restore the entire previous snapshot; the controller rolls back its model.
func commit_combat_resources(value: Dictionary) -> bool:
	if not _valid_live_state() or not Resources.valid(value,stats) or value.revision != combat.revision:
		error = "Combat state changed. Reload before trying again."
		return false
	var previous := snapshot()
	combat = value.duplicate(true)
	combat.revision += 1
	return _commit(previous)

func consume_combat_potion(item_id: String, transaction_id: String, value: Dictionary) -> Dictionary:
	if not _valid_live_state() or not _valid_id(transaction_id): return _failure("invalid_save","Potion use could not be saved safely.")
	if consumption_receipts.has(transaction_id):
		return {"ok":consumption_receipts[transaction_id].item_id == item_id,"duplicate":true,"message":"Potion use was already saved."}
	if item_id not in ["healing_potion","mana_potion"] or not Resources.valid(value,stats) or value.revision != combat.revision: return _failure("invalid_resources","Combat state changed. Try again.")
	if value.hp <= 0: return _failure("defeated","Retry the encounter before using a potion.")
	if value.potion > 0: return _failure("cooldown","Potions are cooling down.")
	var cap := Resources.limits(stats)
	var field := "hp" if item_id == "healing_potion" else "mana"
	if value[field] >= cap[field]: return _failure("full","Your %s is already full. No potion used." % field.to_upper())
	var index := _find_stack(item_id,"bag")
	if index < 0: return _failure("empty","Carry this potion in your bag first.")
	var entry: Dictionary = item_ledger[index]
	var previous := snapshot()
	consumption_receipts[transaction_id] = {"item_id":item_id,"quantity":1,"source":entry.source,"source_id":entry.source_id}
	entry.quantity -= 1
	if entry.quantity == 0: item_ledger.remove_at(index)
	combat = value.duplicate(true)
	combat[field] = minf(cap[field],combat[field] + (40 if field == "hp" else 25))
	combat.potion = 3.0
	combat.revision += 1
	_sync_views()
	if not _commit(previous): return _failure("save_failed",error)
	return {"ok":true,"duplicate":false,"message":"Restored %s. Potion used." % field.to_upper()}

func apply_appearance(value: Dictionary) -> bool:
	if character.is_empty(): return false
	var candidate := character.duplicate(true)
	for key in APPEARANCE:
		if value.has(key): candidate[key] = value[key]
	if not draft_from(candidate).validate().is_empty(): return false
	var previous := snapshot()
	character = candidate
	return _commit(previous)

func transfer(item: String, to_chest: bool) -> bool:
	if character.is_empty() or not ITEMS.has(item): return false
	return _move_item(item, "bag" if to_chest else "chest", "chest" if to_chest else "bag")

func equip(item: String) -> bool:
	if character.is_empty() or not equipped_weapon.is_empty() or not Inventory.can_equip(item, character["class"]): return false
	return _move_item(item, "bag", "equipped_weapon")

func unequip() -> bool:
	if equipped_weapon.is_empty(): return false
	return _move_item(equipped_weapon, "equipped_weapon", "bag")

func equip_ring(item: String = "keepsake_ring") -> bool:
	if character.is_empty() or not equipped_ring.is_empty() or not Inventory.ring_allowed(item): return false
	return _move_item(item, "bag", "equipped_ring")

func unequip_ring() -> bool:
	if equipped_ring.is_empty(): return false
	return _move_item(equipped_ring, "equipped_ring", "bag")

func claim_chest_gold() -> bool:
	if character.is_empty() or location.scene != "bedroom" or chest_gold <= 0: return false
	var previous := snapshot()
	wallet_gold += chest_gold
	chest_gold = 0
	return _commit(previous)

# Trusted compatibility acquisition hook for existing drop/trade/provenance tests.
# It does not execute a purchase or debit gold; the shop UI must use
# purchase_shop_item(), never this hook. Legacy npc_purchase grants stay bound.
func receive_item(item_id: String, quantity: int, source: String, acquisition_id: String) -> bool:
	if item_id == Relic.ITEM: return false
	if character.is_empty() or not ITEMS.has(item_id) or quantity < 1 or quantity > MAX_COUNT or source not in ["world_drop", "trade", "npc_purchase"] or not _valid_id(acquisition_id): return false
	var receipt := {"item_id":item_id, "quantity":quantity, "source":source}
	if acquisition_receipts.has(acquisition_id):
		var existing: Dictionary = acquisition_receipts[acquisition_id]
		return existing.get("item_id") == item_id and existing.get("quantity") == quantity and existing.get("source") == source
	if bag[item_id] + quantity > MAX_COUNT: return false
	var previous := snapshot()
	acquisition_receipts[acquisition_id] = receipt
	_add_stack(item_id, quantity, "bag", source, acquisition_id)
	_sync_views()
	return _commit(previous)

# The service, not the UI, derives the available shop from persisted location.
func get_shop_catalog() -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _shop_failure("invalid_save", "Your local save is not ready to shop.")
	var shop_id := _nearby_shop()
	if shop_id.is_empty(): return _shop_failure("wrong_location", "Speak to the shopkeeper at their counter to shop.")
	return {"ok":true, "code":"shop_available", "message":"", "shop_id":shop_id, "shop_name":ShopCatalog.shop_name(shop_id),
		"stock_policy":ShopCatalog.STOCK_POLICY, "offers":ShopCatalog.entries_for(shop_id), "max_quantity":ShopCatalog.MAX_QUANTITY, "wallet_gold":wallet_gold}

# Untyped arguments are intentional: reject fractions, booleans and non-strings
# rather than accepting GDScript's implicit conversions at this trust boundary.
func purchase_shop_item(item_id, quantity, transaction_id) -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _shop_failure("invalid_save", "Your local save is not ready to shop.")
	if not item_id is String: return _shop_failure("invalid_item", "That item is not sold here.")
	if not _whole(quantity, 1, ShopCatalog.MAX_QUANTITY): return _shop_failure("invalid_quantity", "Choose between 1 and %d items." % ShopCatalog.MAX_QUANTITY)
	if not _valid_id(transaction_id) or transaction_id.length() > ShopCatalog.MAX_TRANSACTION_ID_LENGTH:
		return _shop_failure("invalid_transaction_id", "The purchase reference is invalid. Reopen the shop and try again.")
	var shop_id := _nearby_shop()
	if shop_id.is_empty(): return _shop_failure("wrong_location", "Speak to the shopkeeper at their counter to buy this item.")
	if purchase_receipts.has(transaction_id):
		var prior: Dictionary = purchase_receipts[transaction_id]
		if prior.shop_id != shop_id or prior.item_id != item_id or prior.quantity != quantity:
			return _shop_failure("transaction_conflict", "That purchase reference already belongs to a different purchase.")
		return _shop_success(prior, true)
	var unit_price := ShopCatalog.unit_price(shop_id, item_id)
	if unit_price <= 0: return _shop_failure("invalid_item", "That item is not sold here.")
	var acquisition_id: String = "shop:" + transaction_id
	if acquisition_receipts.has(acquisition_id): return _shop_failure("transaction_conflict", "That purchase reference is already in use. Reopen the shop and try again.")
	var count := int(quantity)
	var total_price := unit_price * count
	if wallet_gold < total_price: return _shop_failure("insufficient_gold", "You need %d gold, but have %d." % [total_price, wallet_gold])
	if bag[item_id] + count > MAX_COUNT: return _shop_failure("inventory_full", "Your bag cannot hold that many of this item.")
	var previous := snapshot()
	var receipt := {"transaction_id":transaction_id, "character_id":character_id, "shop_id":shop_id, "item_id":item_id,
		"quantity":count, "unit_price_gold":unit_price, "total_price_gold":total_price, "catalog_revision":ShopCatalog.CURRENT_REVISION}
	wallet_gold -= total_price
	purchase_receipts[transaction_id] = receipt
	acquisition_receipts[acquisition_id] = {"item_id":item_id, "quantity":count, "source":"npc_purchase"}
	_add_stack(item_id, count, "bag", "npc_purchase", acquisition_id)
	_sync_views()
	if not _commit(previous): return _shop_failure("save_failed", error)
	return _shop_success(receipt, false)

func _nearby_shop() -> String:
	var shop_id := ShopCatalog.shop_for_scene(str(location.get("scene", "")))
	return shop_id if not shop_id.is_empty() and _near_interaction(ShopCatalog.scene_for(shop_id)) else ""

func _shop_failure(code: String, message: String) -> Dictionary:
	return {"ok":false, "duplicate":false, "code":code, "message":message, "receipt":{}}

func _shop_success(receipt: Dictionary, duplicate: bool) -> Dictionary:
	return {"ok":true, "duplicate":duplicate, "code":"already_purchased" if duplicate else "purchased",
		"message":"This purchase was already saved." if duplicate else "Purchased %d %s for %d gold." % [receipt.quantity, str(ITEMS[receipt.item_id]).to_lower(), receipt.total_price_gold], "receipt":receipt.duplicate(true)}

func perform_tutorial_action(action: String) -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _failure("invalid_save", "Your local save is not ready for this action.")
	if not ACTION_SCENES.has(action): return _failure("unknown_action", "This tutorial action is not available.")
	var plan: Dictionary = Progress.plan_action(tutorial, action, _receipt(action), {"character_class":character["class"]})
	if not plan.ok or plan.duplicate: return plan
	if not _near_interaction(ACTION_SCENES[action]): return _failure("wrong_location", "Visit the person or place named in your current objective.")
	if action == "blacksmith_claim_starter" and _starter_weapon_index() < 0:
		return _failure("missing_starter_weapon", "Your original starter weapon could not be found. Your save has not been changed.")
	var previous := snapshot()
	for reward in plan.rewards:
		if not _apply_reward(reward):
			_restore(previous)
			return _failure("invalid_reward", "The tutorial reward could not be applied safely.")
	tutorial = plan.next_state.duplicate(true)
	_sync_views()
	if not _commit(previous): return _failure("save_failed", error)
	return plan

# Trusted gameplay boundary: called only by the encounter controller after all
# assigned enemies die. Dialogue has no event dispatch path. The event and clear
# flag are the same persisted receipt, so a crash/reload cannot pay twice.
func encounter_is_complete(encounter_id: String) -> bool:
	var event: String = {FIRST_ENCOUNTER:COMBAT_EVENT,"west_forest_patrol":"forest_patrol_completed"}.get(encounter_id,"")
	return not event.is_empty() and tutorial.event_receipts.has(event)

func record_encounter_victory(encounter_id: String) -> bool:
	error = ""
	if character.is_empty() or not _valid_live_state():
		error = "Your local save is not ready to record this encounter."
		return false
	if encounter_id not in [FIRST_ENCOUNTER,"west_forest_patrol"]:
		error = "That encounter is not part of your assignment."
		return false
	if encounter_is_complete(encounter_id): return true
	if location.scene != "starter_region":
		error = "Return to the South Meadow to finish this assignment."
		return false
	var event := COMBAT_EVENT if encounter_id == FIRST_ENCOUNTER else "forest_patrol_completed"
	var plan := Progress.plan_event(tutorial, event, _receipt(event), {"encounter_id":encounter_id})
	if not plan.ok:
		error = plan.message
		return false
	var previous := snapshot()
	tutorial = plan.next_state.duplicate(true)
	return _commit(previous)

func apply_tutorial_weapon_upgrade() -> Dictionary:
	if character.is_empty() or not _valid_live_state(): return _failure("invalid_save", "Your local save is not ready for this action.")
	if tutorial.event_receipts.has(UPGRADE_EVENT):
		return Progress.plan_event(tutorial, UPGRADE_EVENT, _receipt(UPGRADE_EVENT))
	if not _near_interaction("blacksmith_interior"): return _failure("wrong_location", "Return to the blacksmith for the upgrade lesson.")
	var index := _starter_weapon_index()
	if index < 0: return _failure("missing_starter_weapon", "Your original starter weapon could not be found. Your save has not been changed.")
	var weapon: Dictionary = item_ledger[index]
	if weapon.container == "chest": return _failure("weapon_in_chest", "Collect your starter weapon from the chest first, then bring it to the blacksmith.")
	var entitlement = upgrade_entitlements.get(SUPPLIES, {})
	if entitlement.get("uses", 0) != 1 or weapon.upgrade_level != 0:
		return _failure("missing_supplies", "Speak to the blacksmith for your free upgrade supplies first.")
	var plan: Dictionary = Progress.plan_event(tutorial, UPGRADE_EVENT, _receipt(UPGRADE_EVENT), {"character_class":character["class"], "item_id":weapon.item_id, "from_level":weapon.upgrade_level, "to_level":1, "supplies_consumed":true})
	if not plan.ok or plan.duplicate: return plan
	var previous := snapshot()
	weapon.upgrade_level = 1
	entitlement.uses = 0
	tutorial = plan.next_state.duplicate(true)
	if not _commit(previous): return _failure("save_failed", error)
	return plan

func get_item_instances(item_id: String = "", container: String = "") -> Array:
	var result: Array = []
	for entry in item_ledger:
		if (item_id.is_empty() or entry.item_id == item_id) and (container.is_empty() or entry.container == container): result.append(entry.duplicate(true))
	return result

func get_item_details(item_id: String, container: String = "bag") -> Dictionary:
	var index := _find_stack(item_id, container)
	if index < 0: return {}
	var result: Dictionary = item_ledger[index].duplicate(true)
	result["instance_id"] = result.id
	result["label"] = str(ITEMS.get(item_id, item_id)) + (" +%d" % result.upgrade_level if result.upgrade_level > 0 else "")
	return result

func weapon_upgrade_level(container: String = "equipped_weapon") -> int:
	if character.is_empty(): return 0
	var details := get_item_details(Inventory.starter_weapon(character["class"]), container)
	return int(details.get("upgrade_level", 0))

func can_transfer_instance(instance_id: String, recipient_character_id: String) -> bool:
	if recipient_character_id.is_empty(): return false
	for entry in item_ledger:
		if entry.id == instance_id:
			return entry.owner_id == character_id and (entry.binding == "unbound" or recipient_character_id == character_id)
	return false

func snapshot() -> Dictionary:
	return {"version":VERSION, "hidden_relic":hidden_relic.duplicate(true), "tutorial_chest_seeded":true, "character":character.duplicate(true), "character_id":character_id,
		"bag":bag.duplicate(true), "chest":chest.duplicate(true), "equipped_weapon":equipped_weapon, "equipped_armor":equipped_armor, "equipped_ring":equipped_ring,
		"chest_gold":chest_gold, "wallet_gold":wallet_gold, "wallet_sigils":wallet_sigils, "progression":progression.duplicate(true), "cosmetics":cosmetics.duplicate(true), "cosmetic_receipts":cosmetic_receipts.duplicate(true), "gold_seeded":gold_seeded, "item_ledger":item_ledger.duplicate(true),
		"upgrade_entitlements":upgrade_entitlements.duplicate(true), "acquisition_receipts":acquisition_receipts.duplicate(true), "purchase_receipts":purchase_receipts.duplicate(true), "tutorial":tutorial.duplicate(true), "stats":stats.duplicate(true), "combat":combat.duplicate(true), "consumption_receipts":consumption_receipts.duplicate(true), "awake":awake, "location":location.duplicate(true)}

func save() -> bool:
	error = ""
	if not _valid_live_state():
		error = "Local inventory, tutorial, or stat state is invalid. Your previous save is unchanged."
		return false
	return _write_snapshot(snapshot())

func load_saved() -> bool:
	if not FileAccess.file_exists(path): return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return _load_error()
	var data = parser.data
	if not data is Dictionary or not _whole(data.get("version"), 1, VERSION): return _load_error()
	var previous := snapshot()
	if int(data.version) == VERSION:
		if not _valid_snapshot(data): return _load_error()
		_restore(data)
		error = ""
		return true
	var migrated := _migrate(data)
	if migrated.is_empty() or not _valid_snapshot(migrated): return _load_error()
	# Validate and write the candidate before replacing the live session.
	if not _write_snapshot(migrated):
		_restore(previous)
		return false
	_restore(migrated)
	error = ""
	return true

func valid_location(value) -> bool:
	if not value is Dictionary or value.get("scene", "") not in ["bedroom", "starter_region", "guild_interior", "blacksmith_interior", "apothecary_interior", "general_store_interior"]: return false
	var point = value.get("position")
	if not point is Array or point.size() != 2: return false
	for number in point:
		if not (number is float or number is int) or not is_finite(float(number)): return false
	var bounds := Vector2(4608,3072) if value.scene == "starter_region" else Vector2(1536,1024)
	return point[0] >= 0 and point[0] <= bounds.x and point[1] >= 0 and point[1] <= bounds.y

func set_location(scene: String, point: Vector2) -> bool:
	var next := {"scene":scene, "position":[point.x, point.y]}
	if not valid_location(next): return false
	var previous := snapshot()
	location = next
	return _commit(previous)

func _move_item(item: String, source: String, target: String) -> bool:
	if not _valid_live_state(): return false
	var index := _find_stack(item, source)
	if index < 0 or (target in ["bag", "chest"] and self.get(target)[item] >= MAX_COUNT): return false
	var previous := snapshot()
	var entry: Dictionary = item_ledger[index]
	if entry.quantity == 1:
		entry.container = target
	else:
		entry.quantity -= 1
		var split := entry.duplicate(true)
		split.id = _new_id()
		split.quantity = 1
		split.container = target
		item_ledger.append(split)
	_sync_views()
	return _commit(previous)

func _find_stack(item: String, container: String) -> int:
	# Prefer the upgraded instance when a count view contains mixed provenance.
	var found := -1
	for index in range(item_ledger.size()):
		var entry: Dictionary = item_ledger[index]
		if entry.item_id == item and entry.container == container and entry.owner_id == character_id:
			if found < 0 or entry.upgrade_level > item_ledger[found].upgrade_level: found = index
	return found

func _starter_weapon_index() -> int:
	for index in range(item_ledger.size()):
		var entry: Dictionary = item_ledger[index]
		if entry.item_id == Inventory.starter_weapon(character["class"]) and entry.source == "starter" and entry.source_id == "starter.weapon" and entry.owner_id == character_id: return index
	return -1

func _add_stack(item: String, quantity: int, container: String, source: String, source_id: String) -> void:
	item_ledger.append({"id":_new_id(), "item_id":item, "quantity":quantity, "container":container, "owner_id":character_id, "binding":Inventory.binding_for_source(source), "source":source, "source_id":source_id, "upgrade_level":0})

func _sync_views() -> void:
	bag = Inventory.empty_inventory()
	chest = Inventory.empty_inventory()
	equipped_weapon = ""
	equipped_armor = ""
	equipped_ring = ""
	for entry in item_ledger:
		if entry.container == "bag": bag[entry.item_id] += entry.quantity
		elif entry.container == "chest": chest[entry.item_id] += entry.quantity
		else: set(entry.container, entry.item_id)

func _receipt(action: String) -> String:
	return "tutorial:" + character_id + ":" + action

func _apply_reward(reward: Dictionary) -> bool:
	if reward.get("binding") != "character": return false
	if reward.get("receipt_id") == FOREST_REWARD:
		if reward.get("source") != "guild" or reward.get("kind") != "gold" or reward.get("count") != 40 or tutorial.reward_receipts.has(FOREST_REWARD): return false
		wallet_gold += 40
		return true
	if reward.get("source") != "tutorial": return false
	if reward.get("receipt_id") == COMBAT_REWARD:
		if reward.get("kind") != "gold" or reward.get("count") != 25 or tutorial.reward_receipts.has(COMBAT_REWARD): return false
		wallet_gold += 25
		return true
	if reward.get("receipt_id") == SUPPLIES:
		if reward.get("kind") != "upgrade_entitlement" or reward.get("entitlement_id") != "tutorial_weapon_plus_one" or reward.get("uses") != 1 or reward.get("target_item_id") != Inventory.starter_weapon(character["class"]) or reward.get("target_level") != 1 or upgrade_entitlements.has(SUPPLIES): return false
		upgrade_entitlements[SUPPLIES] = {"owner_id":character_id, "uses":1, "target_item_id":reward.target_item_id, "target_level":1}
		return true
	var item := "mana_potion" if reward.get("receipt_id") == MANA_GIFT else ("keepsake_ring" if reward.get("receipt_id") == RING_GIFT else "")
	var quantity := 5 if item == "mana_potion" else 1
	if item.is_empty() or reward.get("kind") != "item" or reward.get("item_id") != item or reward.get("count") != quantity or bag[item] + quantity > MAX_COUNT: return false
	_add_stack(item, quantity, "bag", reward.receipt_id, reward.receipt_id)
	return true

func _commit(previous: Dictionary) -> bool:
	if save(): return true
	_restore(previous)
	return false

func _write_snapshot(data: Dictionary) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "Couldn't save locally. Your previous save is unchanged."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
		error = "Couldn't finish saving locally. Try again."
		return false
	return true

func _restore(data: Dictionary) -> void:
	for key in ["hidden_relic", "character", "character_id", "bag", "chest", "equipped_weapon", "equipped_armor", "equipped_ring", "chest_gold", "wallet_gold", "wallet_sigils", "progression", "cosmetics", "cosmetic_receipts", "gold_seeded", "item_ledger", "upgrade_entitlements", "acquisition_receipts", "purchase_receipts", "tutorial", "stats", "combat", "consumption_receipts", "awake", "location"]:
		var value = data[key]
		set(key, value.duplicate(true) if value is Dictionary or value is Array else value)

func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false, "duplicate":false, "code":code, "message":message, "next_state":tutorial.duplicate(true), "rewards":[]}

func _load_error() -> bool:
	error = "Local save could not be read safely. It has not been overwritten."
	return false

func _valid_live_state() -> bool:
	return _valid_snapshot(snapshot())

static func _new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func _valid_id(value) -> bool:
	return value is String and not value.strip_edges().is_empty() and value == value.strip_edges() and value.length() <= 128

static func _whole(value, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and value == floor(float(value))

func _valid_snapshot(data: Dictionary) -> bool:
	if not Relic.valid(data.get("hidden_relic")): return false
	if not _whole(data.get("version"), VERSION, VERSION) or data.get("tutorial_chest_seeded") != true or data.get("gold_seeded") != true: return false
	var hero = data.get("character")
	if not hero is Dictionary or hero.get("base", "") not in ["male", "female"] or not draft_from(hero).validate().is_empty(): return false
	if not _valid_id(data.get("character_id")) or not valid_location(data.get("location")) or data.get("awake") != true: return false
	if not _whole(data.get("chest_gold"), 0, 100) or not _whole(data.get("wallet_gold"), 0, 190): return false
	var gold_spent := _verified_purchase_total(data)
	if not data.get("tutorial") is Dictionary or not Progress.validate_state(data.tutorial): return false
	if not Rewards.valid(data.get("progression")) or not _valid_cosmetics(data): return false
	var earned_gold := (25 if data.tutorial.reward_receipts.has(COMBAT_REWARD) else 0) + (40 if data.tutorial.reward_receipts.has(FOREST_REWARD) else 0)
	if gold_spent < 0 or data.chest_gold + data.wallet_gold + gold_spent != 100 + earned_gold + Rewards.totals(data.progression).gold: return false
	if not Stats.validate_state(data.get("stats")) or not Resources.valid(data.get("combat"), data.stats): return false
	if not data.get("consumption_receipts") is Dictionary: return false
	if data.stats.level != Rewards.summary(data.progression).level: return false
	for receipt_kind in ["action_receipts", "event_receipts"]:
		for action in data.tutorial[receipt_kind]:
			if data.tutorial[receipt_kind][action].id != "tutorial:" + data.character_id + ":" + action: return false
	for field in ["bag", "chest"]:
		if not _valid_counts(data.get(field), ITEMS.keys(), true): return false
	for field in ["equipped_weapon", "equipped_armor", "equipped_ring"]:
		if not data.get(field) is String: return false
	if not data.equipped_weapon.is_empty() and not Inventory.can_equip(data.equipped_weapon, hero["class"]): return false
	if not Inventory.armor_allowed(data.equipped_armor, hero["class"]): return false
	if not data.equipped_ring.is_empty() and not Inventory.ring_allowed(data.equipped_ring): return false
	if not data.get("item_ledger") is Array or data.item_ledger.size() > 20000 or not data.get("acquisition_receipts") is Dictionary: return false
	var expected := {"bag":Inventory.empty_inventory(), "chest":Inventory.empty_inventory(), "equipped_weapon":"", "equipped_armor":"", "equipped_ring":""}
	var seen := {}
	var source_totals := {}
	var upgraded_starters := 0
	for entry in data.item_ledger:
		if not entry is Dictionary or entry.size() != 9: return false
		if not _valid_id(entry.get("id")) or seen.has(entry.id) or entry.get("owner_id") != data.character_id: return false
		seen[entry.id] = true
		if not entry.get("item_id") is String or not entry.get("source") is String or not _valid_id(entry.get("source_id")): return false
		if not _whole(entry.get("quantity"), 1, MAX_COUNT) or not _whole(entry.get("upgrade_level"), 0, 1): return false
		if entry.get("container") not in expected or entry.get("binding") != Inventory.binding_for_source(entry.source): return false
		if entry.container in ["bag", "chest"]:
			if not ITEMS.has(entry.item_id): return false
			expected[entry.container][entry.item_id] += entry.quantity
			if expected[entry.container][entry.item_id] > MAX_COUNT: return false
		else:
			if entry.quantity != 1 or not expected[entry.container].is_empty(): return false
			if entry.container == "equipped_weapon" and not Inventory.can_equip(entry.item_id, hero["class"]): return false
			if entry.container == "equipped_armor" and not Inventory.armor_allowed(entry.item_id, hero["class"]): return false
			if entry.container == "equipped_ring" and not Inventory.ring_allowed(entry.item_id): return false
			expected[entry.container] = entry.item_id
		if entry.source == "starter":
			var starter_items := {"starter.weapon":Inventory.starter_weapon(hero["class"]), "starter.armor":Inventory.starter_armor(hero["class"]), "starter.healing":"healing_potion"}
			if not starter_items.has(entry.source_id) or entry.item_id != starter_items[entry.source_id]: return false
			if entry.upgrade_level > 0:
				if entry.source_id != "starter.weapon": return false
				upgraded_starters += int(entry.quantity)
		elif entry.source == Relic.SOURCE:
			if entry.item_id != Relic.ITEM or entry.source_id != Relic.SOURCE_ID or entry.quantity != 1 or entry.upgrade_level != 0: return false
		elif entry.source == "legacy_unattributed":
			if entry.source_id != "legacy:" + entry.item_id or entry.upgrade_level != 0 or entry.container == "equipped_armor": return false
		elif entry.source in [MANA_GIFT, RING_GIFT]:
			if entry.source_id != entry.source or entry.item_id != ("mana_potion" if entry.source == MANA_GIFT else "keepsake_ring") or entry.upgrade_level != 0: return false
		elif entry.source in ["world_drop", "trade", "npc_purchase"]:
			var acquisition = data.acquisition_receipts.get(entry.source_id)
			if not acquisition is Dictionary or acquisition.get("item_id") != entry.item_id or acquisition.get("source") != entry.source or entry.upgrade_level != 0: return false
		else: return false
		if entry.item_id == Relic.ITEM and entry.source != Relic.SOURCE: return false
		var key: String = entry.source + ":" + entry.source_id
		source_totals[key] = source_totals.get(key, 0) + entry.quantity
	for consumption_id in data.consumption_receipts:
		var used = data.consumption_receipts[consumption_id]
		if not _valid_id(consumption_id) or not used is Dictionary or used.size() != 4: return false
		if used.get("item_id") not in ["healing_potion","mana_potion"] or used.get("quantity") != 1 or used.quantity is bool or not _valid_id(used.get("source_id")): return false
		var source = used.get("source")
		if source == "starter":
			if used.source_id != "starter.healing" or used.item_id != "healing_potion": return false
		elif source == MANA_GIFT:
			if used.source_id != MANA_GIFT or used.item_id != "mana_potion": return false
		elif source == "legacy_unattributed":
			if used.source_id != "legacy:" + used.item_id: return false
		elif source in ["world_drop","trade","npc_purchase"]:
			var grant = data.acquisition_receipts.get(used.source_id,{})
			if grant.get("item_id") != used.item_id or grant.get("source") != source: return false
		else: return false
		var key: String = source + ":" + used.source_id
		source_totals[key] = source_totals.get(key,0) + 1
	for field in expected:
		if field in ["bag", "chest"]:
			for item in ITEMS:
				if data[field][item] != expected[field][item]: return false
		elif data[field] != expected[field]: return false
	if source_totals.get("starter:starter.armor", 0) != 1 or source_totals.get("starter:starter.weapon", 0) > 1 or source_totals.get("starter:starter.healing", 0) > 5: return false
	for acquisition_id in data.acquisition_receipts:
		var receipt = data.acquisition_receipts[acquisition_id]
		if not _valid_id(acquisition_id) or not receipt is Dictionary or receipt.size() != 3 or not ITEMS.has(receipt.get("item_id")) or receipt.get("source") not in ["world_drop", "trade", "npc_purchase"] or not _whole(receipt.get("quantity"), 1, MAX_COUNT): return false
		if source_totals.get(receipt.source + ":" + acquisition_id, 0) != receipt.quantity: return false
	if source_totals.get(Relic.SOURCE+":"+Relic.SOURCE_ID,0) != (1 if data.hidden_relic.claimed else 0): return false
	var rewards: Dictionary = data.tutorial.reward_receipts
	if source_totals.get(MANA_GIFT + ":" + MANA_GIFT, 0) != (5 if rewards.has(MANA_GIFT) else 0): return false
	if source_totals.get(RING_GIFT + ":" + RING_GIFT, 0) != (1 if rewards.has(RING_GIFT) else 0): return false
	var upgraded: bool = data.tutorial.event_receipts.has(UPGRADE_EVENT)
	if upgraded_starters != (1 if upgraded else 0): return false
	if not data.get("upgrade_entitlements") is Dictionary: return false
	if not rewards.has(SUPPLIES): return data.upgrade_entitlements.is_empty()
	if source_totals.get("starter:starter.weapon", 0) != 1 or data.upgrade_entitlements.size() != 1: return false
	var supply = data.upgrade_entitlements.get(SUPPLIES)
	return supply is Dictionary and supply.size() == 4 and supply.get("owner_id") == data.character_id and _whole(supply.get("uses"), 0, 1) and supply.uses == (0 if upgraded else 1) and supply.get("target_item_id") == Inventory.starter_weapon(hero["class"]) and _whole(supply.get("target_level"), 1, 1)

# Every debit must have a known historical price and a matching bound acquisition.
# Ledger quantities and owner/binding checks below independently verify the grant.
func _verified_purchase_total(data: Dictionary) -> int:
	if not data.get("purchase_receipts") is Dictionary or data.purchase_receipts.size() > 100 or not data.get("acquisition_receipts") is Dictionary: return -1
	var spent := 0
	for transaction_id in data.purchase_receipts:
		var receipt = data.purchase_receipts[transaction_id]
		if not _valid_id(transaction_id) or transaction_id.length() > ShopCatalog.MAX_TRANSACTION_ID_LENGTH or not receipt is Dictionary or receipt.size() != 8: return -1
		if not _valid_id(receipt.get("transaction_id")) or not _valid_id(receipt.get("character_id")): return -1
		if receipt.transaction_id != transaction_id or receipt.character_id != data.character_id: return -1
		if not receipt.get("shop_id") is String or not receipt.get("item_id") is String: return -1
		if not _whole(receipt.get("quantity"), 1, ShopCatalog.MAX_QUANTITY) or not _whole(receipt.get("catalog_revision"), 1, 1000000): return -1
		if not _whole(receipt.get("unit_price_gold"), 1, 100) or not _whole(receipt.get("total_price_gold"), 1, 100): return -1
		var price := ShopCatalog.unit_price(receipt.shop_id, receipt.item_id, int(receipt.catalog_revision))
		if price <= 0 or receipt.unit_price_gold != price or receipt.total_price_gold != price * receipt.quantity: return -1
		var acquisition = data.acquisition_receipts.get("shop:" + transaction_id)
		if not acquisition is Dictionary or not acquisition.get("source") is String or not acquisition.get("item_id") is String or not _whole(acquisition.get("quantity"), 1, MAX_COUNT): return -1
		if acquisition.source != "npc_purchase" or acquisition.item_id != receipt.item_id or acquisition.quantity != receipt.quantity: return -1
		spent += int(receipt.total_price_gold)
		if spent > 190: return -1
	return spent

func _valid_counts(value, required: Array, exact: bool) -> bool:
	if not value is Dictionary or (exact and value.size() != required.size()): return false
	for item in required:
		if not _whole(value.get(item), 0, MAX_COUNT): return false
	for item in value:
		if item not in required and not ITEMS.has(item): return false
		if not _whole(value[item], 0, MAX_COUNT): return false
	return true

func _migrate(data: Dictionary) -> Dictionary:
	# v8 already required stats. Missing metadata is corruption, not a fresh slot.
	if int(data.version) >= 8 and not data.has("stats"): return {}
	if int(data.version) >= 9 and not Stats.validate_state(data.stats): return {}
	if int(data.version) >= 10 and (not data.has("combat") or not data.has("consumption_receipts")): return {}
	if data.has("combat") != data.has("consumption_receipts"): return {}
	var economy_fields := 0
	for field in ["progression","wallet_sigils","cosmetics","cosmetic_receipts"]:
		if data.has(field): economy_fields += 1
	if economy_fields not in [0,4]: return {}
	var migrated_stats := Stats.initial_state()
	if data.has("stats"):
		migrated_stats = Stats.migrate_legacy_state(data.stats)
		if migrated_stats.is_empty(): return {}
	# A downgraded test/backup with intact v6 metadata keeps its original ownership
	# and receipts. Partial ledger metadata must never become a fresh legacy slot.
	if data.has("item_ledger") or data.has("character_id") or data.has("tutorial"):
		var preserved := data.duplicate(true)
		preserved.version = VERSION
		if not preserved.has("hidden_relic"): preserved.hidden_relic = Relic.initial()
		for container in ["bag","chest"]:
			if preserved.get(container) is Dictionary and not preserved[container].has(Relic.ITEM): preserved[container][Relic.ITEM] = 0
		preserved.awake = true
		# v6 already owned its gold and grants; migration adds no new value.
		if not preserved.has("purchase_receipts"): preserved.purchase_receipts = {}
		# Prior Luck free points become unspent; other stats and genuine, validated
		# XP metadata are retained. Migration never manufactures earned Luck XP.
		preserved.stats = migrated_stats.duplicate(true)
		if not preserved.has("combat"): preserved.combat = Resources.initial_state(preserved.stats)
		if not preserved.has("consumption_receipts"): preserved.consumption_receipts = {}
		if not preserved.has("progression"):
			preserved.progression = Rewards.initial(int(preserved.stats.level))
			preserved.wallet_sigils = 0
			preserved.cosmetics = Cosmetics.initial()
			preserved.cosmetic_receipts = {}
			if not Progress.validate_state(preserved.tutorial): return {}
			for encounter_id in Rewards.ENCOUNTERS:
				var event: String = Rewards.ENCOUNTERS[encounter_id].event
				if preserved.tutorial.event_receipts.has(event):
					for index in Rewards.ENCOUNTERS[encounter_id].count:
						preserved.progression.kills[Rewards.key(encounter_id,index)] = Rewards.receipt(encounter_id,index)
			var totals := Rewards.totals(preserved.progression)
			preserved.wallet_gold += totals.gold
			preserved.wallet_sigils = totals.sigils
			var earned := Rewards.summary(preserved.progression)
			if earned.level > preserved.stats.level:
				preserved.stats = Stats.plan_level_advance(preserved.stats,earned.level,preserved.stats.revision).next_state
		return preserved if _valid_snapshot(preserved) else {}
	var hero = data.get("character")
	if not hero is Dictionary or hero.get("base", "") not in ["male", "female"] or not draft_from(hero).validate().is_empty(): return {}
	var version := int(data.version)
	if version >= 2 and data.get("tutorial_chest_seeded") != true: return {}
	var required: Array = ["travel_bread", "keepsake"] if version == 1 else (["healing_potion"] if version == 2 else Inventory.LEGACY_ITEMS)
	for field in ["bag", "chest"]:
		if not _valid_counts(data.get(field), required, false): return {}
	var weapon = data.get("equipped_weapon", "")
	if not weapon is String or (not weapon.is_empty() and not Inventory.can_equip(weapon, hero["class"])): return {}
	var armor = data.get("equipped_armor", "") if version >= 4 else Inventory.starter_armor(hero["class"])
	if not armor is String or not Inventory.armor_allowed(armor, hero["class"]): return {}
	var point = data.get("location", {"scene":"bedroom", "position":[535.0,670.0]})
	if not valid_location(point): return {}
	# Build in an isolated instance so migration failure cannot mutate this session.
	var candidate = get_script().new()
	candidate.character = hero.duplicate(true)
	candidate.stats = migrated_stats.duplicate(true)
	candidate.progression = Rewards.initial(int(candidate.stats.level))
	candidate.combat = Resources.initial_state(candidate.stats)
	candidate.character_id = _new_id()
	candidate.hidden_relic = Relic.initial()
	candidate.location = point.duplicate(true)
	candidate.gold_seeded = true
	candidate.chest_gold = 100
	if data.get("gold_seeded") == true:
		if not _whole(data.get("chest_gold"), 0, 100) or not _whole(data.get("wallet_gold"), 0, 100) or data.chest_gold + data.wallet_gold != 100: return {}
		candidate.chest_gold = int(data.chest_gold)
		candidate.wallet_gold = int(data.wallet_gold)
	var inventory := {"bag":Inventory.empty_inventory(), "chest":Inventory.empty_inventory()}
	for field in ["bag", "chest"]:
		if version >= 3:
			for item in data[field]: inventory[field][item] = int(data[field][item])
		elif version == 2: inventory[field].healing_potion = int(data[field].healing_potion)
	if version == 1: inventory.chest.healing_potion = 5
	var starter := Inventory.starter_weapon(hero["class"])
	# v1/v2 had no class weapon. Preserve a preexisting equipped one if present.
	if version < 3 and weapon.is_empty(): inventory.chest[starter] = 1
	candidate._add_stack(armor, 1, "equipped_armor", "starter", "starter.armor")
	var weapon_remaining := 1
	if not weapon.is_empty():
		candidate._add_stack(weapon, 1, "equipped_weapon", "starter", "starter.weapon")
		weapon_remaining = 0
	var healing_remaining := 5
	# Existing releases provided at most one starter weapon and five free potions.
	# Attribute only that bounded amount; preserve any excess as unknown/unbound.
	for field in ["bag", "chest"]:
		for item in ITEMS:
			var count: int = inventory[field][item]
			var bound_count := mini(count, weapon_remaining if item == starter else (healing_remaining if item == "healing_potion" else 0))
			if bound_count > 0:
				candidate._add_stack(item, bound_count, field, "starter", "starter.weapon" if item == starter else "starter.healing")
				if item == starter: weapon_remaining -= bound_count
				else: healing_remaining -= bound_count
			if count > bound_count: candidate._add_stack(item, count - bound_count, field, "legacy_unattributed", "legacy:" + item)
	candidate._sync_views()
	return candidate.snapshot()

func _near_interaction(scene: String) -> bool:
	if location.scene != scene: return false
	var position := Vector2(location.position[0], location.position[1])
	if scene == "starter_region": return position.distance_to(Vector2(1708, 1340)) <= 90.0
	var npc_id: String = {"guild_interior":"guild_receptionist", "blacksmith_interior":"blacksmith", "apothecary_interior":"apothecary", "general_store_interior":"shopkeeper"}.get(scene, "")
	if npc_id.is_empty(): return false
	var layout_path := "res://assets/town-interiors/" + scene + "/layout.json"
	if not FileAccess.file_exists(layout_path): return false
	var layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if not layout is Dictionary or not layout.get("npcs") is Array: return false
	for npc in layout.npcs:
		if npc.get("id") == npc_id:
			var anchor = npc.get("interaction_anchor")
			return anchor is Array and anchor.size() == 2 and position.distance_to(Vector2(anchor[0], anchor[1])) <= 90.0
	return false

func get_progression_summary() -> Dictionary:
	return Rewards.summary(progression)

func enemy_is_defeated(encounter_id: String, index: int) -> bool:
	return progression.kills.has(Rewards.key(encounter_id,index))

# Called only by the encounter controller with its verified dead spawn indexes.
# Unique quest incarnations make reward replay idempotent across retry/reload.
func record_enemy_defeats(encounter_id: String, indexes: Array, resources: Dictionary) -> bool:
	if not _valid_live_state() or not Rewards.ENCOUNTERS.has(encounter_id):
		error = "Monster rewards are unavailable here."; return false
	if not Resources.valid(resources,stats) or resources.revision != combat.revision: return false
	var row: Dictionary = Rewards.ENCOUNTERS[encounter_id]
	var pending: Array = []
	for index in indexes:
		if not Rewards.whole(index,0,int(row.count)-1): return false
		if not enemy_is_defeated(encounter_id,int(index)) and not pending.has(int(index)): pending.append(int(index))
	if pending.is_empty(): return true
	if tutorial.stage != row.stage or location.scene != "starter_region": error = "Accept this guild assignment and return to the field first."; return false
	var previous := snapshot()
	for index in pending:
		progression.kills[Rewards.key(encounter_id,index)] = Rewards.receipt(encounter_id,index)
		wallet_gold += int(row.gold)
		wallet_sigils += int(row.sigils)
	var earned := Rewards.summary(progression)
	if earned.level > stats.level:
		var plan := Stats.plan_level_advance(stats,earned.level,stats.revision)
		if not plan.ok: _restore(previous); return false
		stats = plan.next_state.duplicate(true)
	combat = resources.duplicate(true); combat.revision += 1
	return _commit(previous)

func _valid_cosmetics(data: Dictionary) -> bool:
	if not Rewards.whole(data.get("wallet_sigils"),0,7) or not data.get("cosmetics") is Dictionary or not data.get("cosmetic_receipts") is Dictionary: return false
	var value: Dictionary = data.cosmetics
	if value.size() != 2 or not value.get("owned") is Array or not value.get("equipped") is Dictionary or value.equipped.size() != 2: return false
	var expected: Array = Cosmetics.initial().owned
	var spent := 0
	for id in data.cosmetic_receipts:
		var item := Cosmetics.item(id)
		var receipt = data.cosmetic_receipts[id]
		if item.is_empty() or item.price <= 0 or not receipt is Dictionary or receipt.size() != 2 or receipt.get("item_id") != id or receipt.get("price") != item.price or receipt.price is bool: return false
		expected.append(id); spent += int(item.price)
	if value.owned.size() != expected.size(): return false
	for id in expected:
		if value.owned.count(id) != 1: return false
	for slot in Cosmetics.DEFAULTS:
		var id = value.equipped.get(slot)
		if not id is String or not value.owned.has(id) or Cosmetics.item(id).get("slot") != slot: return false
	return data.wallet_sigils + spent == Rewards.totals(data.progression).sigils

func purchase_cosmetic(id: String) -> bool:
	if not _valid_live_state(): error = "Your save is not ready."; return false
	var item := Cosmetics.item(id)
	if item.is_empty(): error = "Unknown cosmetic."; return false
	if cosmetics.owned.has(id): return true
	if wallet_sigils < int(item.price): error = "You need %d Sigils." % item.price; return false
	var previous := snapshot()
	wallet_sigils -= int(item.price)
	cosmetics.owned.append(id)
	cosmetic_receipts[id] = {"item_id":id,"price":int(item.price)}
	return _commit(previous)

func equip_cosmetic(id: String) -> bool:
	if not _valid_live_state() or not cosmetics.owned.has(id): error = "Own this cosmetic before equipping it."; return false
	var item := Cosmetics.item(id)
	if cosmetics.equipped[item.slot] == id: return true
	var previous := snapshot()
	cosmetics.equipped[item.slot] = id
	return _commit(previous)

func claim_hidden_stick(tree_id: String) -> bool:
	if not _valid_live_state(): error = "Your save is not ready."; return false
	if hidden_relic.claimed: return true
	if tree_id != hidden_relic.tree_id or location.scene != "starter_region" or Vector2(location.position[0],location.position[1]).distance_to(Relic.point(hidden_relic)) > 36:
		error = "Search closer to the roots."; return false
	var previous := snapshot()
	hidden_relic.claimed = true
	_add_stack(Relic.ITEM,1,"bag",Relic.SOURCE,Relic.SOURCE_ID)
	_sync_views()
	return _commit(previous)
func basic_weapon_bonus() -> int:
	return Relic.BONUS_DAMAGE if equipped_weapon == Relic.ITEM else weapon_upgrade_level()
