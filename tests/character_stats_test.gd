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
	for key in Stats.KEYS: check(view.attributes[key] == 10 and view.allocations[key] == 0, key + " starts at ten")
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
	var plan := Stats.preview_allocation(state, {"STR":4, "AGI":1, "VIT":1, "INT":2, "WIS":1, "LUK":1}, 1)
	check(plan.ok and plan.unspent_points == 0 and plan.points_assigned == 10 and plan.revision == 2, "All six stats freely allocated in one plan")
	check(plan.attributes.STR == 14 and plan.attributes.INT == 12 and state.allocations.STR == 0, "Allocation preview correct and detached")
	state = plan.next_state
	check(Stats.validate_state(state), "Allocated candidate valid")
	expect_failure(state, {"STR":1}, 1, "stale_revision")
	expect_failure(state, {"STR":1}, 2, "insufficient_points")
	advance = Stats.plan_level_advance(state, 5, 2)
	check(advance.ok and advance.points_awarded == 10 and advance.earned_points == 20 and advance.unspent_points == 10 and advance.allocations.STR == 4, "Later levels preserve allocations and only add their new points")
	var whole_float := Stats.preview_allocation(advance.next_state, {"LUK":1.0}, 3.0)
	check(whole_float.ok and whole_float.allocations.LUK == 2, "JSON whole-number floats accepted without accepting fractions")
	# Strong current-schema validation: no defaults repair malformed state.
	for field in ["version", "level", "revision", "allocations"]:
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
	for key in Stats.KEYS:
		var high := Stats.preview_allocation(base, {key:4995}, 1)
		check(high.ok and high.unspent_points == 0, "All earned points may enter " + key)
		for effect in effects:
			check(high.planned_effects[effect] > effects[effect] if effect in keys_by_stat[key] else high.planned_effects[effect] == effects[effect], key + " effect ownership " + effect)
		check(high.planned_effects.accuracy_chance < 0.99 and high.planned_effects.auto_dodge_chance < 0.35 and high.planned_effects.resilience < 0.30 and high.planned_effects.critical_chance < 0.30 and high.planned_effects.rare_drop_multiplier < 1.5, "Diminishing effects remain below explicit caps")
	var one: float = Stats.preview_allocation(base, {"AGI":1}, 1).planned_effects.auto_dodge_chance
	var two: float = Stats.preview_allocation(base, {"AGI":2}, 1).planned_effects.auto_dodge_chance
	check(one - effects.auto_dodge_chance > two - one, "Additional AGI has diminishing marginal chance gain")
	print("CHARACTER STATS CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
