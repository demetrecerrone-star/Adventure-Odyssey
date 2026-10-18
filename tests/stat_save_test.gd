extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Stats = preload("res://src/character_stats.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const Catalog = preload("res://src/creator/catalog.gd")
var checks := 0
var failures := 0
var paths: Array = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func snap(state) -> Dictionary: return normalized(state.snapshot())
func fixture(selected_class: String = "Warrior"):
	var state = Save.new()
	state.path = "user://stat_save_%s_%d.json" % [Time.get_ticks_usec(), paths.size()]
	paths.append(state.path)
	var draft = Draft.new(); draft.set_base("female"); draft.character_class = selected_class; draft.username = "StatTester"
	check(state.create(draft.payload()), "Create " + selected_class + " fixture")
	return state
func write_json(path: String, data) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()
func reject(state, deltas, revision, code: String) -> void:
	var before := snap(state); var bytes := FileAccess.get_file_as_string(state.path)
	var result: Dictionary = state.allocate_stat_points(deltas, revision)
	check(not result.ok and result.code == code, "Reject " + code + ": " + str(result))
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Rejected allocation preserves memory and disk")
func reject_corrupt(state, data: Dictionary, label: String) -> void:
	var before := snap(state); var original_path: String = state.path
	state.path += ".corrupt"; write_json(state.path, data)
	var bytes := FileAccess.get_file_as_string(state.path)
	check(not state.load_saved(), "Reject corrupt save: " + label)
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Corrupt load preserves memory and disk: " + label)
	DirAccess.remove_absolute(state.path); state.path = original_path
func move_near(state, action: String) -> void:
	var scene: String = "blacksmith_interior" if action == "upgrade" else Save.ACTION_SCENES[action]
	var point := Vector2(1708, 1340)
	if scene != "starter_region":
		var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-interiors/" + scene + "/layout.json"))
		var npc_id: String = {"guild_interior":"guild_receptionist", "blacksmith_interior":"blacksmith", "apothecary_interior":"apothecary", "general_store_interior":"shopkeeper"}[scene]
		for npc in layout.npcs:
			if npc.id == npc_id: point = Vector2(npc.interaction_anchor[0], npc.interaction_anchor[1])
	check(state.set_location(scene, point), "Visit " + scene)
func finish_errands(state) -> void:
	check(state.claim_chest_gold(), "Claim starter gold")
	var weapon := Save.Inventory.starter_weapon(state.character["class"])
	check(state.transfer(weapon, false) and state.equip(weapon), "Equip starter weapon")
	for action in ["read_envelope", "guild_assign_blacksmith", "blacksmith_claim_starter", "upgrade", "guild_after_blacksmith", "apothecary_claim_gift", "guild_after_apothecary", "general_store_claim_keepsake", "guild_after_general_store"]:
		move_near(state, action)
		var result: Dictionary = state.apply_tutorial_weapon_upgrade() if action == "upgrade" else state.perform_tutorial_action(action)
		check(result.ok, "Complete errand " + action)
	check(state.equip_ring(), "Equip tutorial ring")
	move_near(state, "apothecary_claim_gift")
	check(state.purchase_shop_item("healing_potion", 2, "saved-stat-shop").ok, "Purchase two potions")
	check(state.receive_item("mana_potion", 2, "world_drop", "saved-stat-drop"), "Preserve independent acquisition")

func run() -> void:
	check(Save.VERSION == 13 and Save.new().path == "user://bedroom_guest_v1.json", "v9 stays in existing permanent slot")
	var empty = Save.new()
	check(empty.get_stat_summary().code == "invalid_save" and empty.preview_stat_allocation({"STR":1}, 0).code == "invalid_save" and empty.allocate_stat_points({"STR":1}, 0).code == "invalid_save" and empty.advance_character_level(2, 0).code == "invalid_save", "No operations before character creation")
	for selected_class in Catalog.CLASSES:
		var hero = fixture(selected_class)
		var summary: Dictionary = hero.get_stat_summary()
		check(summary.ok and summary.level == 1 and summary.unspent_points == 0 and summary.revision == 0, "Every class begins at level one without free extra points")
		for key in Stats.KEYS: check(summary.attributes[key] == 10, selected_class + " equal baseline " + key)
		check(hero.load_saved() and hero.get_stat_summary().attributes == summary.attributes, "Baseline persists " + selected_class)
		reject(hero, {"STR":1}, 0, "insufficient_points")
	var state = fixture("Necromancer")
	finish_errands(state)
	var before := snap(state); var bytes := FileAccess.get_file_as_string(state.path)
	check(state.get_stat_summary().level == 1 and state.get_stat_summary().unspent_points == 0, "Tutorial and shop do not invent XP or award stat points")
	# Future progression hook is tested with explicit earned levels, never a UI control.
	var advanced: Dictionary = state.advance_character_level(4, 0)
	check(advanced.ok and advanced.points_awarded == 15 and advanced.unspent_points == 15 and advanced.revision == 1, "Skipping three earned levels gives exactly 15 points")
	var unchanged := before.duplicate(true); unchanged.stats = snap(state).stats; unchanged.progression = snap(state).progression
	check(snap(state) == unchanged, "Level updates preserve every inventory, tutorial, class, location, gold and shop field")
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	advanced = state.advance_character_level(4, 1)
	check(advanced.ok and advanced.duplicate and advanced.points_awarded == 0 and advanced.revision == 1, "Same level is an award-free no-op")
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Same level does not write")
	check(not state.advance_character_level(3, 1).ok and state.advance_character_level(5, 0).code == "stale_revision", "No level rollback or stale awards")
	var preview: Dictionary = state.preview_stat_allocation({"STR":2, "VIT":4, "INT":3, "WIS":1}, 1)
	check(preview.ok and preview.attributes.VIT == 14 and preview.unspent_points == 5 and not preview.has("next_state"), "Detached preview provides proposed effects without exposing candidate state")
	preview.attributes.VIT = 999; preview.allocations.VIT = 999; preview.planned_effects.max_hp = 999
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Editing or cancelling preview changes neither memory nor disk")
	for value in [true, -1, 1.5, "1", null]: reject(state, {"STR":value}, 1, "invalid_allocation")
	reject(state, {"STR":16}, 1, "insufficient_points")
	reject(state, {"NOPE":1}, 1, "unknown_stat")
	reject(state, {}, 1, "empty_allocation")
	reject(state, {"STR":1}, 0, "stale_revision")
	var allocated: Dictionary = state.allocate_stat_points({"STR":2, "VIT":4, "INT":3, "WIS":1}, 1)
	check(allocated.ok and allocated.code == "allocated" and allocated.points_assigned == 10 and allocated.unspent_points == 5 and allocated.revision == 2, "Explicit atomic allocation succeeds")
	unchanged = before.duplicate(true); unchanged.stats = snap(state).stats; unchanged.progression = snap(state).progression
	check(snap(state) == unchanged, "Allocation changes only validated stats")
	reject(state, {"STR":2, "VIT":4, "INT":3, "WIS":1}, 1, "stale_revision")
	check(state.load_saved() and state.get_stat_summary().attributes.INT == 13 and state.get_stat_summary().unspent_points == 5, "All assigned and unspent values survive restart")
	reject(state, {"STR":1}, 1, "stale_revision")
	# Inventory changes do not invalidate an otherwise identical stat revision.
	check(state.transfer("healing_potion", true), "Unrelated inventory transaction")
	check(state.allocate_stat_points({"AGI":1, "WIS":1}, 2).ok, "Still-current stats may commit after unrelated inventory transaction")
	# Temporary write and rename failure both roll back stats and full save graph.
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	allocated = state.allocate_stat_points({"WIS":2}, 3)
	check(not allocated.ok and allocated.code == "save_failed" and allocated.revision == 3 and allocated.unspent_points == 3 and not state.error.is_empty(), "Failed write returns restored values and useful error")
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Failed allocation write rolls back full memory and preserves disk")
	DirAccess.remove_absolute(state.path + ".tmp")
	check(state.allocate_stat_points({"WIS":2}, 3).ok, "Exact failed allocation safely retries")
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	var real_path: String = state.path; state.path += ".blocked"; DirAccess.make_dir_absolute(state.path)
	allocated = state.allocate_stat_points({"AGI":1}, 4)
	check(not allocated.ok and allocated.code == "save_failed" and snap(state) == before, "Failed rename rolls back allocation")
	check(FileAccess.get_file_as_string(real_path) == bytes and not FileAccess.file_exists(state.path + ".tmp"), "Rename failure preserves previous file and cleans temporary")
	DirAccess.remove_absolute(state.path); state.path = real_path
	check(state.allocate_stat_points({"AGI":1}, 4).ok and state.load_saved() and state.get_stat_summary().unspent_points == 0, "All points allocated and durable")
	reject(state, {"STR":1}, 5, "insufficient_points")
	# Level notification failure also rolls back its award and revision.
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	advanced = state.advance_character_level(6, 5)
	check(not advanced.ok and advanced.code == "save_failed" and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Failed level save cannot leave unsaved points or revision")
	DirAccess.remove_absolute(state.path + ".tmp")
	check(state.advance_character_level(6, 5).points_awarded == 10 and state.load_saved() and state.get_stat_summary().unspent_points == 10, "Retry awards exactly newly earned levels")
	check(state.advance_character_level(6, 6).points_awarded == 0, "Repeated notification after restart cannot grant again")
	reject(state, {"STR":1}, 5, "stale_revision")
	var detached: Dictionary = state.get_stat_summary(); detached.allocations.STR = 100; detached.attributes.STR = 100
	check(state.get_stat_summary().attributes.STR == 12, "Save summaries are detached")
	var good := snap(state)
	for field in ["stats"]:
		var bad := good.duplicate(true); bad.erase(field); reject_corrupt(state, bad, "missing " + field)
	for field in ["version", "level", "revision", "allocations"]:
		var bad := good.duplicate(true); bad.stats.erase(field); reject_corrupt(state, bad, "missing stats." + field)
	for field in ["version", "level", "revision"]:
		for value in [true, null, "1", -1, 1.5, 999999999999]:
			var bad := good.duplicate(true); bad.stats[field] = value; reject_corrupt(state, bad, "invalid stats." + field)
	for value in [true, null, {}, [], -1, 1.5, "10", 5000]:
		var bad := good.duplicate(true); bad.stats.allocations.STR = value; reject_corrupt(state, bad, "invalid allocation")
	var bad := good.duplicate(true); bad.stats.extra = 1; reject_corrupt(state, bad, "extra stat metadata")
	bad = good.duplicate(true); bad.stats.allocations.erase("AGI"); reject_corrupt(state, bad, "missing attribute")
	bad = good.duplicate(true); bad.stats.allocations.EXTRA = 0; reject_corrupt(state, bad, "extra attribute")
	bad = good.duplicate(true); bad.stats.level = 1; reject_corrupt(state, bad, "allocated more than earned")
	state.stats.allocations.STR = -1
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	check(state.get_stat_summary().code == "invalid_save" and state.allocate_stat_points({"STR":1}, 6).code == "invalid_save" and not state.save(), "Invalid live stat state cannot authorize mutations or overwrite valid slot")
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes and state.load_saved() and snap(state) == good, "Rejected invalid live state stays unchanged and may reload good slot")
	# v7 migration preserves the complete pre-stat save, including paid receipts.
	var legacy := good.duplicate(true); legacy.version = 7; legacy.erase("stats"); legacy.erase("progression"); legacy.erase("wallet_sigils"); legacy.erase("cosmetics"); legacy.erase("cosmetic_receipts")
	write_json(state.path, legacy); bytes = FileAccess.get_file_as_string(state.path); before = snap(state)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	check(not state.load_saved() and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "v7 migration write failure preserves live session and original slot")
	DirAccess.remove_absolute(state.path + ".tmp")
	check(state.load_saved(), "v7 full-progress save migrates")
	var migrated := snap(state)
	var expected := legacy.duplicate(true); expected.version = Save.VERSION; expected.stats = normalized(Stats.initial_state()); expected.progression = Save.Rewards.initial(); expected.wallet_sigils = 0; expected.cosmetics = Save.Cosmetics.initial(); expected.cosmetic_receipts = {}
	check(migrated == normalized(expected), "v7 migration only adds baseline stats and version")
	check(state.tutorial.stage == "first_combat_pending" and state.weapon_upgrade_level() == 1 and state.equipped_ring == "keepsake_ring" and state.wallet_gold == 80, "Migration retains tutorial, upgrade, equipment and spent gold")
	check(state.load_saved() and snap(state) == migrated, "Migration does not repeat or reset on next load")
	check(state.purchase_shop_item("healing_potion", 2, "saved-stat-shop").duplicate and state.perform_tutorial_action("apothecary_claim_gift").duplicate and snap(state) == migrated, "Saved shop and tutorial rewards cannot duplicate after migration")
	# Downgraded backups with valid stat metadata preserve it instead of re-awarding.
	legacy = good.duplicate(true); legacy.version = 7; write_json(state.path, legacy)
	check(state.load_saved() and snap(state) == good, "Existing stats in downgraded backup preserve all assigned and earned points")
	bad = legacy.duplicate(true); bad.stats.allocations.STR = -1; reject_corrupt(state, bad, "old version with malformed stats is never silently reset")
	# Pre-shop v6 metadata has no purchase receipts. It gains only empty receipts and baseline stats.
	var v6 = fixture("Mage"); check(v6.claim_chest_gold() and v6.transfer("mage_01_weapon", false) and v6.equip("mage_01_weapon"), "Prepare v6 state")
	var v6_data := snap(v6); v6_data.version = 6; v6_data.erase("stats"); v6_data.erase("purchase_receipts")
	write_json(v6.path, v6_data)
	check(v6.load_saved() and v6.get_stat_summary().unspent_points == 0 and v6.character_id == v6_data.character_id and v6.item_ledger == v6_data.item_ledger and v6.wallet_gold == 100, "v6 identities, equipment, inventory and currency preserved")
	for version in [1, 2, 3, 4, 5]:
		var old = fixture("Ranger")
		var old_bag: Dictionary = {"travel_bread":2, "keepsake":1} if version == 1 else ({"healing_potion":3} if version == 2 else Save.Inventory.empty_inventory())
		var old_chest: Dictionary = {"travel_bread":0, "keepsake":0} if version == 1 else ({"healing_potion":2} if version == 2 else Save.Inventory.empty_inventory())
		if version >= 3:
			old_bag.healing_potion = 3; old_chest.healing_potion = 2
			for added in ["mana_potion", "keepsake_ring"]: old_bag.erase(added); old_chest.erase(added)
		var old_data := {"version":version, "tutorial_chest_seeded":true, "character":old.character.duplicate(true), "bag":old_bag, "chest":old_chest, "equipped_weapon":"ranger_01_weapon" if version >= 3 else "", "awake":false, "location":{"scene":"guild_interior", "position":[700,700]}}
		if version >= 4: old_data.equipped_armor = "ranger_01_armor"
		var malformed_legacy := old_data.duplicate(true); malformed_legacy.stats = {"level":1}
		reject_corrupt(old, malformed_legacy, "bare legacy v%d with malformed supplied stats" % version)
		write_json(old.path, old_data)
		check(old.load_saved() and old.get_stat_summary().level == 1 and old.get_stat_summary().unspent_points == 0 and old.get_stat_summary().attributes.STR == 10, "Legacy v%d safely gains baseline without points" % version)
		var stable := snap(old)
		check(old.load_saved() and snap(old) == stable, "Legacy v%d migration remains idempotent" % version)
	luck_save_cases()
	for path in paths:
		DirAccess.remove_absolute(path); DirAccess.remove_absolute(path + ".tmp")
	print("STAT SAVE CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func luck_save_cases() -> void:
	var state = fixture("Paladin")
	finish_errands(state)
	check(state.get_stat_summary().luck_total_xp == 0, "Tutorial, storage claims and purchases do not give Luck XP")
	var before := snap(state); var bytes := FileAccess.get_file_as_string(state.path)
	check(state.get_stat_summary().luck_xp_required == 100 and state.get_stat_summary().attributes.LUK == 10, "Persistent Luck baseline is 10 and 0/100 XP")
	check(state.set_location("bedroom", Vector2(535, 670)), "Return to storage chest")
	for index in range(3): check(state.transfer("healing_potion", true) and state.transfer("healing_potion", false), "Storage item round trip")
	check(state.get_stat_summary().luck_total_xp == 0, "Repeated storage transfers cannot earn Luck XP")
	check(state.advance_character_level(4, 0).ok, "Prepare five-stat points")
	reject(state, {"LUK":1}, 1, "luck_not_allocatable")
	reject(state, {"LUK":0, "STR":1}, 1, "luck_not_allocatable")
	# This trusted hook is invoked only by tests, never current chest UI/gameplay.
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	var event: Dictionary = state.record_luck_event("first", "future-chest-a", "first_discovery", "", 1)
	check(not event.ok and event.code == "save_failed" and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Failed earned XP write rolls back receipt, XP and revision")
	DirAccess.remove_absolute(state.path + ".tmp")
	event = state.record_luck_event("first", "future-chest-a", "first_discovery", "", 1)
	check(event.ok and event.luck_xp_awarded == 25 and event.luck_total_xp == 25 and event.unspent_points == 15, "Future verified discovery saves independent Luck XP")
	var unchanged := before.duplicate(true); unchanged.stats = snap(state).stats; unchanged.progression = snap(state).progression
	check(snap(state) == unchanged, "Luck receipt only changes stats, preserving every other save field")
	check(state.load_saved() and state.get_stat_summary().luck_xp == 25, "Luck XP and receipt persist on reload")
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	event = state.record_luck_event("first", "future-chest-a", "first_discovery", "", 1)
	check(event.ok and event.duplicate and event.luck_xp_awarded == 0 and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Replay after reload with original revision is a no-write success")
	event = state.record_luck_event("another-id", "future-chest-a", "first_discovery", "", 2)
	check(not event.ok and event.code == "discovery_already_recorded" and snap(state) == before, "Alternate event reference cannot farm first discovery")
	for index in range(3):
		event = state.record_luck_event("empty-%d" % index, "future-chest-a", "empty_open", "", 2)
		check(event.ok and event.luck_xp_awarded == 0 and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Empty opening earns zero and performs no write")
	check(state.record_luck_event("bad-refill", "unknown", "refill", "cycle", 2).code == "undiscovered_source", "Unrecognized refill source rejected")
	var real_path: String = state.path; state.path += ".blocked"; DirAccess.make_dir_absolute(state.path)
	event = state.record_luck_event("refill-1", "future-chest-a", "refill", "cycle-1", 2)
	check(not event.ok and event.code == "save_failed" and snap(state) == before and FileAccess.get_file_as_string(real_path) == bytes and not FileAccess.file_exists(state.path + ".tmp"), "Failed XP rename restores all state and preserves disk")
	DirAccess.remove_absolute(state.path); state.path = real_path
	check(state.record_luck_event("refill-1", "future-chest-a", "refill", "cycle-1", 2).luck_xp_awarded == 5, "Genuinely new refill saves reduced XP")
	before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	check(state.record_luck_event("refill-1", "future-chest-a", "refill", "cycle-1", 2).duplicate and state.record_luck_event("new-id", "future-chest-a", "refill", "cycle-1", 3).code == "refill_already_recorded", "Both transport and semantic refill replays safe")
	check(snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Refill replays do not save or mutate")
	check(state.record_luck_event("refill-2", "future-chest-a", "refill", "cycle-2", 3).luck_xp_awarded == 5, "A later genuine refill cycle gets reduced XP")
	for index in range(3): check(state.record_luck_event("new-first-%d" % index, "future-chest-%d" % index, "first_discovery", "", state.stats.revision).ok, "Distinct future discovery")
	check(state.load_saved() and state.get_stat_summary().attributes.LUK == 11 and state.get_stat_summary().luck_xp == 10 and state.get_stat_summary().luck_xp_required == 125 and state.get_stat_summary().unspent_points == 15, "Earned Luck level and overflow persist without affecting character-point budget")
	reject(state, {"STR":1}, 1, "stale_revision")
	var valid_xp := snap(state)
	for field in ["luck"]:
		var bad := valid_xp.duplicate(true); bad.stats.erase(field); reject_corrupt(state, bad, "missing current Luck state")
	for field in ["version", "total_xp", "event_receipts"]:
		var bad := valid_xp.duplicate(true); bad.stats.luck.erase(field); reject_corrupt(state, bad, "missing Luck " + field)
	var bad := valid_xp.duplicate(true); bad.stats.luck.total_xp += 100; reject_corrupt(state, bad, "XP without receipts")
	bad = valid_xp.duplicate(true); bad.stats.luck.event_receipts.first.xp += 100; bad.stats.luck.total_xp += 100; reject_corrupt(state, bad, "balanced forged award")
	bad = valid_xp.duplicate(true); bad.stats.allocations.LUK = 0; reject_corrupt(state, bad, "current free Luck allocation forbidden")
	bad = valid_xp.duplicate(true); bad.stats.luck.event_receipts["copy"] = bad.stats.luck.event_receipts.first.duplicate(true); bad.stats.luck.total_xp += 25; reject_corrupt(state, bad, "duplicate discovery receipt")
	# Genuine current-schema XP in a downgraded backup survives intact.
	var old := valid_xp.duplicate(true); old.version = 8; write_json(state.path, old)
	check(state.load_saved() and snap(state) == valid_xp, "Validated existing XP metadata survives downgraded v8 backup")
	# Real v8 stats had six free attributes, with no genuine XP evidence.
	old = valid_xp.duplicate(true); old.version = 8
	old.stats = {"version":1, "level":4, "revision":6, "allocations":{"STR":2, "AGI":1, "VIT":2, "INT":1, "WIS":1, "LUK":5}}
	write_json(state.path, old); before = snap(state); bytes = FileAccess.get_file_as_string(state.path)
	DirAccess.make_dir_absolute(state.path + ".tmp")
	check(not state.load_saved() and snap(state) == before and FileAccess.get_file_as_string(state.path) == bytes, "Refund migration failure preserves original v8 bytes and current live XP")
	DirAccess.remove_absolute(state.path + ".tmp")
	check(state.load_saved(), "Valid v8 stat schema migrates")
	var refunded := snap(state); var view: Dictionary = state.get_stat_summary()
	check(view.attributes.LUK == 10 and view.luck_total_xp == 0 and view.unspent_points == 8 and view.spent_points == 7 and view.earned_points == 15 and view.revision == 7, "Five previous Luck points refunded into unspent, never interpreted as XP")
	var expected := old.duplicate(true); expected.version = Save.VERSION; expected.stats = normalized(Stats.migrate_legacy_state(old.stats))
	check(refunded == normalized(expected), "Refund preserves all other stats, tutorial, purchases, equipment, gold, identity and location")
	check(state.load_saved() and snap(state) == refunded, "Reload cannot repeat refund")
	check(state.allocate_stat_points({"STR":8}, 7).ok and state.get_stat_summary().unspent_points == 0 and state.get_stat_summary().attributes.LUK == 10, "Refunded points freely available to eligible five stats")
	check(state.load_saved() and state.get_stat_summary().unspent_points == 0, "Spent refund is not restored again")
	bad = old.duplicate(true); bad.erase("stats"); reject_corrupt(state, bad, "v8 missing stats never defaults")
	bad = old.duplicate(true); bad.stats.luck_xp = 100; reject_corrupt(state, bad, "v8 invented XP field rejected")
	bad = old.duplicate(true); bad.stats.allocations.LUK = -1; reject_corrupt(state, bad, "malformed old Luck allocation rejected")
	bad = old.duplicate(true); bad.version = 9; reject_corrupt(state, bad, "current v9 cannot silently migrate legacy stat schema")
