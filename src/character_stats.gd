extends RefCounted
# Pure, class-neutral stat accounting. This model never writes a save or awards
# XP. All derived numbers are provisional previews until gameplay consumes them.
const VERSION := 1
const KEYS := ["STR", "AGI", "VIT", "INT", "WIS", "LUK"]
const LABELS := {"STR":"Strength", "AGI":"Agility", "VIT":"Vitality", "INT":"Intelligence", "WIS":"Wisdom", "LUK":"Luck"}
const DESCRIPTIONS := {
	"STR":"Physical power", "AGI":"Accuracy and automatic dodge", "VIT":"Maximum HP and resilience",
	"INT":"Spell power", "WIS":"Maximum mana and mana recovery", "LUK":"Critical chance and rare-drop chance"
}
const BASE_ATTRIBUTE := 10
const POINTS_PER_LEVEL := 5
# Serialization safety limit, not a promised level cap or XP curve.
const MAX_LEVEL := 1000
const MAX_REVISION := 1000000000
const TUNING := {
	"physical_power_per_str":2.0, "spell_power_per_int":2.0,
	"base_hp":50.0, "hp_per_vit":5.0, "base_mana":20.0, "mana_per_wis":3.0,
	"mana_recovery_per_wis":0.1, "diminishing_scale":100.0,
	"base_accuracy":0.90, "bonus_accuracy_cap":0.09,
	"base_auto_dodge":0.05, "bonus_auto_dodge_cap":0.30,
	"resilience_cap":0.30, "base_critical":0.05, "bonus_critical_cap":0.25,
	"rare_drop_bonus_cap":0.50
}
const EFFECTS_STATUS := "planned"

static func initial_state() -> Dictionary:
	return {"version":VERSION, "level":1, "revision":0, "allocations":empty_allocation()}

static func empty_allocation() -> Dictionary:
	var result := {}
	for key in KEYS: result[key] = 0
	return result

static func validate_state(value) -> bool:
	if not value is Dictionary or value.size() != 4: return false
	if not _whole(value.get("version"), VERSION, VERSION): return false
	if not _whole(value.get("level"), 1, MAX_LEVEL) or not _whole(value.get("revision"), 0, MAX_REVISION): return false
	if not value.get("allocations") is Dictionary or value.allocations.size() != KEYS.size(): return false
	var total := 0
	var earned := POINTS_PER_LEVEL * (int(value.level) - 1)
	for key in KEYS:
		if not _whole(value.allocations.get(key), 0, earned): return false
		total += int(value.allocations[key])
	return total <= earned

static func summary(value) -> Dictionary:
	if not validate_state(value):
		return {"ok":false, "code":"invalid_stats", "message":"Your character stats could not be read safely."}
	var attributes := {}
	var spent := 0
	for key in KEYS:
		attributes[key] = BASE_ATTRIBUTE + int(value.allocations[key])
		spent += int(value.allocations[key])
	var earned := POINTS_PER_LEVEL * (int(value.level) - 1)
	return {"ok":true, "code":"ready", "message":"", "level":int(value.level), "revision":int(value.revision),
		"earned_points":earned, "spent_points":spent, "unspent_points":earned - spent,
		"attributes":attributes, "allocations":value.allocations.duplicate(true),
		"planned_effects":_planned_effects(attributes), "effects_status":EFFECTS_STATUS}

