extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Catalog = preload("res://src/shop_catalog.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
var serial := 0
var paths: Array = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func snap(state) -> Dictionary: return normalized(state.snapshot())
func fixture(claim_gold: bool = true):
	serial += 1
	var state = Save.new()
	state.path = "user://shop_save_%s_%d.json" % [Time.get_ticks_usec(), serial]
	paths.append(state.path)
	var draft = Draft.new()
	draft.set_base("female")
	draft.character_class = "Mage"
	draft.username = "ShopTester"
	check(state.create(draft.payload()), "Create shop fixture")
	if claim_gold: check(state.claim_chest_gold(), "Claim starter gold once")
	return state
func shop_point(shop_id: String) -> Vector2:
	var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-interiors/" + Catalog.scene_for(shop_id) + "/layout.json"))
	var npc_id := "apothecary" if shop_id == "apothecary" else "shopkeeper"
	for npc in layout.npcs:
		if npc.id == npc_id: return Vector2(npc.interaction_anchor[0], npc.interaction_anchor[1])
	return Vector2.ZERO
func move_near(state, shop_id: String) -> void:
	check(state.set_location(Catalog.scene_for(shop_id), shop_point(shop_id)), "Persist shop interaction " + shop_id)
func write_json(path: String, value) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value)); file.close()
func fail_purchase(state, item, quantity, transaction, code: String) -> void:
	var before := snap(state)
	var bytes := FileAccess.get_file_as_string(state.path)
	var result: Dictionary = state.purchase_shop_item(item, quantity, transaction)
	check(not result.ok and result.code == code, "Reject with " + code + ": " + str(result))
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Rejected purchase preserves full memory and disk")
func reject_corrupt(state, data: Dictionary, label: String) -> void:
	var prior := snap(state)
	var path: String = state.path
	state.path = path + ".corrupt"
	write_json(state.path, data)
	var bytes := FileAccess.get_file_as_string(state.path)
	check(not state.load_saved(), "Reject corrupted purchase: " + label)
	check(snap(state) == prior and FileAccess.get_file_as_string(state.path) == bytes, "Rejected load preserves memory and bytes: " + label)
	DirAccess.remove_absolute(state.path)
	state.path = path

