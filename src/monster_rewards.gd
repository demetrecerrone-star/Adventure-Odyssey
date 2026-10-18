extends RefCounted
# Stable quest-spawn incarnation keys. Future respawn services must issue new
# verified incarnation IDs, never reuse reload time or an arbitrary UI request.
const INCARNATION := "quest_v1"
const ENCOUNTERS := {
 "south_meadow_slimes":{"count":3,"stage":"first_combat_active","event":"first_combat_completed","gold":3,"xp":10,"sigils":1},
 "west_forest_patrol":{"count":2,"stage":"forest_patrol_active","event":"forest_patrol_completed","gold":8,"xp":35,"sigils":2}
}
static func initial(level: int = 1) -> Dictionary:
 return {"version":1,"base_level":level,"kills":{}}
static func key(encounter_id: String, index: int) -> String:
 return "%s:%s:%d" % [INCARNATION,encounter_id,index]
static func receipt(encounter_id: String, index: int) -> Dictionary:
 var row: Dictionary = ENCOUNTERS[encounter_id]
 return {"encounter_id":encounter_id,"spawn":index,"incarnation":INCARNATION,"gold":row.gold,"xp":row.xp,"sigils":row.sigils}
static func totals(value: Dictionary) -> Dictionary:
 var result := {"gold":0,"xp":0,"sigils":0}
 for reward in value.kills.values():
  for field in result: result[field] += int(reward[field])
 return result
static func summary(value: Dictionary) -> Dictionary:
 var amount: int = totals(value).xp
 var level: int = value.base_level
 while level < 1000 and amount >= required(level):
  amount -= required(level); level += 1
 return {"level":level,"xp":amount,"xp_required":required(level),"total_xp":totals(value).xp}
static func required(level: int) -> int: return 100 + (level-1)*50
static func valid(value) -> bool:
 if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or value.version is bool: return false
 if not whole(value.get("base_level"),1,1000) or not value.get("kills") is Dictionary: return false
 for id in value.kills:
  var found := false
  for encounter_id in ENCOUNTERS:
   for index in ENCOUNTERS[encounter_id].count:
    if id == key(encounter_id,index):
     var row = value.kills[id]
     if not row is Dictionary or row.size() != 6: return false
     var expected := receipt(encounter_id,index)
     for field in expected:
      if row.get(field) != expected[field] or row.get(field) is bool: return false
     found = true
  if not found: return false
 return true
static func whole(value, minimum: int, maximum: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= maximum
