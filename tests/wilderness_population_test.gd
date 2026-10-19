extends SceneTree
const Population=preload("res://src/wilderness_population.gd")
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(message)
func _initialize() -> void:
 var value=Population.initial()
 check(Population.valid(value),"Five fresh independent spawns")
 for group in Population.GROUPS:
  var lives: Array=[]
  for index in Population.GROUPS[group]: lives.append({"index":index,"generation":0})
  var plan=Population.plan_defeats(value,group,lives,"letter_pending",1000)
  check(plan.ok and plan.accepted.size()==lives.size(),"Monsters reward without quest")
  value=plan.next_state
  check(value.quest_kills[group]==0,"Pre-accept kills never count toward assignment")
  check(not Population.ready(value,group,0,1024) and Population.ready(value,group,0,1025),"Persistent exact cooldown")
  var replay=Population.plan_defeats(value,group,lives,Population.STAGES[group],2000)
  check(replay.ok and replay.accepted.is_empty() and replay.next_state==value,"Old incarnation never repays after cooldown")
  for life in lives: life.generation=1
  check(not Population.plan_defeats(value,group,lives,Population.STAGES[group],1024).ok,"Future life cannot die before respawn")
  plan=Population.plan_defeats(value,group,lives,Population.STAGES[group],1025)
  check(plan.ok and plan.accepted.size()==lives.size(),"New group life pays")
  value=plan.next_state
  check(value.quest_kills[group]==lives.size(),"Only accepted quest gets kills")
 check(value.spawns.size()==5 and Population.valid(value),"Bounded records remain valid")
 var before=value.duplicate(true)
 check(not Population.plan_defeats(value,"south_meadow_slimes",[{"index":0,"generation":999}],"first_combat_active",5000).ok,"Forged future incarnation rejected")
 check(not Population.plan_defeats(value,"south_meadow_slimes",[{"index":0,"generation":2},{"index":99,"generation":0}],"first_combat_active",5000).ok and value==before,"Invalid mixed batch never partially commits")
 var corrupt=value.duplicate(true); corrupt.spawns["south_meadow_slimes:0"].generation=-1
 check(not Population.valid(corrupt),"Negative generation rejected")
 corrupt=value.duplicate(true); corrupt.spawns["south_meadow_slimes:0"].generation=1.5
 check(not Population.valid(corrupt),"Fractional generation rejected")
 corrupt=value.duplicate(true); corrupt.quest_kills.south_meadow_slimes=4
 check(not Population.valid(corrupt),"Impossible quest credit rejected")
 print("WILDERNESS POPULATION CHECKS: %d; failures: %d" % [checks,failures]); quit(1 if failures else 0)
