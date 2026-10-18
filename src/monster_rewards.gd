extends RefCounted
# Original first-discovery receipts remain fixed. Repeated lives use the bounded
# population generation counters; reload time never becomes a reward identity.
const Population = preload("res://src/wilderness_population.gd")
const INCARNATION := "quest_v1"
const ENCOUNTERS := {
 "south_meadow_slimes":{"count":3,"stage":"first_combat_active","event":"first_combat_completed","gold":3,"xp":10,"sigils":1},
 "west_forest_patrol":{"count":2,"stage":"forest_patrol_active","event":"forest_patrol_completed","gold":8,"xp":35,"sigils":2}
}
static func initial(level: int = 1) -> Dictionary:
 return {"version":2,"base_level":level,"kills":{},"population":Population.initial()}
static func key(encounter_id: String, index: int) -> String:
 return "%s:%s:%d" % [INCARNATION,encounter_id,index]
static func receipt(encounter_id: String, index: int) -> Dictionary:
 var row: Dictionary = ENCOUNTERS[encounter_id]
 return {"encounter_id":encounter_id,"spawn":index,"incarnation":INCARNATION,"gold":row.gold,"xp":row.xp,"sigils":row.sigils}
static func totals(value: Dictionary) -> Dictionary:
 var result := {"gold":0,"xp":0,"sigils":0}
 for reward in value.kills.values():
  for field in result: result[field] += int(reward[field])
 if value.has("population"):
  for group in ENCOUNTERS:
   for index in ENCOUNTERS[group].count:
    var repeats: int = int(value.population.spawns[Population.key(group,index)].generation) - (1 if value.kills.has(key(group,index)) else 0)
    result.gold += repeats*int(ENCOUNTERS[group].gold)
    result.xp += repeats*int(ENCOUNTERS[group].xp)
 return result
static func summary(value: Dictionary) -> Dictionary:
 var amount: int = totals(value).xp
 var level: int = value.base_level
 while level < 1000 and amount >= required(level):
  amount -= required(level); level += 1
 return {"level":level,"xp":amount,"xp_required":required(level),"total_xp":totals(value).xp}
static func required(level: int) -> int: return 100 + (level-1)*50
static func valid(value) -> bool:
 if not value is Dictionary or (value.get("version") != 1 and value.get("version") != 2) or value.version is bool: return false
 if value.version == 1 and value.size()!=3: return false
 if value.version == 2 and (value.size()!=4 or not Population.valid(value.get("population"))): return false
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
 if value.version == 2:
  for group in ENCOUNTERS:
   for index in ENCOUNTERS[group].count:
    var generation := Population.generation(value.population,group,index)
    if (generation > 0) != value.kills.has(key(group,index)): return false
 return true
static func migrate(value: Dictionary, stage: String) -> Dictionary:
 if not valid(value): return {}
 var result := value.duplicate(true)
 if result.version == 1:
  result.version = 2
  result.population = Population.initial(result.kills,stage)
 return result
static func whole(value, minimum: int, maximum: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= maximum
