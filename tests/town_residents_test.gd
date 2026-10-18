extends SceneTree
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
func check(ok:bool,text:String)->void:
 checks += 1
 if not ok: failures += 1; push_error(text)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(844,390)
 var room = load("res://src/starter_world.gd").new()
 room.state.path = "user://residents_"+str(Time.get_ticks_usec())+".json"
 var d = Draft.new();d.set_base("male");d.character_class="Warrior";d.username="ResidentTester"
 check(room.state.create(d.payload()),"Create isolated resident fixture")
 root.add_child(room);room.set_process(false)
 for tick in 3: await process_frame
 check(room.resident_ids.size()==4,"Four actual static attendants loaded")
 for id in room.resident_ids:
  var point:Vector2=room.anchors[id]
  check(room.can_stand(point),id+" stand is walkable")
  for delta in [Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:check(room.can_stand(point+delta),id+" has input clearance")
  room.player=point+Vector2(100,0);room._update_actor()
  check(room.nearest_prop()!=id,id+" respects72px interaction reach")
  room.player=point;room._update_actor()
  check(room.nearest_prop()==id,id+" targets correct resident")
  check(room.state.set_location("starter_region",point),id+" persist approach")
  var before:String=JSON.stringify(room.state.snapshot())
  room.interact()
  for tick in 3:await process_frame
  check(is_instance_valid(room.overlay),id+" conversation opens")
  check(room.overlay.body_label.text.length()>30,id+" has meaningful town guidance")
  check(room.overlay.choices.get_child_count()==0,id+" does not invent rewards or services")
  check(not room.joystick.input_enabled,id+" modal clears input")
  check(JSON.stringify(room.state.snapshot())==before,id+" cannot mutate quest or inventory")
  room._close_overlay()
  check(room.joystick.input_enabled,id+" movement resumes")
 var path:String=room.state.path;room.free();DirAccess.remove_absolute(path)
 print("TOWN RESIDENT CHECKS: %d; failures: %d"%[checks,failures])
 quit(1 if failures else 0)
