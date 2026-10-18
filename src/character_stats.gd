extends RefCounted
# Pure, class-neutral accounting. Character-level points and earned Luck XP
# remain independent. No current gameplay source awards XP; effects are previews.
const VERSION := 2
const LUCK_VERSION := 1
const KEYS := ["STR", "AGI", "VIT", "INT", "WIS", "LUK"]
const ALLOCATABLE_KEYS := ["STR", "AGI", "VIT", "INT", "WIS"]
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
# Provisional independent Luck progression. Do not change historical reward
# amounts without retaining an auditable revision and an explicit migration.
const LUCK_TUNING := {"first_threshold":100, "threshold_increment":25}
const LUCK_REWARD_REVISION := 1
const LUCK_EVENT_XP := {"first_discovery":25, "refill":5, "empty_open":0}
const MAX_LUCK_EVENTS := 20000
const MAX_LUCK_XP := MAX_LUCK_EVENTS * 25

static func initial_luck() -> Dictionary:
	return {"version":LUCK_VERSION, "total_xp":0, "event_receipts":{}}

static func initial_state() -> Dictionary:
	return {"version":VERSION, "level":1, "revision":0, "allocations":empty_allocation(), "luck":initial_luck()}

static func empty_allocation() -> Dictionary:
	var result := {}
	for key in ALLOCATABLE_KEYS: result[key] = 0
	return result

static func validate_state(value) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	if not _whole(value.get("version"), VERSION, VERSION): return false
	if not _whole(value.get("level"), 1, MAX_LEVEL) or not _whole(value.get("revision"), 0, MAX_REVISION): return false
	if not _valid_allocations(value.allocations if value.has("allocations") else null, ALLOCATABLE_KEYS, int(value.level)): return false
	return _validate_luck(value.get("luck"))

static func _valid_allocations(allocations, keys: Array, level: int) -> bool:
	if not allocations is Dictionary or allocations.size() != keys.size(): return false
	var total := 0
	var earned := POINTS_PER_LEVEL * (level - 1)
	for key in keys:
		if not _whole(allocations.get(key), 0, earned): return false
		total += int(allocations[key])
	return total <= earned

# Only this exact prior schema is eligible for the Luck-point refund. Unknown
# XP fields cannot be reinterpreted as genuinely earned Luck experience.
static func migrate_legacy_state(value) -> Dictionary:
	if validate_state(value): return value.duplicate(true)
	if not value is Dictionary or value.size() != 4 or not _whole(value.get("version"), 1, 1): return {}
	if not _whole(value.get("level"), 1, MAX_LEVEL) or not _whole(value.get("revision"), 0, MAX_REVISION): return {}
	if not _valid_allocations(value.get("allocations"), KEYS, int(value.level)): return {}
	var next: Dictionary = value.duplicate(true)
	next.version = VERSION
	next.revision = mini(int(value.revision) + 1, MAX_REVISION)
	next.allocations.erase("LUK")
	next.luck = initial_luck()
	return next if validate_state(next) else {}

static func summary(value) -> Dictionary:
	if not validate_state(value):
		return {"ok":false, "code":"invalid_stats", "message":"Your character stats could not be read safely."}
	var attributes := {}
	var spent := 0
	for key in ALLOCATABLE_KEYS:
		attributes[key] = BASE_ATTRIBUTE + int(value.allocations[key])
		spent += int(value.allocations[key])
	var luck := luck_progression(int(value.luck.total_xp))
	attributes.LUK = luck.value
	var earned := POINTS_PER_LEVEL * (int(value.level) - 1)
	return {"ok":true, "code":"ready", "message":"", "level":int(value.level), "revision":int(value.revision),
		"earned_points":earned, "spent_points":spent, "unspent_points":earned - spent,
		"attributes":attributes, "allocations":value.allocations.duplicate(true),
		"luck_level":luck.level, "luck_xp":luck.xp, "luck_xp_required":luck.required,
		"luck_total_xp":int(value.luck.total_xp), "luck_progress":luck.progress,
		"planned_effects":_planned_effects(attributes), "effects_status":EFFECTS_STATUS}

static func luck_progression(total_xp: int) -> Dictionary:
	var remaining := maxi(total_xp, 0)
	var rank := 1
	var required: int = LUCK_TUNING.first_threshold
	while remaining >= required:
		remaining -= required
		rank += 1
		required = LUCK_TUNING.first_threshold + LUCK_TUNING.threshold_increment * (rank - 1)
	return {"value":BASE_ATTRIBUTE + rank - 1, "level":rank, "xp":remaining, "required":required, "progress":float(remaining) / required}

static func _validate_luck(value) -> bool:
	if not value is Dictionary or value.size() != 3 or not _whole(value.get("version"), LUCK_VERSION, LUCK_VERSION): return false
	if not _whole(value.get("total_xp"), 0, MAX_LUCK_XP): return false
	if not value.get("event_receipts") is Dictionary or value.event_receipts.size() > MAX_LUCK_EVENTS: return false
	var total := 0
	var discoveries := {}
	var refills := {}
	for event_id in value.event_receipts:
		var receipt = value.event_receipts[event_id]
		if not _valid_event_id(event_id) or not receipt is Dictionary or receipt.size() != 5: return false
		if not _valid_event_id(receipt.get("source_id")) or not receipt.get("kind") is String: return false
		if receipt.kind not in ["first_discovery", "refill"] or not receipt.get("refill_id") is String: return false
		if not _whole(receipt.get("reward_revision"), LUCK_REWARD_REVISION, LUCK_REWARD_REVISION): return false
		var amount: int = LUCK_EVENT_XP[receipt.kind]
		if not _whole(receipt.get("xp"), amount, amount): return false
		if receipt.kind == "first_discovery":
			if not receipt.refill_id.is_empty() or discoveries.has(receipt.source_id): return false
			discoveries[receipt.source_id] = true
		else:
			if not _valid_event_id(receipt.refill_id): return false
			if not refills.has(receipt.source_id): refills[receipt.source_id] = {}
			if refills[receipt.source_id].has(receipt.refill_id): return false
			refills[receipt.source_id][receipt.refill_id] = true
		total += amount
	for source_id in refills:
		if not discoveries.has(source_id): return false
	return total == value.total_xp

