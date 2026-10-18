extends RefCounted
const Stats = preload("res://src/character_stats.gd")
const MAX_REVISION := 1000000000
static func limits(stats: Dictionary) -> Dictionary:
	var effects: Dictionary = Stats.summary(stats).planned_effects
	return {"hp":int(effects.max_hp), "mana":int(effects.max_mana), "mana_recovery":float(effects.mana_recovery_per_second)}
static func initial_state(stats: Dictionary) -> Dictionary:
	var cap := limits(stats)
	return {"version":1,"revision":0,"hp":cap.hp,"mana":float(cap.mana),"skills":[0.0,0.0,0.0],"potion":0.0}
static func valid(value, stats: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 6 or not Stats.validate_state(stats): return false
	if value.get("version") != 1 or value.get("version") is bool: return false
	if not number(value.get("revision"),0,MAX_REVISION) or value.revision != floor(value.revision): return false
	var cap := limits(stats)
	if not number(value.get("hp"),0,cap.hp) or value.hp != floor(value.hp) or not number(value.get("mana"),0,cap.mana): return false
	if not value.get("skills") is Array or value.skills.size() != 3: return false
	for cooldown in value.skills:
		if not number(cooldown,0,30): return false
	return number(value.get("potion"),0,3)
static func number(value, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum
