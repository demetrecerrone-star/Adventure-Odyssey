extends SceneTree
const Stats = preload("res://src/character_stats.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func expect_failure(state, deltas, revision, code: String) -> void:
	var before = normalized(state)
	var result := Stats.preview_allocation(state, deltas, revision)
	check(not result.ok and result.code == code, "Allocation rejects " + code + ": " + str(result))
	check(normalized(state) == before, "Pure model never mutates input")

func run() -> void:
	var state := Stats.initial_state()
	check(Stats.validate_state(state), "Initial state valid")
	var view := Stats.summary(state)
	check(view.level == 1 and view.revision == 0 and view.unspent_points == 0 and view.earned_points == 0, "Level one starts with no earned points")
	check(view.attributes.size() == 6 and view.effects_status == "planned", "Exactly six planned core stats")
	for key in Stats.KEYS: check(view.attributes[key] == 10, key + " starts at ten")
	for key in Stats.ALLOCATABLE_KEYS: check(view.allocations[key] == 0, key + " has no allocation")
	check(not view.allocations.has("LUK") and view.luck_xp == 0 and view.luck_xp_required == 100 and view.luck_progress == 0, "Luck starts at ten with separate 0/100 XP")
	check(view.planned_effects.physical_power == 20 and view.planned_effects.spell_power == 20, "Baseline STR and INT predictions")
	check(view.planned_effects.max_hp == 100 and view.planned_effects.max_mana == 50 and view.planned_effects.mana_recovery_per_second == 1, "Baseline VIT and WIS predictions")
	check(is_equal_approx(view.planned_effects.accuracy_chance, 0.90) and is_equal_approx(view.planned_effects.auto_dodge_chance, 0.05) and is_equal_approx(view.planned_effects.critical_chance, 0.05), "Baseline AGI and LUK predictions")
	check(view.planned_effects.resilience == 0 and view.planned_effects.rare_drop_multiplier == 1, "Baseline resilience and rare multiplier")
	view.allocations.STR = 99; view.attributes.STR = 99; view.planned_effects.max_hp = 0
	check(state.allocations.STR == 0 and Stats.summary(state).attributes.STR == 10 and Stats.summary(state).planned_effects.max_hp == 100, "Returned summary is detached")
	expect_failure(state, {"STR":1}, 0, "insufficient_points")
	var advance := Stats.plan_level_advance(state, 3, 0)
	check(advance.ok and advance.points_awarded == 10 and advance.unspent_points == 10 and advance.revision == 1, "Skipped levels award five per earned level")
	check(state.level == 1, "Level plan remains pure")
	state = advance.next_state
	var duplicate := Stats.plan_level_advance(state, 3, 1)
	check(duplicate.ok and duplicate.duplicate and duplicate.points_awarded == 0 and duplicate.revision == 1 and not duplicate.has("next_state"), "Same level is unchanged without repeated awards")
	check(Stats.plan_level_advance(state, 2, 1).code == "level_not_increased", "Lower level rejected")
	check(Stats.plan_level_advance(state, 3, 0).code == "stale_revision", "Stale level notification rejected")
	for value in [true, false, "4", 3.5, -1, 0, null, {}, [], Stats.MAX_LEVEL + 1]:
		check(Stats.plan_level_advance(state, value, 1).code == "invalid_level", "Invalid level rejected: " + str(value))
	for value in [true, "1", 1.5, -1, null, {}, []]: expect_failure(state, {"STR":1}, value, "invalid_revision")
	expect_failure(state, {"STR":1}, 0, "stale_revision")
	for value in [true, [], "STR", null, 1]: expect_failure(state, value, 1, "invalid_allocation")
	for value in [true, "1", -1, 0.5, INF, NAN, null, {}, [], 50000]: expect_failure(state, {"STR":value}, 1, "invalid_allocation")
	expect_failure(state, {"strength":1}, 1, "unknown_stat")
	expect_failure(state, {1:1}, 1, "unknown_stat")
	expect_failure(state, {}, 1, "empty_allocation")
	expect_failure(state, Stats.empty_allocation(), 1, "empty_allocation")
	expect_failure(state, {"STR":6, "AGI":5}, 1, "insufficient_points")
	var plan := Stats.preview_allocation(state, {"STR":4, "AGI":1, "VIT":1, "INT":2, "WIS":2}, 1)
	check(plan.ok and plan.unspent_points == 0 and plan.points_assigned == 10 and plan.revision == 2, "All five eligible stats freely allocated in one plan")
	check(plan.attributes.STR == 14 and plan.attributes.INT == 12 and state.allocations.STR == 0, "Allocation preview correct and detached")
	state = plan.next_state
	check(Stats.validate_state(state), "Allocated candidate valid")
	expect_failure(state, {"STR":1}, 1, "stale_revision")
	expect_failure(state, {"STR":1}, 2, "insufficient_points")
	advance = Stats.plan_level_advance(state, 5, 2)
	check(advance.ok and advance.points_awarded == 10 and advance.earned_points == 20 and advance.unspent_points == 10 and advance.allocations.STR == 4, "Later levels preserve allocations and only add their new points")
	var whole_float := Stats.preview_allocation(advance.next_state, {"WIS":1.0}, 3.0)
	check(whole_float.ok and whole_float.allocations.WIS == 3, "JSON whole-number floats accepted without accepting fractions")
	# Strong current-schema validation: no defaults repair malformed state.
	for field in ["version", "level", "revision", "allocations", "luck"]:
		var bad := state.duplicate(true); bad.erase(field)
		check(not Stats.validate_state(bad), "Missing field rejected: " + field)
	for field in ["version", "level", "revision"]:
		for value in [true, null, "1", -1, 1.5, INF, NAN]:
			var bad := state.duplicate(true); bad[field] = value
			check(not Stats.validate_state(bad), "Invalid scalar rejected: " + field + " " + str(value))
	var bad := state.duplicate(true); bad.extra = 0; check(not Stats.validate_state(bad), "Extra state field rejected")
	bad = state.duplicate(true); bad.allocations.erase("AGI"); check(not Stats.validate_state(bad), "Missing stat rejected")
	bad = state.duplicate(true); bad.allocations.extra = 0; check(not Stats.validate_state(bad), "Unknown stat rejected")
	bad = state.duplicate(true); bad.allocations.STR += 1; check(not Stats.validate_state(bad), "Overallocated state rejected")
	bad = state.duplicate(true); bad.allocations.STR = true; check(not Stats.validate_state(bad), "Boolean stat rejected")
	bad = state.duplicate(true); bad.allocations.STR = 1.25; check(not Stats.validate_state(bad), "Fractional stat rejected")
	bad = state.duplicate(true); bad.revision = Stats.MAX_REVISION + 1; check(not Stats.validate_state(bad), "Revision overflow rejected")
	bad = state.duplicate(true); bad.level = Stats.MAX_LEVEL + 1; check(not Stats.validate_state(bad), "Level safety bound enforced")
	# Each effect changes only with its documented owning attribute.
	var base: Dictionary = Stats.plan_level_advance(Stats.initial_state(), Stats.MAX_LEVEL, 0).next_state
	var effects: Dictionary = Stats.summary(base).planned_effects
	var keys_by_stat := {"STR":["physical_power"], "AGI":["accuracy_chance", "auto_dodge_chance"], "VIT":["max_hp", "resilience"], "INT":["spell_power"], "WIS":["max_mana", "mana_recovery_per_second"], "LUK":["critical_chance", "rare_drop_multiplier"]}
	for key in Stats.ALLOCATABLE_KEYS:
		var high := Stats.preview_allocation(base, {key:4995}, 1)
		check(high.ok and high.unspent_points == 0, "All earned points may enter " + key)
		for effect in effects:
			check(high.planned_effects[effect] > effects[effect] if effect in keys_by_stat[key] else high.planned_effects[effect] == effects[effect], key + " effect ownership " + effect)
		check(high.planned_effects.accuracy_chance < 0.99 and high.planned_effects.auto_dodge_chance < 0.35 and high.planned_effects.resilience < 0.30 and high.planned_effects.critical_chance < 0.30 and high.planned_effects.rare_drop_multiplier < 1.5, "Diminishing effects remain below explicit caps")
	var one: float = Stats.preview_allocation(base, {"AGI":1}, 1).planned_effects.auto_dodge_chance
	var two: float = Stats.preview_allocation(base, {"AGI":2}, 1).planned_effects.auto_dodge_chance
	check(one - effects.auto_dodge_chance > two - one, "Additional AGI has diminishing marginal chance gain")
	luck_cases()
	print("CHARACTER STATS CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func luck_cases() -> void:
	var state := Stats.plan_level_advance(Stats.initial_state(), 4, 0).next_state as Dictionary
	for value in [0, 1, -1, true, 1.5]: expect_failure(state, {"LUK":value}, 1, "luck_not_allocatable")
	expect_failure(state, {"STR":1, "LUK":0}, 1, "luck_not_allocatable")
	var old := {"version":1, "level":4, "revision":7, "allocations":{"STR":2, "AGI":1, "VIT":1, "INT":3, "WIS":1, "LUK":4}}
	var migrated := Stats.migrate_legacy_state(old)
	var view := Stats.summary(migrated)
	check(view.ok and view.attributes.LUK == 10 and view.luck_total_xp == 0 and view.unspent_points == 7 and view.spent_points == 8 and view.revision == 8, "Old Luck points refund into free balance, never XP")
	check(migrated.allocations.STR == 2 and migrated.allocations.INT == 3 and old.allocations.LUK == 4, "Refund preserves other five and original input")
	check(Stats.migrate_legacy_state(migrated) == migrated, "Stat migration is idempotent")
	var forged := old.duplicate(true); forged.luck = {"total_xp":100}
	check(Stats.migrate_legacy_state(forged).is_empty(), "Undocumented old XP fields cannot become genuine experience")
	for total in [0, 99, 100, 224, 225, 374, 375]:
		var progress := Stats.luck_progression(total)
		var expected: Dictionary = {0:[10,0,100], 99:[10,99,100], 100:[11,0,125], 224:[11,124,125], 225:[12,0,150], 374:[12,149,150], 375:[13,0,175]}
		check(progress.value == expected[total][0] and progress.xp == expected[total][1] and progress.required == expected[total][2], "Exact modest Luck threshold/carry for XP " + str(total))
		check(progress.progress >= 0 and progress.progress < 1, "Luck fraction remains bounded")
	var before = normalized(state)
	var event := Stats.plan_luck_event(state, "first", "chest-a", "first_discovery", "", 1)
	check(event.ok and event.luck_xp_awarded == 25 and event.luck_xp == 25 and event.luck_xp_required == 100 and event.luck_progress == 0.25, "First discovery earns full configured XP")
	check(normalized(state) == before and event.unspent_points == 15 and event.level == 4, "Luck preview is pure and independent of character points/level")
	state = event.next_state
	event = Stats.plan_luck_event(state, "first", "chest-a", "first_discovery", "", 1)
	check(event.ok and event.duplicate and event.luck_xp_awarded == 0 and not event.has("next_state") and event.revision == 2, "Exact replay with original stale revision is idempotent")
	check(Stats.plan_luck_event(state, "first", "chest-b", "first_discovery", "", 2).code == "event_conflict", "Event ID cannot change source")
	check(Stats.plan_luck_event(state, "first", "chest-a", "refill", "cycle-1", 2).code == "event_conflict", "Event ID cannot change event type")
	check(Stats.plan_luck_event(state, "different-id", "chest-a", "first_discovery", "", 2).code == "discovery_already_recorded", "New event ID cannot farm rediscovery")
	check(Stats.plan_luck_event(state, "refill", "chest-b", "refill", "cycle-1", 2).code == "undiscovered_source", "Refill requires first discovery")
	check(Stats.plan_luck_event(state, "refill", "chest-a", "refill", "cycle-1", 1).code == "stale_revision", "New stale XP event rejected")
	for kind in ["open", "storage", "loot", "unknown", "", true, null, 25]:
		check(Stats.plan_luck_event(state, "bad-kind", "chest-a", kind, "", 2).code == "invalid_event_kind", "Only explicit approved event kinds allowed")
	for id in ["", " padded ", true, null, 1, {}, "x".repeat(129)]:
		check(Stats.plan_luck_event(state, id, "chest-a", "first_discovery", "", 2).code == "invalid_event", "Malformed event ID rejected")
		check(Stats.plan_luck_event(state, "valid", id, "first_discovery", "", 2).code == "invalid_event", "Malformed source ID rejected")
	check(Stats.plan_luck_event(state, "refill", "chest-a", "refill", "", 2).code == "invalid_refill", "Refill needs stable cycle ID")
	check(Stats.plan_luck_event(state, "new", "chest-b", "first_discovery", "cycle", 2).code == "invalid_refill", "First discovery cannot impersonate refill")
	before = normalized(state)
	for index in range(5):
		event = Stats.plan_luck_event(state, "empty-%d" % index, "chest-a", "empty_open", "", 2)
		check(event.ok and event.code == "no_luck_xp" and event.luck_xp_awarded == 0 and not event.has("next_state") and event.revision == 2, "Empty openings never award or mutate")
	check(normalized(state) == before, "Empty opening spam preserves exact state")
	event = Stats.plan_luck_event(state, "refill-1", "chest-a", "refill", "cycle-1", 2)
	check(event.ok and event.luck_xp_awarded == 5 and event.luck_total_xp == 30, "Verified new refill earns reduced XP")
	state = event.next_state
	check(Stats.plan_luck_event(state, "refill-replay", "chest-a", "refill", "cycle-1", 3).code == "refill_already_recorded", "New event ID cannot farm same refill")
	check(Stats.plan_luck_event(state, "refill-1", "chest-a", "refill", "cycle-2", 3).code == "event_conflict", "Event ID cannot impersonate a later refill")
	check(Stats.plan_luck_event(state, "refill-1", "chest-a", "refill", "cycle-1", 2).duplicate, "Exact refill retry awards nothing")
	state = Stats.plan_luck_event(state, "refill-2", "chest-a", "refill", "cycle-2", 3).next_state
	check(Stats.summary(state).luck_xp == 35, "A genuinely new cycle may earn reduced XP")
	for index in range(3):
		state = Stats.plan_luck_event(state, "new-%d" % index, "new-source-%d" % index, "first_discovery", "", state.revision).next_state
	view = Stats.summary(state)
	check(view.attributes.LUK == 11 and view.luck_xp == 10 and view.luck_xp_required == 125 and view.luck_total_xp == 110, "Luck growth preserves overflow toward next modest threshold")
	check(view.unspent_points == 15 and view.level == 4 and view.spent_points == 0, "Luck growth never grants or consumes free points")
	check(view.planned_effects.critical_chance > 0.05 and view.planned_effects.rare_drop_multiplier > 1 and view.planned_effects.physical_power == 20, "Earned Luck alone changes its planned effects")
	var advanced := Stats.plan_level_advance(state, 5, state.revision)
	check(advanced.luck_total_xp == 110 and advanced.attributes.LUK == 11 and advanced.unspent_points == 20, "Character level does not change Luck XP")
	check(Stats.migrate_legacy_state(state) == state, "Validated genuine XP state survives migration intact")
	for field in ["version", "total_xp", "event_receipts"]:
		var bad := state.duplicate(true); bad.luck.erase(field); check(not Stats.validate_state(bad), "Missing Luck field rejected " + field)
	for value in [-1, 1, true, null, "110", 1.5, INF, NAN]:
		var bad := state.duplicate(true); bad.luck.total_xp = value; check(not Stats.validate_state(bad), "XP must exactly reconcile to receipts")
	var bad := state.duplicate(true); bad.allocations.LUK = 0; check(not Stats.validate_state(bad), "Even zero Luck allocation forbidden in current schema")
	bad = state.duplicate(true); bad.luck.extra = 0; check(not Stats.validate_state(bad), "Unknown Luck field rejected")
	bad = state.duplicate(true); bad.luck.event_receipts.first.xp = 100; bad.luck.total_xp += 75; check(not Stats.validate_state(bad), "Balanced arbitrary XP injection rejected")
	bad = state.duplicate(true); bad.luck.event_receipts.first.reward_revision = 2; check(not Stats.validate_state(bad), "Unknown reward revision rejected")
	bad = state.duplicate(true); bad.luck.event_receipts["copy"] = bad.luck.event_receipts.first.duplicate(true); bad.luck.total_xp += 25; check(not Stats.validate_state(bad), "Duplicated discovery receipt rejected")
	bad = state.duplicate(true); bad.luck.event_receipts["copy"] = bad.luck.event_receipts["refill-1"].duplicate(true); bad.luck.total_xp += 5; check(not Stats.validate_state(bad), "Duplicated refill cycle rejected")
	bad = state.duplicate(true); bad.luck.event_receipts.erase("first"); bad.luck.total_xp -= 25; check(not Stats.validate_state(bad), "Refills without their first discovery rejected")
	bad = state.duplicate(true); bad.luck.event_receipts["empty"] = {"source_id":"chest-a", "kind":"empty_open", "refill_id":"", "xp":0, "reward_revision":1}; check(not Stats.validate_state(bad), "Empty openings must not accumulate receipts")
