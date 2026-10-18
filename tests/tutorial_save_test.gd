extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const ACTIONS = ["read_envelope", "guild_assign_blacksmith", "blacksmith_claim_starter", "guild_after_blacksmith", "apothecary_claim_gift", "guild_after_apothecary", "general_store_claim_keepsake", "guild_after_general_store"]
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
func fixture(selected_class: String = "Warrior", base: String = "male"):
	serial += 1
	var state = Save.new()
	state.path = "user://tutorial_save_%s_%d.json" % [Time.get_ticks_usec(), serial]
	paths.append(state.path)
	var draft = Draft.new()
	draft.set_base(base)
	draft.character_class = selected_class
	draft.username = "TutorialTester"
	check(state.create(draft.payload()), "Create " + selected_class + "/" + base)
	return state
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func snap(state) -> Dictionary: return normalized(state.snapshot())
func write_json(path: String, value) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func move_near(state, action: String) -> void:
	var scene: String = "blacksmith_interior" if action == "upgrade" else Save.ACTION_SCENES[action]
	var point := Vector2(1708,1340)
	if scene != "starter_region":
		var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-interiors/" + scene + "/layout.json"))
		var npc_id: String = {"guild_interior":"guild_receptionist", "blacksmith_interior":"blacksmith", "apothecary_interior":"apothecary", "general_store_interior":"shopkeeper"}[scene]
		for npc in layout.npcs:
			if npc.id == npc_id: point = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1])
	check(state.set_location(scene,point), "Persist interaction position " + action)
func act(state, action: String) -> Dictionary:
	return state.apply_tutorial_weapon_upgrade() if action == "upgrade" else state.perform_tutorial_action(action)
func take_step(state, action: String) -> void:
	move_near(state, action)
	var result: Dictionary = act(state, action)
	check(result.ok and not result.duplicate, "Apply " + action + ": " + str(result.get("message")))
	var bytes := FileAccess.get_file_as_string(state.path)
	var previous := snap(state)
	result = act(state, action)
	check(result.ok and result.duplicate, "Repeat is an idempotent success " + action)
	check(snap(state) == previous and FileAccess.get_file_as_string(state.path) == bytes, "Repeat does not write or grant " + action)
	var loaded = Save.new(); loaded.path = state.path
	check(loaded.load_saved() and snap(loaded) == previous, "Entire snapshot reloads " + action)
func fail_write(state, operation: Callable, label: String) -> void:
	var previous := snap(state)
	var bytes := FileAccess.get_file_as_string(state.path)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	var result = operation.call()
	check(not result.ok if result is Dictionary else not result, "Injected I/O failure rejects " + label)
	check(snap(state) == previous, "Full live rollback " + label)
	check(FileAccess.get_file_as_string(state.path) == bytes, "Original disk byte preservation " + label)
	check(not state.error.is_empty(), "Useful I/O error " + label)
	DirAccess.remove_absolute(state.path + ".tmp")
func reject_corrupt(state, data: Dictionary, label: String) -> void:
	var prior := snap(state)
	var path: String = state.path
	state.path = path + ".corrupt"
	write_json(state.path, data)
	var bytes := FileAccess.get_file_as_string(state.path)
	check(not state.load_saved(), "Reject corruption: " + label)
	check(snap(state) == prior and FileAccess.get_file_as_string(state.path) == bytes, "Corruption preserves live + disk: " + label)
	DirAccess.remove_absolute(state.path)
	state.path = path

