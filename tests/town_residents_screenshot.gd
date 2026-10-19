extends SceneTree
const Draft = preload("res://src/creator/character_draft.gd")
func _initialize()->void:call_deferred("run")
func snap(name:String)->void:
 for tick in 3:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png((OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")+"/"+name)==OK)
func run()->void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 var room=load("res://src/starter_world.gd").new()
 room.state.path="user://residents_capture_"+str(Time.get_ticks_usec())+".json"
 var d=Draft.new();d.set_base("female");d.character_class="Ranger";d.username="Aeloria"
 assert(room.state.create(d.payload()))
 assert(room.state.transfer("ranger_01_weapon",false) and room.state.equip("ranger_01_weapon"))
 root.add_child(room);room.set_process(false)
 for id in room.resident_ids:
  room.player=room.anchors[id];room._update_actor()
  await snap("town_"+id+".png")
  if id=="resident_plaza_home":
   root.size=Vector2i(844,390);room.interact();await snap("town_resident_phone_dialogue.png")
   room._close_overlay();root.size=Vector2i(1280,720)
 room.player=Vector2(3150,1260);room.camera_zoom=0.55;room._update_actor()
 await snap("town_residential_overview.png")
 var path:String=room.state.path;room.free();DirAccess.remove_absolute(path)
 print("TOWN RESIDENT SCREENSHOTS: 6 native views saved")
 quit()
