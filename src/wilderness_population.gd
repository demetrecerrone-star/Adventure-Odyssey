extends RefCounted
# Five fixed records: a monotonic paid-life counter and a persisted respawn deadline.
# A dead simulation life can never claim the next life by waiting or reloading.
const GROUPS := {"south_meadow_slimes":3,"west_forest_patrol":2}
const STAGES := {"south_meadow_slimes":"first_combat_active","west_forest_patrol":"forest_patrol_active"}
const RESPAWN_SECONDS := 45
const MAX_GENERATION := 100000000
static func key(group: String, index: int) -> String: return "%s:%d" % [group,index]
static func initial(legacy: Dictionary = {}, stage: String = "") -> Dictionary:
 var result := {"version":1,"spawns":{},"quest_kills":{}}
 for group in GROUPS:
  result.quest_kills[group] = 0
  for index in GROUPS[group]:
   var paid := legacy.has("quest_v1:"+key(group,index))
   result.spawns[key(group,index)] = {"generation":1 if paid else 0,"ready_at":0}
   if paid and stage == STAGES[group]: result.quest_kills[group] += 1
 return result
static func valid(value) -> bool:
 if not value is Dictionary or value.size()!=3 or value.get("version")!=1 or value.version is bool: return false
 if not value.get("spawns") is Dictionary or value.spawns.size()!=5 or not value.get("quest_kills") is Dictionary or value.quest_kills.size()!=2: return false
 for group in GROUPS:
  if not whole(value.quest_kills.get(group),0,GROUPS[group]): return false
  var paid_lives := 0
  for index in GROUPS[group]:
   var spawn=value.spawns.get(key(group,index))
   if not spawn is Dictionary or spawn.size()!=2 or not whole(spawn.get("generation"),0,MAX_GENERATION) or not whole(spawn.get("ready_at"),0,4102444800): return false
   if spawn.generation==0 and spawn.ready_at!=0: return false
   paid_lives += int(spawn.generation)
  if int(value.quest_kills[group]) > paid_lives: return false
 return true
static func ready(value: Dictionary, group: String, index: int, now: int) -> bool:
 return now >= int(value.spawns[key(group,index)].ready_at)
static func generation(value: Dictionary, group: String, index: int) -> int:
 return int(value.spawns[key(group,index)].generation)
static func plan_defeats(value: Dictionary, group: String, lives: Array, stage: String, now: int) -> Dictionary:
 if not valid(value) or not GROUPS.has(group) or not whole(now,0,4102444800-RESPAWN_SECONDS): return {"ok":false}
 var candidate := value.duplicate(true)
 var accepted: Array = []
 for life in lives:
  if not life is Dictionary or life.size()!=2 or not whole(life.get("index"),0,GROUPS[group]-1) or not whole(life.get("generation"),0,MAX_GENERATION-1): return {"ok":false}
  var index := int(life.index)
  var spawn: Dictionary = candidate.spawns[key(group,index)]
  if life.generation < spawn.generation: continue # Paid incarnation; safe replay.
  if life.generation != spawn.generation or now < spawn.ready_at: return {"ok":false}
  spawn.generation += 1
  spawn.ready_at = now+RESPAWN_SECONDS
  accepted.append(index)
  if stage == STAGES[group]: candidate.quest_kills[group] = mini(GROUPS[group],int(candidate.quest_kills[group])+1)
 return {"ok":true,"next_state":candidate,"accepted":accepted}
static func whole(value, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=low and value<=high