# A sparse dictionary is accepted; all six attributes remain present in state.
# Arguments deliberately stay untyped at the trust boundary to reject booleans,
# fractional numbers and implicit string/integer conversions.
static func preview_allocation(value, deltas, expected_revision) -> Dictionary:
	if not validate_state(value): return _failure(value, "invalid_stats", "Your character stats could not be read safely.")
	if not _whole(expected_revision, 0, MAX_REVISION): return _failure(value, "invalid_revision", "Reopen Stats before assigning points.")
	if expected_revision != value.revision: return _failure(value, "stale_revision", "Your stats changed. Review the current values and try again.")
	if not deltas is Dictionary or deltas.size() > KEYS.size(): return _failure(value, "invalid_allocation", "Choose whole, nonnegative points for the six core stats.")
	var available: int = summary(value).unspent_points
	var amount := 0
	for key in deltas:
		if not key is String or key not in KEYS: return _failure(value, "unknown_stat", "That stat cannot receive points.")
		if not _whole(deltas[key], 0, POINTS_PER_LEVEL * (MAX_LEVEL - 1)):
			return _failure(value, "invalid_allocation", "Choose whole, nonnegative points for the six core stats.")
		amount += int(deltas[key])
	if amount <= 0: return _failure(value, "empty_allocation", "Choose at least one point to assign.")
	if amount > available: return _failure(value, "insufficient_points", "You do not have enough unspent stat points.")
	if value.revision >= MAX_REVISION: return _failure(value, "revision_limit", "Your stats cannot be changed safely.")
	var next: Dictionary = value.duplicate(true)
	for key in deltas: next.allocations[key] = int(next.allocations[key]) + int(deltas[key])
	next.revision = int(value.revision) + 1
	var result := summary(next)
	result.code = "allocation_ready"
	result["next_state"] = next
	result["points_assigned"] = amount
	return result

# Trusted future progression integration only. The caller must independently
# establish earned character level. The current game has no caller or XP system.
# Deriving total awards from level makes repeated notifications unable to re-award.
static func plan_level_advance(value, target_level, expected_revision) -> Dictionary:
	if not validate_state(value): return _failure(value, "invalid_stats", "Your character stats could not be read safely.")
	if not _whole(expected_revision, 0, MAX_REVISION): return _failure(value, "invalid_revision", "Refresh the character state before recording a level.")
	if expected_revision != value.revision: return _failure(value, "stale_revision", "Your stats changed. Refresh before recording a level.")
	if not _whole(target_level, 1, MAX_LEVEL): return _failure(value, "invalid_level", "The earned character level is invalid.")
	if target_level < value.level: return _failure(value, "level_not_increased", "A recorded character level cannot be decreased.")
	if target_level == value.level:
		var unchanged := summary(value)
		unchanged.code = "level_already_recorded"
		unchanged["duplicate"] = true
		unchanged["points_awarded"] = 0
		return unchanged
	if value.revision >= MAX_REVISION: return _failure(value, "revision_limit", "Your stats cannot be changed safely.")
	var next: Dictionary = value.duplicate(true)
	next.level = int(target_level)
	next.revision = int(value.revision) + 1
	var result := summary(next)
	result.code = "level_ready"
	result["next_state"] = next
	result["points_awarded"] = POINTS_PER_LEVEL * (int(target_level) - int(value.level))
	return result

static func _planned_effects(attributes: Dictionary) -> Dictionary:
	var agility := _diminishing(int(attributes.AGI))
	var vitality := _diminishing(int(attributes.VIT))
	var luck := _diminishing(int(attributes.LUK))
	return {
		"physical_power":TUNING.physical_power_per_str * attributes.STR,
		"spell_power":TUNING.spell_power_per_int * attributes.INT,
		"max_hp":TUNING.base_hp + TUNING.hp_per_vit * attributes.VIT,
		"max_mana":TUNING.base_mana + TUNING.mana_per_wis * attributes.WIS,
		"mana_recovery_per_second":TUNING.mana_recovery_per_wis * attributes.WIS,
		"accuracy_chance":clampf(TUNING.base_accuracy + TUNING.bonus_accuracy_cap * agility, 0.0, 1.0),
		"auto_dodge_chance":clampf(TUNING.base_auto_dodge + TUNING.bonus_auto_dodge_cap * agility, 0.0, 1.0),
		"resilience":clampf(TUNING.resilience_cap * vitality, 0.0, 1.0),
		"critical_chance":clampf(TUNING.base_critical + TUNING.bonus_critical_cap * luck, 0.0, 1.0),
		"rare_drop_multiplier":1.0 + TUNING.rare_drop_bonus_cap * luck
	}

static func _diminishing(attribute: int) -> float:
	var extra := maxf(attribute - BASE_ATTRIBUTE, 0.0)
	return extra / (extra + TUNING.diminishing_scale)

static func _failure(value, code: String, message: String) -> Dictionary:
	var result := summary(value)
	result.ok = false
	result.code = code
	result.message = message
	return result

static func _whole(value, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and value == floor(float(value))
