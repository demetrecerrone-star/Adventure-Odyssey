extends "res://tests/tutorial_save_test.gd"
func settle() -> void:
 for i in 3: await process_frame
func run() -> void:
 root.size=Vector2i(844,390)
 root.content_scale_size=Vector2i(844,390)
 var state=fixture("Warrior")
 check(state.set_location("starter_region",Vector2(1000,2020)),"Enter field fixture")
 var world=load("res://src/starter_world.gd").new();world.state=state
 root.add_child(world);world.set_process(false);await settle()
 var calls: Array[int]=[0]
 var attack=world.combat_touch_buttons[0]
 attack.set_meta("combat_action",func(): calls[0]+=1)
 for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_PAUSED]:
  world.moving_to_target=true;world.target=world.player+Vector2(200,0);world.touch_direction=Vector2.RIGHT
  world.joystick.owner_index=3;world.joystick.direction=Vector2.RIGHT;world.joystick.mouse_owned=true
  attack.disabled=false;attack.set_meta("combat_touch",2);attack.set_meta("combat_dragged",false)
  world._notification(notification)
  check(not world.moving_to_target,"Interruption clears tap target %d"%notification)
  check(world.touch_direction==Vector2.ZERO,"Interruption clears joystick direction %d"%notification)
  check(world.joystick.owner_index==-1 and not world.joystick.mouse_owned and world.joystick.direction==Vector2.ZERO,"Interruption releases joystick owner %d"%notification)
  check(not attack.has_meta("combat_touch"),"Interruption clears held attack owner %d"%notification)
  var release=InputEventScreenTouch.new();release.index=2;release.pressed=false;release.position=attack.get_global_rect().get_center()
  world._input(release)
  check(calls[0]==0,"Stale release never attacks after interruption")
 world.moving_to_target=true;world.touch_direction=Vector2.RIGHT;attack.set_meta("combat_touch",2)
 world.open_menu();await settle()
 check(not world.moving_to_target and world.touch_direction==Vector2.ZERO,"Opening menu clears motion")
 check(not attack.has_meta("combat_touch"),"Opening menu clears attack ownership")
 check(world.hud._modal_active,"World HUD blocked by menu")
 world.cancel_overlay();await settle()
 check(not world.hud._modal_active and not world.moving_to_target,"Closing menu cannot resume prior target")
 var before=snap(state);var original_path=state.path
 state.path="user://missing-parent-for-interruption-test/save.json"
 check(not state.set_location("starter_region",world.player+Vector2(10,0)),"Save failure is reported")
 check(snap(state)==before,"Failed location save preserves all inventory/stats/quest state")
 state.path=original_path
 check(state.save(),"Save succeeds after path recovers")
 var loaded=Save.new();loaded.path=original_path
 check(loaded.load_saved() and snap(loaded)==before,"Recovered save reloads exact state")
 world.queue_free();await settle()
 for room_id in ["bedroom","guild_interior","blacksmith_interior","apothecary_interior","general_store_interior"]:
  var room_state=fixture("Ranger")
  var room=load("res://src/bedroom.gd" if room_id=="bedroom" else "res://src/town_interior.gd").new()
  room.state=room_state
  if room_id!="bedroom":room.room_id=room_id
  root.add_child(room);room.set_process(false);await settle()
  var original:Vector2=room.player
  room.moving_to_target=true;room.target=original+Vector2(120,0);room.touch_direction=Vector2.RIGHT
  room.joystick.owner_index=3;room.joystick.direction=Vector2.RIGHT
  room.message.text="QA: held move before pause"
  await capture(room_id+"_before_pause")
  room._notification(Node.NOTIFICATION_PAUSED)
  check(not room.moving_to_target and room.touch_direction==Vector2.ZERO,room_id+" pause resets target and direction")
  check(room.joystick.owner_index==-1 and room.joystick.direction==Vector2.ZERO,room_id+" pause releases joystick")
  for frame in 30:room._process(1.0/60.0)
  check(room.player==original,room_id+" resumes stationary without new input")
  room.message.text="QA: resumed stationary; old touch released"
  await capture(room_id+"_after_resume")
  room.queue_free();await settle()
 for path in paths:DirAccess.remove_absolute(path)
 print("MOBILE INTERRUPTION: %d checks; failures: %d"%[checks,failures]);quit(1 if failures else 0)

func capture(label:String) -> void:
 if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
 await process_frame
 await RenderingServer.frame_post_draw
 var directory:=OS.get_environment("AO_CAPTURE_DIR")
 DirAccess.make_dir_recursive_absolute(directory)
 check(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"Native interruption capture")
