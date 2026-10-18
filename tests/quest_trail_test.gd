extends SceneTree
const Trail=preload("res://src/quest_trail.gd")
const Save=preload("res://src/bedroom_save.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String):
 checks+=1
 if not ok: failures+=1; push_error(why)
func _initialize(): call_deferred("run")
func run():
 var w=preload("res://src/starter_world.gd").new()
 w.state.path="user://trail_%d.json"%Time.get_ticks_usec()
 var d=Save.Draft.new();d.set_base("female");d.character_class="Mage";d.username="TrailTester"
 check(w.state.create(d.payload()),"Create route geometry test")
 root.add_child(w);w.set_process(false);await process_frame
 for stage in ["first_combat_active","forest_patrol_active"]:
  var route=Trail.road(stage)
  check(route.size()>3,"Assignment has road waypoints")
  for i in range(route.size()-1):
   var a:Vector2=route[i];var b:Vector2=route[i+1]
   var count=maxi(1,ceili(a.distance_to(b)/5))
   for j in range(count+1):check(w.can_stand(a.lerp(b,float(j)/count)),"Gold trail cannot point through walls or terrain: "+stage)
 var before=JSON.stringify(w.state.snapshot())
 var node=Trail.new();root.add_child(node)
 node.update_quest("first_combat_active",Vector2(1000,2020),w.encounter.enemies)
 check(node.visible and node.branches.size()==3,"Active assignment marks each living slime branch")
 for branch in node.branches:
  for i in range(branch.size()-1):
   for j in 100:check(w.can_stand(branch[i].lerp(branch[i+1],float(j)/99)),"Meadow branch remains walkable")
 w.encounter.enemies[0].hp=0
 node.update_quest("first_combat_active",Vector2.ZERO,w.encounter.enemies)
 check(node.branches.size()==2,"Defeated spawn branch disappears")
 for stage in ["awaiting_letter","first_combat_pending","return_guild_first_combat","forest_patrol_complete"]:
  node.update_quest(stage,Vector2.ZERO,w.encounter.enemies)
  check(not node.visible and node.route.is_empty(),"No false trail before acceptance or after completion")
 check(JSON.stringify(w.state.snapshot())==before,"Wayfinding never mutates saved progress")
 DirAccess.remove_absolute(w.state.path);node.free();w.free()
 print("QUEST TRAIL: %d checks; failures: %d"%[checks,failures]);quit(1 if failures else 0)
