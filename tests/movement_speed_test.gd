extends "res://tests/tutorial_save_test.gd"
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(844,390)
 var state=fixture("Ranger")
 for kind in ["bedroom","starter_region","guild_interior"]:
  var room
  if kind=="bedroom": room=preload("res://src/bedroom.gd").new()
  elif kind=="starter_region": room=preload("res://src/starter_world.gd").new()
  else:
   room=preload("res://src/town_interior.gd").new()
   room.room_id=kind
  room.state=state
  root.add_child(room); room.set_process(false); await process_frame
  check(is_equal_approx(room.movement_speed,186.0),kind+" speed +20 percent")
  var start: Vector2=Vector2(780,700) if kind=="bedroom" else (Vector2(1100,1800) if kind=="starter_region" else Vector2(740,700))
  check(room.can_stand(start),kind+" test start walkable")
  for direction in [Vector2.RIGHT,Vector2(1,1),Vector2(0.5,0)]:
   room.player=start
   room.touch_direction=direction
   room.actor.advance(2,false,0)
   var elapsed_before: float=room.actor.elapsed
   for tick in 4: room._process(0.05)
   var expected: float=186*0.2*minf(direction.length(),1)
   check(absf(room.player.distance_to(start)-expected)<0.1,kind+" normalized analog speed "+str(direction))
   check(absf(room.actor.elapsed-0.2*minf(direction.length(),1))<0.01,kind+" nine-fps cadence independent of boost")
  room.touch_direction=Vector2.ZERO
  room.player=start
  var key:=InputEventKey.new(); key.physical_keycode=KEY_D; key.keycode=KEY_D; key.pressed=true
  Input.parse_input_event(key)
  Input.flush_buffered_events()
  check(Input.is_physical_key_pressed(KEY_D),"Keyboard event active")
  room._process(0.05)
  check(absf(room.player.x-start.x-9.3)<0.1,kind+" keyboard186 px/s")
  var released: InputEventKey = key.duplicate()
  released.pressed=false; Input.parse_input_event(released)
  Input.flush_buffered_events()
  room.queue_free(); await process_frame
 for path in paths: DirAccess.remove_absolute(path)
 print("MOVEMENT SPEED CHECKS: %d; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
