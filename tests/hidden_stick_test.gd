extends "res://tests/tutorial_save_test.gd"
const Relic = preload("res://src/hidden_relic.gd")
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(844,390)
 for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
  var state=fixture(selected_class)
  check(Relic.valid(state.hidden_relic),"Persistent tree initialized")
  var selected: String=state.hidden_relic.tree_id
  check(state.load_saved() and state.hidden_relic.tree_id==selected,"Reload never rerolls")
  var point: Vector2=Relic.point(state.hidden_relic)
  check(not state.claim_hidden_stick(selected),"Cannot claim remotely inside home")
  check(not state.receive_item(Relic.ITEM,1,"world_drop","fake-stick"),"Generic drops cannot duplicate unique relic")
  check(state.set_location("starter_region",point),"Approach assigned tree")
  fail_write(state,func(): return state.claim_hidden_stick(selected),"hidden pickup")
  check(not state.hidden_relic.claimed and state.bag[Relic.ITEM]==0,"Failure leaves find available")
  check(state.claim_hidden_stick(selected),"Search grants one stick")
  var once:=snap(state)
  check(state.claim_hidden_stick(selected) and snap(state)==once,"Repeat search grants nothing")
  check(state.get_item_details(Relic.ITEM,"bag").binding=="character","Find bound to character")
  check(state.equip(Relic.ITEM) and state.basic_weapon_bonus()==988,"All six classes equip real OP weapon")
  check(state.unequip() and state.transfer(Relic.ITEM,true) and state.load_saved(),"Unequip/store/reload safe")
  check(state.chest[Relic.ITEM]==1 and state.hidden_relic.claimed,"Storage does not reset find")
  check(state.transfer(Relic.ITEM,false) and state.equip(Relic.ITEM),"Retrieve and re-equip unique instance")
  var fight=preload("res://src/wilderness_encounter.gd").new()
  fight.configure({},selected_class,state.get_stat_summary(),state.basic_weapon_bonus())
  check(fight.attack(fight.enemies[0].position+Vector2(0,40),func(_p):return true),"Basic strike hits")
  check(fight.enemies[0].hp==0,"OP damage actually defeats monster")
  var previous_gold: int=state.wallet_gold
  var previous_stats: Dictionary=state.stats.duplicate(true)
  check(state.wallet_gold==previous_gold and state.stats==previous_stats,"Relic does not modify currency or core stats")
  var bad:=snap(state); bad.hidden_relic.claimed=false
  reject_corrupt(state,bad,"Receipt cannot be reset while item exists")
  # Genuine pre-relic current snapshot: no unique item, no extra key.
  var legacy=fixture(selected_class)
  var old:=snap(legacy); old.version=11; old.erase("hidden_relic")
  old.bag.erase(Relic.ITEM); old.chest.erase(Relic.ITEM)
  write_json(legacy.path,old)
  check(legacy.load_saved() and Relic.valid(legacy.hidden_relic),"v11 migration chooses one tree")
  var migrated:=snap(legacy)
  check(legacy.load_saved() and snap(legacy)==migrated,"Migrated tree stable")
 var state=fixture()
 var world=preload("res://src/starter_world.gd").new(); world.state=state
 root.add_child(world); world.set_process(false); await process_frame
 for id in Relic.TREES:
  var p: Vector2=Relic.TREES[id]
  check(world.can_stand(p),"Tree pickup reachable "+id)
  var route: Array = find_route(world,Vector2(850,1230),p)
  check(not route.is_empty(),"Connected to protected forest path "+id)
  world.player=Vector2(850,1230)
  for waypoint in route:
   while world.player.distance_to(waypoint)>0.1:
    var offset: Vector2=waypoint-world.player
    var before: Vector2=world.player
    world.move_player(offset.limit_length(7))
    if world.player.distance_to(before)<0.01:
     check(false,"Collision stops actual route "+id)
     break
  check(world.player.distance_to(p)<0.2,"Actual collision movement reaches roots "+id)
  for offset in [Vector2(0,32),Vector2(32,0),Vector2(-32,0)]:
   check(world.can_stand(p+offset),"Approach clearance "+id+str(offset))
 world.queue_free(); await process_frame
 for path in paths: DirAccess.remove_absolute(path)
 print("HIDDEN STICK CHECKS: %d; failures: %d" % [checks,failures])
 quit(1 if failures else 0)

func find_route(world, start: Vector2, target: Vector2) -> Array:
 var queue: Array[Vector2] = [start]
 var visited := {start:start}
 var index:=0
 var end:=Vector2.INF
 while index < queue.size() and index < 15000:
  var point: Vector2=queue[index]; index+=1
  if point.distance_to(target)<24 and world.encounter.line_clear(point,target,world.can_stand):
   end=point; break
  for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
   var next: Vector2=point+direction*16
   if next.x<180 or next.x>1000 or next.y<880 or next.y>1650 or visited.has(next): continue
   if not world.can_stand(next) or not world.can_stand((point+next)*0.5): continue
   visited[next]=point
   queue.append(next)
 if end==Vector2.INF: return []
 var result: Array=[target,end]
 while end!=start:
  end=visited[end]
  result.append(end)
 result.reverse()
 return result
