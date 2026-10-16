extends SceneTree
# Synthetic touchscreen routing regression tests. Run in an isolated project/user dir.
# These exercise Godot GUI dispatch; they do not certify physical Android input.
var scene
var failed:int=0
var passed:int=0
func _initialize():
	call_deferred('_run')
func check(condition:bool,label:String):
	if condition:
		passed+=1
		print('PASS: ',label)
	else:
		failed+=1
		print('FAIL: ',label)
func touch(index:int,pos:Vector2,pressed:bool):
	var event=InputEventScreenTouch.new()
	event.index=index
	event.position=pos
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag(index:int,pos:Vector2):
	var event=InputEventScreenDrag.new()
	event.index=index
	event.position=pos
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _run():
	root.size=Vector2i(1280,720)
	scene=load('res://scenes/main.tscn').instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._random_default()
	scene._enter_world('forest',Vector2(500,655))
	scene._dismiss_message()
	await process_frame
	check(Input.emulate_mouse_from_touch,'project uses default touch-to-mouse emulation')
	touch(0,Vector2(1120,585),true)
	touch(0,Vector2(1120,585),false)
	check(scene.attack_cooldown>0,'single touch ATTACK routes correctly (control)')
	scene.attack_cooldown=0.0
	touch(0,Vector2(195,605),true)
	check(scene.movement.x>0.8,'joystick receives first touch')
	touch(1,Vector2(1120,585),true)
	touch(1,Vector2(1120,585),false)
	check(scene.attack_cooldown>0,'second finger ATTACK works while joystick held')
	check(scene.movement.x>0.8,'second finger does not interrupt joystick movement')
	touch(1,Vector2(1070,125),true)
	touch(1,Vector2(1070,125),false)
	check(is_instance_valid(scene.popup),'second finger STATS opens while joystick held')
	scene._dismiss_message()
	await process_frame
	drag(0,Vector2(450,450))
	check(scene.movement.y<0,'captured finger drag outside joystick tracks')
	touch(0,Vector2(450,450),false)
	check(scene.movement==Vector2.ZERO and scene.joystick.finger==-1,'release outside joystick stops movement')
	touch(0,Vector2(195,605),true)
	scene._open_menu('stats')
	await process_frame
	var before:Vector2=scene.player.position
	scene._process(0.1)
	check(scene.player.position==before,'open modal pauses player movement')
	touch(0,Vector2(195,605),false)
	check(scene.movement==Vector2.ZERO,'release over modal reaches captured joystick')
	scene._dismiss_message()
	await process_frame
	scene._process(0.1)
	check(scene.player.position==before,'closing modal after release does not resume stale movement')
	touch(0,Vector2(195,605),true)
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(scene.movement==Vector2.ZERO and scene.joystick.finger==-1 and not scene.joystick.mouse_held,'focus loss clears movement and pointer state')
	touch(0,Vector2(195,605),false)
	touch(0,Vector2(195,605),true)
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(scene.movement==Vector2.ZERO and scene.joystick.finger==-1 and not scene.joystick.mouse_held,'app pause clears movement and pointer state')
	scene.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	before=scene.player.position
	scene._process(0.1)
	check(scene.player.position==before,'resume without release event cannot retain old joystick movement')
	scene._enter_world('town',Vector2(1030,980))
	await process_frame
	check(scene.movement==Vector2.ZERO and scene.joystick.finger==-1,'map transition resets joystick and movement')
	touch(0,Vector2(195,605),false)
	check(scene.movement==Vector2.ZERO,'old touch release after map transition stays neutral')
	print('TOUCH REGRESSION: ',passed,' passed; ',failed,' failed')
	quit(1 if failed else 0)
