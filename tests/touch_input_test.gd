extends SceneTree
# Actual viewport event dispatch. Headless coverage is not physical Android QA.
var scene
var passed:=0
var failed:=0
var clicks:=0
func _initialize():call_deferred('_run')
func check(ok:bool,label:String):
	if ok:passed+=1;print('PASS: ',label)
	else:failed+=1;print('FAIL: ',label)
func event(e:InputEvent):
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func touch(i:int,p:Vector2,down:bool,canceled:=false):
	var e:=InputEventScreenTouch.new()
	e.index=i;e.position=p;e.pressed=down;e.canceled=canceled;event(e)
func drag(i:int,p:Vector2):
	var e:=InputEventScreenDrag.new()
	e.index=i;e.position=p;event(e)
func mouse(p:Vector2,down:bool,device:=0):
	var e:=InputEventMouseButton.new()
	e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.device=device;event(e)
func _run():
	root.size=Vector2i(1280,720)
	scene=load('res://scenes/main.tscn').instantiate();root.add_child(scene)
	await process_frame
	scene.set_process(false);scene._random_default();scene._enter_world('forest',Vector2(500,655));scene._dismiss_message()
	await process_frame
	var p:=Vector2(1120,585)
	var j:=Vector2(195,605)
	var b:Button=scene._gameplay_button_at(p)
	b.pressed.connect(func():clicks+=1)
	touch(0,p,true);touch(1,j,true)
	check(scene.movement.x>0.8,'button first, joystick second moves')
	touch(0,p,false)
	check(clicks==1 and scene.movement.x>0.8,'button first releases once without stealing joystick')
	touch(1,j,false)
	check(scene.movement==Vector2.ZERO,'second finger joystick release stops')
	for i in [0,1]:
		var before:=clicks
		touch(i,p,true);touch(i,p,false)
		check(clicks==before+1,'finger %d fires once despite emulated mouse' % i)
	var before:=clicks
	touch(0,p,true);mouse(p,true,InputEvent.DEVICE_ID_EMULATION);mouse(p,false,InputEvent.DEVICE_ID_EMULATION);touch(0,p,false)
	check(clicks==before+1,'explicit emulated mouse pair cannot duplicate action')
	before=clicks;touch(0,p,true);drag(0,Vector2(600,400));touch(0,Vector2(600,400),false)
	check(clicks==before and scene.gameplay_touches.is_empty() and not b.button_pressed,'release outside cancels button')
	touch(0,Vector2(600,400),true);touch(0,p,false)
	check(clicks==before,'outside press then inside release does not activate')
	touch(0,p,true);touch(0,p,false,true)
	check(clicks==before and scene.gameplay_touches.is_empty(),'canceled touch releases ownership without activation')
	touch(0,p,true);touch(1,p,true);touch(1,p,false);touch(0,p,false)
	check(clicks==before+1,'two fingers on same button produce one owned gesture')
	before=clicks;b.disabled=true;touch(0,p,true);touch(0,p,false);b.disabled=false
	check(clicks==before,'disabled button ignores touch')
	b.hide();touch(0,p,true);touch(0,p,false);b.show()
	check(clicks==before,'hidden button ignores touch')
	scene._open_menu('stats');await process_frame
	touch(0,p,true);touch(0,p,false)
	check(clicks==before,'modal blocks underlying gameplay touches')
	scene._dismiss_message();await process_frame
	mouse(p,true);mouse(p,false)
	check(clicks==before+1,'physical mouse Button callback preserved')
	before=clicks;b.grab_focus()
	var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;event(key)
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=false;event(key)
	check(clicks==before+1,'focused keyboard Button activation preserved')
	before=clicks;touch(0,p,true);scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);touch(0,p,false)
	check(clicks==before and scene.gameplay_touches.is_empty() and not b.button_pressed,'focus loss cancels held button and late release')
	mouse(j,true);check(scene.joystick.mouse_held and scene.movement.x>0.8,'physical mouse joystick works')
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not scene.joystick.mouse_held and scene.joystick.finger==-1 and scene.movement==Vector2.ZERO,'pause clears mouse joystick ownership')
	mouse(j,false)
	touch(0,j,true);touch(0,j,false,true)
	check(scene.joystick.finger==-1 and scene.movement==Vector2.ZERO,'canceled joystick touch clears movement')
	touch(0,j,true);scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);drag(0,j)
	check(scene.movement==Vector2.ZERO,'late drag after focus loss cannot reacquire movement')
	touch(0,j,false);touch(0,j,true)
	check(scene.movement.x>0.8,'fresh press reacquires joystick after reset')
	touch(0,j,false)
	touch(0,j,true);touch(1,Vector2(1070,125),true);touch(1,Vector2(1070,125),false)
	check(is_instance_valid(scene.popup),'second finger opens modal while joystick held')
	touch(1,Vector2(1090,115),true);touch(1,Vector2(1090,115),false)
	check(not is_instance_valid(scene.popup),'second finger closes modal while joystick held')
	touch(0,j,false)
	await process_frame
	for child in scene.hud.get_children():
		if child is Button:
			check(scene._gameplay_button_at(child.get_global_rect().get_center())==child,'touch coverage: '+child.text)
	print('TOUCH INPUT: ',passed,' passed; ',failed,' failed')
	quit(1 if failed else 0)