func run() -> void:
	check(Save.VERSION == 11 and Catalog.MAX_QUANTITY == 10, "Bounded v10 service")
	check(Catalog.STOCK_POLICY == "unlimited" and Catalog.CURRENT_REVISION == 1, "Explicit development stock and price revision")
	check(Catalog.entries_for("apothecary").size() == 2 and Catalog.entries_for("general_store").size() == 1, "Only approved potions stocked")
	check(Catalog.entries_for("blacksmith").is_empty() and Catalog.shop_for_scene("guild_interior").is_empty(), "No gear or guild shop")
	check(Catalog.unit_price("apothecary", "healing_potion") == 10 and Catalog.unit_price("apothecary", "mana_potion") == 10 and Catalog.unit_price("general_store", "healing_potion") == 10, "Provisional prices authoritative in catalog")
	check(Catalog.unit_price("general_store", "mana_potion") == 0 and Catalog.unit_price("apothecary", "healing_potion", 999) == 0, "Unknown stock and historical revisions rejected")
	var offers := Catalog.entries_for("apothecary")
	offers[0].unit_price_gold = 0
	check(Catalog.entries_for("apothecary")[0].unit_price_gold == 10, "Catalog returned offers detached")
	var empty = Save.new()
	check(empty.get_shop_catalog().code == "invalid_save" and empty.purchase_shop_item("healing_potion", 1, "empty").code == "invalid_save", "No pre-creation shop access")
	# Chest gold is not spendable before an explicit claim; no shop code seeds gold.
	var state = fixture(false)
	check(state.purchase_receipts.is_empty(), "New slot has no purchased value")
	check(state.get_shop_catalog().code == "wrong_location", "Bedroom cannot open shop")
	fail_purchase(state, "healing_potion", 1, "bedroom", "wrong_location")
	move_near(state, "apothecary")
	fail_purchase(state, "healing_potion", 1, "zero-wallet", "insufficient_gold")
	check(state.chest_gold == 100 and state.wallet_gold == 0, "Purchase never implicitly claims chest")
	for scene in ["starter_region", "guild_interior", "blacksmith_interior"]:
		check(state.set_location(scene, Vector2(700, 700)), "Enter non-shop " + scene)
		fail_purchase(state, "healing_potion", 1, "remote", "wrong_location")
	for shop_id in ["apothecary", "general_store"]:
		check(state.set_location(Catalog.scene_for(shop_id), Vector2.ZERO), "Enter shop far from merchant")
		check(state.get_shop_catalog().code == "wrong_location", "Same scene does not authorize remote browsing")
		fail_purchase(state, "healing_potion", 1, "far", "wrong_location")
		check(state.set_location(Catalog.scene_for(shop_id), shop_point(shop_id) + Vector2(90.01, 0)), "Move just outside shop range")
		fail_purchase(state, "healing_potion", 1, "outside", "wrong_location")
		check(state.set_location(Catalog.scene_for(shop_id), shop_point(shop_id) + Vector2(90, 0)), "Move to inclusive interaction boundary")
		check(state.get_shop_catalog().ok and state.get_shop_catalog().shop_id == shop_id, "Saved NPC anchor authorizes correct shop")
	check(state.set_location("bedroom", Vector2(535, 670)) and state.claim_chest_gold(), "Collect exact 100 gold for purchases")
	move_near(state, "apothecary")
	var catalog: Dictionary = state.get_shop_catalog()
	check(catalog.ok and catalog.shop_id == "apothecary" and catalog.shop_name == "Apothecary" and catalog.wallet_gold == 100 and catalog.max_quantity == 10 and catalog.stock_policy == "unlimited", "Authoritative catalog includes UI context")
	catalog.offers[0].unit_price_gold = 1
	check(state.get_shop_catalog().offers[0].unit_price_gold == 10, "UI catalog cannot change price")
	for quantity in [-1, 0, 11, 999999999999, 1.5, NAN, INF, "1", true, false, null, [], {}]:
		fail_purchase(state, "healing_potion", quantity, "invalid-quantity", "invalid_quantity")
	for item in ["unknown", "keepsake_ring", "mage_01_weapon", "", null, true, 1, [], {}]:
		fail_purchase(state, item, 1, "invalid-item", "invalid_item")
	for transaction in ["", " ", " leading", "trailing ", "x".repeat(97), null, true, 1, [], {}]:
		fail_purchase(state, "healing_potion", 1, transaction, "invalid_transaction_id")
	# Debit, bound ledger grant and both receipts are one atomic write.
	var first: Dictionary = state.purchase_shop_item("healing_potion", 2, "first-purchase")
	check(first.ok and not first.duplicate and first.code == "purchased", "First transaction succeeds")
	check(state.wallet_gold == 80 and state.bag.healing_potion == 2 and state.chest.healing_potion == 5 and state.chest_gold == 0, "Exactly 20 gold debited and two potions granted")
	check(first.receipt == state.purchase_receipts["first-purchase"] and first.receipt.total_price_gold == 20 and first.receipt.unit_price_gold == 10 and first.receipt.shop_id == "apothecary" and first.receipt.character_id == state.character_id, "Receipt derives complete authoritative payload")
	var stack: Dictionary = state.get_item_details("healing_potion")
	check(stack.source == "npc_purchase" and stack.source_id == "shop:first-purchase" and stack.binding == "character" and stack.owner_id == state.character_id and not state.can_transfer_instance(stack.id, "other"), "Paid goods stay bound to current character")
	first.receipt.total_price_gold = 0
	check(state.purchase_receipts["first-purchase"].total_price_gold == 20, "Receipt result is detached")
	var before := snap(state)
	var bytes := FileAccess.get_file_as_string(state.path)
	var duplicate: Dictionary = state.purchase_shop_item("healing_potion", 2.0, "first-purchase")
	check(duplicate.ok and duplicate.duplicate and duplicate.code == "already_purchased" and duplicate.receipt.total_price_gold == 20, "Whole JSON numeric retry succeeds idempotently")
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Double tap neither writes nor grants nor debits")
	var loaded = Save.new(); loaded.path = state.path
	check(loaded.load_saved() and snap(loaded) == before, "Paid snapshot fully reloads")
	duplicate = loaded.purchase_shop_item("healing_potion", 2, "first-purchase")
	check(duplicate.ok and duplicate.duplicate and snap(loaded) == before and FileAccess.get_file_as_string(state.path) == bytes, "Retry after reload is idempotent")
	fail_purchase(state, "healing_potion", 1, "first-purchase", "transaction_conflict")
	fail_purchase(state, "mana_potion", 2, "first-purchase", "transaction_conflict")
	move_near(state, "general_store")
	fail_purchase(state, "healing_potion", 2, "first-purchase", "transaction_conflict")
	fail_purchase(state, "mana_potion", 1, "not-sold", "invalid_item")
	check(state.purchase_shop_item("healing_potion", 1, "general-purchase").ok and state.wallet_gold == 70 and state.bag.healing_potion == 3, "General store has separate authoritative valid purchase")
	move_near(state, "apothecary")
	check(state.purchase_shop_item("mana_potion", 3, "mana-purchase").ok and state.wallet_gold == 40 and state.bag.mana_potion == 3, "Apothecary also sells mana")
	check(state.purchase_shop_item("healing_potion", 2, "second-purchase").ok and state.wallet_gold == 20 and state.bag.healing_potion == 5, "New ID permits another deliberate identical purchase")
	fail_purchase(state, "healing_potion", 3, "expensive", "insufficient_gold")
	# Both failure stages restore the full live graph and leave prior disk bytes.
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	var failed: Dictionary = state.purchase_shop_item("mana_potion", 1, "retry-write")
	check(not failed.ok and failed.code == "save_failed" and not state.error.is_empty(), "Failed temporary write reports useful error")
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes and not state.purchase_receipts.has("retry-write"), "Failed write fully rolls back receipt, stack and gold")
	DirAccess.remove_absolute(state.path + ".tmp")
	check(state.purchase_shop_item("mana_potion", 1, "retry-write").ok and state.wallet_gold == 10, "Same transaction ID safely retries after I/O failure")
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	var real_path: String = state.path
	state.path += ".blocked"
	DirAccess.make_dir_absolute(state.path)
	failed = state.purchase_shop_item("mana_potion", 1, "retry-rename")
	check(not failed.ok and failed.code == "save_failed" and snap(state) == before, "Failed final rename fully rolls back")
	check(FileAccess.get_file_as_string(real_path) == bytes and not FileAccess.file_exists(state.path + ".tmp"), "Failed rename preserves original file and removes temporary")
	DirAccess.remove_absolute(state.path); state.path = real_path
	check(state.purchase_shop_item("mana_potion", 1, "retry-rename").ok and state.wallet_gold == 0, "Exact remaining balance can be spent")
	fail_purchase(state, "healing_potion", 1, "no-gold-left", "insufficient_gold")
	check(state.purchase_shop_item("mana_potion", 1, "retry-rename").duplicate, "Zero balance does not break successful retry")
	check(state.load_saved() and state.wallet_gold == 0 and state.chest_gold == 0, "Zero gold persists")
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	check(state.purchase_shop_item("mana_potion", 1, "retry-rename").duplicate and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Zero-gold retry after reload remains an unchanged idempotent success")
	check(state.set_location("bedroom", Vector2(535, 670)) and not state.claim_chest_gold() and state.load_saved() and state.wallet_gold == 0, "No chest gold reseed after complete spend")
	check(state.transfer("healing_potion", true) and state.transfer("healing_potion", false) and state.load_saved(), "Purchased stacks split and transfer without losing accounting")
	for entry in state.get_item_instances():
		if entry.source == "npc_purchase": check(entry.binding == "character" and not state.can_transfer_instance(entry.id, "other"), "Purchased split stacks remain bound")
	# Corrupt debit/grant/price/owner receipts cannot load or overwrite a good slot.
	var good := snap(state)
	for field in ["purchase_receipts", "wallet_gold", "acquisition_receipts"]:
		var bad := good.duplicate(true); bad.erase(field); reject_corrupt(state, bad, "missing " + field)
	for field in ["transaction_id", "character_id", "shop_id", "item_id", "quantity", "unit_price_gold", "total_price_gold", "catalog_revision"]:
		var bad := good.duplicate(true); bad.purchase_receipts["first-purchase"].erase(field); reject_corrupt(state, bad, "receipt missing " + field)
	for field in ["transaction_id", "character_id", "shop_id", "item_id"]:
		for value in ["forged", "", true, 3, null, {}]:
			var bad := good.duplicate(true); bad.purchase_receipts["first-purchase"][field] = value; reject_corrupt(state, bad, "receipt invalid " + field)
	for field in ["quantity", "unit_price_gold", "total_price_gold", "catalog_revision"]:
		for value in [-1, 0, 1.5, 999999, "10", true, null]:
			var bad := good.duplicate(true); bad.purchase_receipts["first-purchase"][field] = value; reject_corrupt(state, bad, "receipt invalid " + field)
	var bad := good.duplicate(true); bad.purchase_receipts["first-purchase"].unit_price_gold = 5; bad.purchase_receipts["first-purchase"].total_price_gold = 10; bad.wallet_gold = 10; reject_corrupt(state, bad, "internally balanced fake discount")
	bad = good.duplicate(true); bad.purchase_receipts["first-purchase"].catalog_revision = 2; reject_corrupt(state, bad, "unknown catalog revision")
	bad = good.duplicate(true); bad.purchase_receipts["first-purchase"].extra = "unexpected"; reject_corrupt(state, bad, "extra receipt field")
	bad = good.duplicate(true); bad.purchase_receipts.erase("first-purchase"); reject_corrupt(state, bad, "missing debit receipt")
	bad = good.duplicate(true); bad.purchase_receipts["copy"] = bad.purchase_receipts["first-purchase"].duplicate(true); reject_corrupt(state, bad, "duplicated receipt key")
	bad = good.duplicate(true); bad.wallet_gold = 100; reject_corrupt(state, bad, "restored spent money")
	bad = good.duplicate(true); bad.chest_gold = 100; reject_corrupt(state, bad, "reseeded chest gold")
	bad = good.duplicate(true); bad.acquisition_receipts.erase("shop:first-purchase"); reject_corrupt(state, bad, "missing purchase acquisition")
	bad = good.duplicate(true); bad.acquisition_receipts["shop:first-purchase"].quantity += 1; reject_corrupt(state, bad, "grant/debit quantity mismatch")
	bad = good.duplicate(true); bad.acquisition_receipts["shop:first-purchase"].source = "world_drop"; reject_corrupt(state, bad, "laundered paid provenance")
	for field in ["source", "item_id", "quantity"]:
		for value in [true, null, {}, []]:
			bad = good.duplicate(true); bad.acquisition_receipts["shop:first-purchase"][field] = value; reject_corrupt(state, bad, "malformed purchase acquisition " + field)
	bad = good.duplicate(true)
	for index in range(bad.item_ledger.size() - 1, -1, -1):
		if bad.item_ledger[index].source_id == "shop:first-purchase":
			var entry: Dictionary = bad.item_ledger[index]
			bad[entry.container][entry.item_id] -= entry.quantity
			bad.item_ledger.remove_at(index)
	reject_corrupt(state, bad, "receipt exists but paid ledger grant is missing")
	bad = good.duplicate(true)
	for entry in bad.item_ledger:
		if entry.source == "npc_purchase": entry.binding = "unbound"; break
	reject_corrupt(state, bad, "unbound paid stack")
	# v7 missing receipts are not migrated; changing version cannot restore spent gold.
	bad = good.duplicate(true); bad.version = 6; bad.erase("purchase_receipts"); reject_corrupt(state, bad, "downgrade strips paid accounting")
	# Existing v6 provenance records remain intact and do not count as paid spend.
	var legacy = fixture()
	check(legacy.receive_item("healing_potion", 2, "npc_purchase", "legacy-npc"), "Trusted compatibility acquisition hook retained")
	move_near(legacy, "general_store")
	var legacy_data := snap(legacy); legacy_data.version = 6; legacy_data.erase("purchase_receipts")
	write_json(legacy.path, legacy_data)
	var old_bytes := FileAccess.get_file_as_string(legacy.path)
	var old_live := snap(legacy)
	DirAccess.make_dir_absolute(legacy.path + ".tmp")
	check(not legacy.load_saved() and snap(legacy) == old_live and FileAccess.get_file_as_string(legacy.path) == old_bytes, "v6 migration I/O rollback")
	DirAccess.remove_absolute(legacy.path + ".tmp")
	check(legacy.load_saved() and legacy.wallet_gold == 100 and legacy.chest_gold == 0 and legacy.bag.healing_potion == 2 and legacy.purchase_receipts.is_empty(), "v6 migration preserves gold, grants and receipts without inferred purchases")
	check(legacy.character_id == legacy_data.character_id and legacy.get_item_details("healing_potion").id == legacy_data.item_ledger[-1].id, "v6 ownership and stack identity retained")
	var migrated := snap(legacy)
	check(legacy.load_saved() and snap(legacy) == migrated, "Migration does not repeat")
	check(legacy.purchase_shop_item("healing_potion", 10, "full-balance").ok and legacy.wallet_gold == 0 and legacy.bag.healing_potion == 12, "Migrated save can spend full balance normally")
	check(legacy.load_saved() and not legacy.claim_chest_gold() and legacy.wallet_gold == 0, "Migrated save never reseeds spent gold")
	# Capacity includes existing acquisitions and starter transfers.
	var capacity = fixture()
	check(capacity.receive_item("healing_potion", 998, "world_drop", "capacity"), "Fill near capacity with explicit existing acquisition")
	move_near(capacity, "apothecary")
	fail_purchase(capacity, "healing_potion", 2, "over-capacity", "inventory_full")
	check(capacity.purchase_shop_item("healing_potion", 1, "at-capacity").ok and capacity.bag.healing_potion == 999, "Inclusive inventory cap accepted")
	fail_purchase(capacity, "healing_potion", 1, "full-capacity", "inventory_full")
	check(capacity.purchase_shop_item("healing_potion", 1, "at-capacity").duplicate, "Successful retry at full capacity remains safe")
	check(capacity.receive_item("mana_potion", 1, "npc_purchase", "shop:collision"), "Create legacy ID collision fixture")
	fail_purchase(capacity, "mana_potion", 1, "collision", "transaction_conflict")
	# Corrupt public views cannot authorize a purchase or silently repair themselves.
	capacity.wallet_gold += 10
	before = snap(capacity); bytes = FileAccess.get_file_as_string(capacity.path)
	check(capacity.get_shop_catalog().code == "invalid_save" and capacity.purchase_shop_item("mana_potion", 1, "invalid-state").code == "invalid_save", "Invalid live currency refused before any transaction")
	check(snap(capacity) == before and FileAccess.get_file_as_string(capacity.path) == bytes and capacity.load_saved(), "Invalid live state neither mutates nor overwrites saved slot")
	for path in paths:
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path + ".tmp")
	print("SHOP SAVE CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