func run() -> void:
	check(Save.new().path == "user://bedroom_guest_v1.json", "Permanent guest path unchanged")
	for selected_class in ["Warrior", "Ranger", "Mage", "Necromancer", "Assassin", "Paladin"]:
		for base in ["male", "female"]:
			for container in ["chest", "bag", "equipped_weapon"]:
				var state = fixture(selected_class,base)
				var weapon := Save.Inventory.starter_weapon(selected_class)
				check(state.chest_gold == 100 and state.wallet_gold == 0 and state.chest.healing_potion == 5 and state.chest[weapon] == 1, "Exact starting reward")
				check(state.character_id.length() == 32 and state.item_ledger.size() == 3, "Stable ownership and three initial stacks")
				var weapon_instance: String = state.get_item_details(weapon,"chest").instance_id
				for entry in state.get_item_instances():
					check(entry.binding == "character" and entry.owner_id == state.character_id and not state.can_transfer_instance(entry.id,"other-character"), "All starter supplies and armor bound")
				if container != "chest": check(state.transfer(weapon,false), "Withdraw class weapon")
				if container == "equipped_weapon": check(state.equip(weapon), "Equip class weapon")
				var before := snap(state)
				check(not state.perform_tutorial_action("general_store_claim_keepsake").ok and not state.apply_tutorial_weapon_upgrade().ok, "No skipped rewards or upgrade")
				check(snap(state) == before, "Skipped actions preserve all state")
				take_step(state,"read_envelope")
				take_step(state,"guild_assign_blacksmith")
				take_step(state,"blacksmith_claim_starter")
				check(state.get_item_instances(weapon).size() == 1 and state.upgrade_entitlements[Save.SUPPLIES].uses == 1, "Smith gives only one entitlement, no duplicate weapon")
				var upgrade_container: String = container
				if container == "chest":
					var chest_before := snap(state)
					check(state.apply_tutorial_weapon_upgrade().get("code") == "weapon_in_chest" and snap(state) == chest_before, "Must physically bring starter weapon to smith")
					check(state.set_location("bedroom",Vector2(535,670)) and state.transfer(weapon,false), "Collect lesson weapon from chest")
					upgrade_container = "bag"
				take_step(state,"upgrade")
				check(state.get_item_details(weapon,upgrade_container).instance_id == weapon_instance and state.weapon_upgrade_level(upgrade_container) == 1, "Existing instance upgraded in " + upgrade_container)
				check(state.upgrade_entitlements[Save.SUPPLIES].uses == 0, "Supplies consumed once")
				for action in ACTIONS.slice(3): take_step(state,action)
				check(state.tutorial.stage == "first_combat_pending" and state.bag.mana_potion == 5 and state.bag.keepsake_ring == 1, "Honest pending combat, exact gifts")
				check(not state.perform_tutorial_action("first_combat_completed").ok, "No fabricated combat completion")
				check(state.equip_ring() and state.equipped_ring == "keepsake_ring" and state.equipped_weapon == (weapon if container == "equipped_weapon" else ""), "Ring uses separate accessory slot")
				check(not state.equip("keepsake_ring") and not state.equip_ring(weapon) and not state.equip_ring(), "Slots reject wrong types/repeated equip")
				check(state.unequip_ring() and state.transfer("keepsake_ring",true) and state.load_saved(), "Bound ring stores/reloads")
				check(state.get_item_details("keepsake_ring","chest").binding == "character", "Stored ring remains bound")
				if container == "equipped_weapon": check(state.unequip(), "Remove upgraded weapon")
				check(state.transfer(weapon,true) and state.transfer(weapon,false) and state.equip(weapon) and state.load_saved(), "Upgraded weapon survives chest/bag/equip/reload")
				check(state.weapon_upgrade_level() == 1 and state.get_item_details(weapon,"equipped_weapon").instance_id == weapon_instance, "Upgrade and identity never lost")
				var id: String = state.character_id
				check(state.apply_appearance({"eyes":"Blue"}) and state.load_saved() and state.character_id == id, "Appearance preserves identity and progression")
	# Full rollback at every tutorial transaction, plus ordinary mutations.
	var state = fixture()
	check(state.transfer("warrior_01_weapon",false), "Bring weapon for I/O lesson checks")
	var before := snap(state)
	check(not state.perform_tutorial_action("read_envelope").ok and snap(state) == before, "Remote envelope redemption rejected")
	check(state.set_location("starter_region",Vector2.ZERO), "Set far same-scene position")
	check(not state.perform_tutorial_action("read_envelope").ok, "Same scene does not bypass envelope distance")
	for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store"]:
		move_near(state,action)
		fail_write(state,func(): return act(state,action),action)
		take_step(state,action)
	move_near(state,"upgrade")
	check(state.set_location("bedroom",Vector2(535,670)), "Return to chest")
	fail_write(state,func(): return state.claim_chest_gold(),"chest gold")
	check(state.claim_chest_gold() and state.wallet_gold == 100 and state.chest_gold == 0, "Claim 100 once")
	check(not state.claim_chest_gold() and state.load_saved() and state.wallet_gold == 100, "Claim cannot repeat after reload")
	fail_write(state,func(): return state.transfer("warrior_01_weapon",true),"transfer")
	check(state.transfer("warrior_01_weapon",true) and state.transfer("warrior_01_weapon",false), "Prepare equip")
	fail_write(state,func(): return state.equip("warrior_01_weapon"),"equip")
	check(state.equip("warrior_01_weapon"), "Equip after failure")
	fail_write(state,func(): return state.unequip(),"unequip")
	fail_write(state,func(): return state.equip_ring(),"ring equip")
	check(state.equip_ring(), "Equip ring after failure")
	fail_write(state,func(): return state.unequip_ring(),"ring unequip")
	fail_write(state,func(): return state.apply_appearance({"eyes":"Blue"}),"appearance")
	fail_write(state,func(): return state.set_location("guild_interior",Vector2(500,500)),"location")
	fail_write(state,func(): return state.receive_item("healing_potion",2,"world_drop","drop-failure"),"acquisition")
	var fresh = Save.new(); fresh.path = state.path + "/missing.json"
	before = snap(fresh)
	check(not fresh.create(state.character) and snap(fresh) == before, "Failed creation rolls back entire empty session")
	# Provenance remains per stack even when the item ID is identical.
	check(state.receive_item("healing_potion",3,"world_drop","drop-1"), "Ordinary future drops have explicit provenance")
	check(state.receive_item("healing_potion",2,"trade","trade-1"), "Ordinary future trades have explicit provenance")
	check(state.receive_item("healing_potion",4,"npc_purchase","shop-1"), "NPC purchase acquisition is bound")
	check(state.receive_item("warrior_01_weapon",1,"world_drop","weapon-drop"), "Identical weapon type can be unbound")
	check(state.load_saved(), "Reload mixed provenance")
	before = snap(state)
	check(state.receive_item("healing_potion",3,"world_drop","drop-1") and snap(state) == before, "Acquisition retry idempotent after JSON numeric roundtrip")
	check(not state.receive_item("mana_potion",3,"world_drop","drop-1") and snap(state) == before, "Conflicting acquisition receipt rejected")
	check(not state.receive_item("mana_potion",5,Save.MANA_GIFT,"forged-gift"), "Acquisition API cannot forge tutorial provenance")
	check(not state.receive_item("healing_potion",999,"world_drop","overflow"), "Overflow rejected")
	for entry in state.get_item_instances():
		check(state.can_transfer_instance(entry.id,state.character_id), "Same-owner storage allowed")
		check(state.can_transfer_instance(entry.id,"other") == (entry.source in ["world_drop","trade"]), "Mixed source ownership policy")
	check(not state.can_transfer_instance("forged","other") and not state.can_transfer_instance("", ""), "Unknown ownership rejected")
	# Public views and returned dictionaries cannot authorize invented receipts.
	var detached := state.snapshot(); detached.tutorial.stage = "fake"
	var details: Dictionary = state.get_item_details("warrior_01_weapon","equipped_weapon"); details.upgrade_level = 99
	check(state.tutorial.stage == "first_combat_pending" and state.weapon_upgrade_level() == 1, "Getters are detached copies")
	var good := snap(state)
	for field in ["version", "character_id", "tutorial", "item_ledger", "upgrade_entitlements", "acquisition_receipts", "gold_seeded", "wallet_gold", "equipped_ring"]:
		var bad := good.duplicate(true); bad.erase(field)
		reject_corrupt(state,bad,"missing " + field)
	for value in [-1, 1000, 1.5, "5", true, null]:
		var bad := good.duplicate(true); bad.bag.healing_potion = value
		reject_corrupt(state,bad,"invalid count " + str(value))
	for value in ["other-owner", "", null]:
		var bad := good.duplicate(true); bad.item_ledger[0].owner_id = value
		reject_corrupt(state,bad,"forged owner")
	var bad := good.duplicate(true); bad.item_ledger[0].binding = "unbound"; reject_corrupt(state,bad,"unbound starter")
	bad = good.duplicate(true); bad.item_ledger[0].id = bad.item_ledger[1].id; reject_corrupt(state,bad,"duplicate instance")
	bad = good.duplicate(true); bad.item_ledger[0].quantity += 1; reject_corrupt(state,bad,"ledger/view mismatch")
	bad = good.duplicate(true); bad.wallet_gold += 100; reject_corrupt(state,bad,"duplicated currency")
	bad = good.duplicate(true); bad.tutorial.action_receipts.read_envelope.id = "forged"; reject_corrupt(state,bad,"forged action receipt")
	bad = good.duplicate(true); bad.tutorial.reward_receipts[Save.MANA_GIFT].owner = "read_envelope"; reject_corrupt(state,bad,"forged reward owner")
	bad = good.duplicate(true); bad.upgrade_entitlements[Save.SUPPLIES].uses = 1; reject_corrupt(state,bad,"reusable consumed entitlement")
	bad = good.duplicate(true); bad.tutorial.stage = "completed"; reject_corrupt(state,bad,"fabricated combat completion")
	bad = good.duplicate(true); bad.acquisition_receipts["shop-1"].source = "world_drop"; reject_corrupt(state,bad,"laundered purchase provenance")
	bad = good.duplicate(true); bad.location.position = [INF,0]; reject_corrupt(state,bad,"nonfinite position")
	# View-only mutation cannot be persisted as an inventory grant.
	state.bag.healing_potion += 1
	check(not state.save(), "Direct counts cannot forge a ledger entry")
	check(state.load_saved() and snap(state) == good, "Reload recovers authoritative views")
	# Legacy migrations v1-v5 keep counts/equipment/location and seed gold once.
	for version in [1,2,3,4,5]:
		var legacy = fixture("Ranger","female")
		var source := legacy.snapshot()
		var old_bag: Dictionary = {"travel_bread":2,"keepsake":1} if version == 1 else ({"healing_potion":3} if version == 2 else Save.Inventory.empty_inventory())
		var old_chest: Dictionary = {"travel_bread":0,"keepsake":0} if version == 1 else ({"healing_potion":2} if version == 2 else Save.Inventory.empty_inventory())
		if version >= 3:
			old_bag.healing_potion = 3; old_chest.healing_potion = 2; old_chest.mage_01_weapon = 2
			for added in ["mana_potion","keepsake_ring"]: old_bag.erase(added); old_chest.erase(added)
		var old := {"version":version,"tutorial_chest_seeded":true,"character":source.character,"bag":old_bag,"chest":old_chest,"equipped_weapon":"ranger_01_weapon" if version >= 3 else "","awake":false,"location":{"scene":"guild_interior","position":[700,700]}}
		if version >= 4: old.equipped_armor = "ranger_01_armor"
		write_json(legacy.path,old)
		var old_bytes := FileAccess.get_file_as_string(legacy.path)
		var old_live := snap(legacy)
		DirAccess.make_dir_absolute(legacy.path + ".tmp")
		check(not legacy.load_saved() and snap(legacy) == old_live and FileAccess.get_file_as_string(legacy.path) == old_bytes, "Migration I/O rollback v%d" % version)
		DirAccess.remove_absolute(legacy.path + ".tmp")
		check(legacy.load_saved() and legacy.awake and legacy.chest_gold == 100 and legacy.tutorial.stage == "awaiting_letter", "Migrate v%d" % version)
		check(legacy.bag.healing_potion == (0 if version == 1 else 3) and legacy.chest.healing_potion == (5 if version == 1 else 2), "Preserve potion counts v%d" % version)
		check(legacy.equipped_weapon == ("ranger_01_weapon" if version >= 3 else "") and legacy.chest.ranger_01_weapon == (0 if version >= 3 else 1), "No duplicate migrated starter v%d" % version)
		if version >= 3: check(legacy.chest.mage_01_weapon == 2 and legacy.get_item_details("mage_01_weapon","chest").binding == "unbound", "Preserve unknown extra legacy loot")
		var stable := snap(legacy)
		check(legacy.load_saved() and snap(legacy) == stable, "Idempotent migration v%d" % version)
		check(legacy.set_location("bedroom",Vector2(500,700)) and legacy.claim_chest_gold() and legacy.load_saved() and legacy.wallet_gold == 100 and legacy.chest_gold == 0, "Gold never reseeds v%d" % version)
		# Existing migration regressions downgrade a modern fixture; preserve metadata.
		var downgraded := legacy.snapshot(); downgraded.version = version; downgraded.awake = false
		write_json(legacy.path,downgraded)
		stable = snap(legacy)
		check(legacy.load_saved() and snap(legacy) == stable, "Metadata-bearing backup does not duplicate v%d" % version)
	for path in paths:
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path + ".tmp")
	print("TUTORIAL SAVE CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