# Unconnected future boundary: a gameplay owner must verify real discovery or
# genuinely new refill evidence, then persist it together with this candidate.
# User input, opening storage, item transfers and arbitrary XP cannot authorize it.
static func plan_luck_event(value, event_id, source_id, kind, refill_id, expected_revision) -> Dictionary:
	if not validate_state(value): return _failure(value, "invalid_stats", "Your character stats could not be read safely.")
	if not _valid_event_id(event_id) or not _valid_event_id(source_id): return _failure(value, "invalid_event", "A valid earned-Luck event and source are required.")
	if not kind is String or kind not in LUCK_EVENT_XP: return _failure(value, "invalid_event_kind", "This event cannot award Luck experience.")
	if not refill_id is String or (kind == "refill" and not _valid_event_id(refill_id)) or (kind != "refill" and not refill_id.is_empty()):
		return _failure(value, "invalid_refill", "A genuine new refill needs its own stable reference.")
	if not _whole(expected_revision, 0, MAX_REVISION): return _failure(value, "invalid_revision", "Refresh before recording Luck experience.")
	if value.luck.event_receipts.has(event_id):
		var prior: Dictionary = value.luck.event_receipts[event_id]
		if prior.source_id != source_id or prior.kind != kind or prior.refill_id != refill_id:
			return _failure(value, "event_conflict", "This event reference already belongs to another Luck event.")
		var duplicate := summary(value)
		duplicate.code = "luck_already_recorded"
		duplicate["duplicate"] = true
		duplicate["luck_xp_awarded"] = 0
		return duplicate
	if expected_revision != value.revision: return _failure(value, "stale_revision", "Your stats changed. Refresh before recording Luck experience.")
	if kind == "empty_open":
		var unchanged := summary(value)
		unchanged.code = "no_luck_xp"
		unchanged["duplicate"] = false
		unchanged["luck_xp_awarded"] = 0
		return unchanged
	var discovered := false
	for receipt in value.luck.event_receipts.values():
		if receipt.source_id != source_id: continue
		if receipt.kind == "first_discovery": discovered = true
		if kind == "refill" and receipt.kind == "refill" and receipt.refill_id == refill_id:
			return _failure(value, "refill_already_recorded", "That refill has already awarded Luck experience.")
	if kind == "first_discovery" and discovered: return _failure(value, "discovery_already_recorded", "This source has already awarded its first-discovery experience.")
	if kind == "refill" and not discovered: return _failure(value, "undiscovered_source", "A refill requires a previously discovered source.")
	if value.revision >= MAX_REVISION: return _failure(value, "revision_limit", "Your stats cannot be changed safely.")
	if value.luck.event_receipts.size() >= MAX_LUCK_EVENTS: return _failure(value, "event_limit", "Luck experience cannot be recorded safely.")
	var next: Dictionary = value.duplicate(true)
	var amount: int = LUCK_EVENT_XP[kind]
	next.luck.total_xp = int(value.luck.total_xp) + amount
	next.luck.event_receipts[event_id] = {"source_id":source_id, "kind":kind, "refill_id":refill_id, "xp":amount, "reward_revision":LUCK_REWARD_REVISION}
	next.revision = int(value.revision) + 1
	var result := summary(next)
	result.code = "luck_ready"
	result["duplicate"] = false
	result["luck_xp_awarded"] = amount
	result["next_state"] = next
	return result

static func _valid_event_id(value) -> bool:
	return value is String and not value.strip_edges().is_empty() and value == value.strip_edges() and value.length() <= 128

# A sparse dictionary is accepted for the five free-point attributes only.
# Arguments deliberately stay untyped at the trust boundary to reject booleans,
# fractional numbers and implicit string/integer conversions.
static func preview_allocation(value, deltas, expected_revision) -> Dictionary:
	if not validate_state(value): return _failure(value, "invalid_stats", "Your character stats could not be read safely.")
	if not _whole(expected_revision, 0, MAX_REVISION): return _failure(value, "invalid_revision", "Reopen Stats before assigning points.")
	if expected_revision != value.revision: return _failure(value, "stale_revision", "Your stats changed. Review the current values and try again.")
	if not deltas is Dictionary or deltas.size() > KEYS.size(): return _failure(value, "invalid_allocation", "Choose whole, nonnegative points for the five allocatable stats.")
	var available: int = summary(value).unspent_points
	var amount := 0
	for key in deltas:
		if not key is String: return _failure(value, "unknown_stat", "That stat cannot receive points.")
		if key == "LUK": return _failure(value, "luck_not_allocatable", "Luck grows through earned experience, not free stat points.")
		if not key is String or key not in ALLOCATABLE_KEYS: return _failure(value, "unknown_stat", "That stat cannot receive points.")
		if not _whole(deltas[key], 0, POINTS_PER_LEVEL * (MAX_LEVEL - 1)):
			return _failure(value, "invalid_allocation", "Choose whole, nonnegative points for the five allocatable stats.")
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
