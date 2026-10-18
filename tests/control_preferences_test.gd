extends SceneTree
const Preferences = preload("res://src/control_preferences.gd")
const Joystick = preload("res://src/touch_joystick.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func write_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open test fixture: " + path)
	if file != null:
		file.store_string(contents)
		file.close()

func touch(index: int, point: Vector2, pressed: bool = true, canceled: bool = false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	return event

func drag(index: int, point: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	return event

func mouse(point: Vector2, pressed: bool = true, device: int = 0) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	event.device = device
	return event

func stopped(pad) -> bool:
	return pad.owner_index == -1 and not pad.mouse_owned and pad.direction == Vector2.ZERO and pad.knob == Vector2.ZERO

func test_persistence() -> void:
	var path := "user://control_preferences_qa_%s.json" % Time.get_ticks_usec()
	var prefs = Preferences.new()
	check(prefs.path == "user://control_preferences_v1.json", "Device preferences have a separate local file")
	prefs.path = path
	check(prefs.mode == "fixed" and not prefs.left_handed, "Defaults preserve fixed left-side joystick")
	check(not prefs.load_saved() and prefs.error.is_empty(), "First use missing preferences is normal")
	check(not FileAccess.file_exists(path), "Reading defaults does not write files")
	for mode in ["fixed", "floating"]:
		for left in [false, true]:
			check(prefs.apply(mode, left), "Save combination %s/%s" % [mode, left])
			var reload = Preferences.new()
			reload.path = path
			check(reload.load_saved() and reload.mode == mode and reload.left_handed == left, "Restart preserves independent controls %s/%s" % [mode, left])
			check(not FileAccess.file_exists(path + ".tmp"), "Successful atomic write leaves no temporary file")
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			check(data.size() == 3 and data.version == 1 and data.mode == mode and data.left_handed == left, "Only version and device controls are saved")
	check(prefs.set_mode("fixed") and prefs.left_handed, "Changing mode preserves left-handed preference")
	check(prefs.set_left_handed(false) and prefs.mode == "fixed", "Changing handedness preserves mode")
	check(prefs.set_mode("floating") and not prefs.left_handed, "Mode does not implicitly toggle handedness")
	check(prefs.set_left_handed(true) and prefs.mode == "floating", "Handedness does not implicitly toggle mode")
	var prior_file := FileAccess.get_file_as_string(path)
	check(not prefs.apply("invalid", false) and prefs.mode == "floating" and prefs.left_handed and not prefs.error.is_empty(), "Invalid update preserves both live preferences")
	check(FileAccess.get_file_as_string(path) == prior_file, "Invalid update preserves committed file")

	# A blocked temporary file proves rollback while a real previous file exists.
	check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Create temporary-path failure fixture")
	check(not prefs.apply("fixed", false) and prefs.mode == "floating" and prefs.left_handed, "Open failure rolls back both preferences")
	check(FileAccess.get_file_as_string(path) == prior_file, "Open failure cannot truncate previous save")
	DirAccess.remove_absolute(path + ".tmp")
	prefs.path = path + ".missing/preferences.json"
	check(not prefs.apply("fixed", false) and prefs.mode == "floating" and prefs.left_handed, "Missing parent directory rolls back live preferences")

	# A nonempty directory at the destination forces failure at the rename step.
	prefs.path = path + ".directory"
	check(DirAccess.make_dir_absolute(prefs.path) == OK, "Create rename failure fixture")
	write_file(prefs.path + "/keep.txt", "previous target")
	check(not prefs.apply("fixed", false) and prefs.mode == "floating" and prefs.left_handed, "Rename failure leaves both live preferences unchanged")
	check(FileAccess.get_file_as_string(prefs.path + "/keep.txt") == "previous target", "Failed rename does not remove existing destination")
	check(not FileAccess.file_exists(prefs.path + ".tmp"), "Failed rename cleans its temporary file")
	DirAccess.remove_absolute(prefs.path + "/keep.txt")
	DirAccess.remove_absolute(prefs.path)
	prefs.path = path

	for contents in ["not json", "", "null", "[]", "{}", '{"version":2,"mode":"fixed","left_handed":false}', '{"version":1.5,"mode":"fixed","left_handed":false}', '{"version":true,"mode":"fixed","left_handed":false}', '{"version":"1","mode":"fixed","left_handed":false}', '{"version":1,"mode":"unknown","left_handed":false}', '{"version":1,"mode":1,"left_handed":false}', '{"version":1,"mode":"fixed","left_handed":"false"}', '{"version":1,"mode":"fixed","left_handed":0}', '{"version":1,"mode":"fixed"}', " ".repeat(Preferences.MAX_FILE_BYTES + 1)]:
		write_file(path, contents)
		check(not prefs.load_saved() and not prefs.error.is_empty(), "Malformed or oversized preferences rejected")
		check(prefs.mode == "floating" and prefs.left_handed, "Invalid load preserves complete live state")
		check(FileAccess.get_file_as_string(path) == contents, "Invalid load never overwrites source")
	write_file(path, '{"version":1,"mode":"fixed","left_handed":false,"future_option":"ignored"}')
	check(prefs.load_saved() and prefs.mode == "fixed" and not prefs.left_handed and prefs.error.is_empty(), "Valid data loads after errors and ignores harmless unknown fields")
	write_file(path + ".tmp", '{"version":1,"mode":"floating","left_handed":true}')
	check(prefs.load_saved() and prefs.mode == "fixed" and not prefs.left_handed, "Interrupted temporary write never replaces committed settings")
	check(prefs.apply("floating", true) and not FileAccess.file_exists(path + ".tmp"), "Next save recovers from stale temporary data")
	DirAccess.remove_absolute(path)
	write_file(path + ".tmp", '{"version":1,"mode":"fixed","left_handed":false}')
	check(not prefs.load_saved() and prefs.mode == "floating" and prefs.left_handed, "Temporary-only data is not treated as committed")
	DirAccess.remove_absolute(path + ".tmp")

func test_joystick() -> void:
	root.size = Vector2i(1280, 720)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	var pad = Joystick.new()
	pad.position = Vector2(40, 470)
	pad.size = Vector2(164, 164)
	host.add_child(pad)
	await process_frame
	var emitted: Array[Vector2] = []
	pad.direction_changed.connect(func(value: Vector2): emitted.append(value))
	check(pad.mode == "fixed" and pad.size == Vector2(164, 164), "Existing fixed default and dimensions remain compatible")
	var center: Vector2 = pad.size * 0.5
	pad.set_position_input(center + Vector2(4, 0))
	check(pad.direction == Vector2.ZERO, "Fixed analog deadzone prevents drift")
	pad.set_position_input(center + Vector2(Joystick.RADIUS * (Joystick.DEADZONE + (1.0 - Joystick.DEADZONE) * 0.5), 0))
	check(is_equal_approx(pad.direction.x, 0.5) and pad.direction.y == 0, "Deadzone remaps remainder to proportional analog strength")
	pad.set_position_input(center + Vector2(200, -200))
	check(is_equal_approx(pad.direction.length(), 1) and pad.direction.x > 0 and pad.direction.y < 0, "Diagonal magnitude clamps at one")
	pad.reset()
	check(stopped(pad) and emitted.back() == Vector2.ZERO, "Reset emits immediate stop")
	pad._gui_input(touch(3, center + Vector2(60, 0)))
	check(pad.owner_index == 3 and pad.direction.x > 0.9, "Fixed press immediately drives from pad center")
	pad._gui_input(touch(4, center + Vector2(-60, 0)))
	pad._gui_input(mouse(center + Vector2(-60, 0)))
	check(pad.owner_index == 3 and not pad.mouse_owned and pad.direction.x > 0.9, "Second finger and mouse cannot steal touch ownership")
	pad._input(touch(4, Vector2.ZERO, false))
	pad._input(drag(4, Vector2.ZERO))
	check(pad.owner_index == 3 and pad.direction.x > 0.9, "Unowned release/drag cannot alter movement")
	pad._input(drag(3, pad.get_global_transform_with_canvas() * (center + Vector2(-300, 300))))
	check(pad.direction.x < 0 and pad.direction.y > 0 and is_equal_approx(pad.direction.length(), 1), "Owned drag tracks outside pad")
	pad._input(touch(3, Vector2.ZERO, false))
	check(stopped(pad), "Owner release outside pad stops input")
	pad._gui_input(touch(3, center, true, true))
	pad._gui_input(touch(-1, center))
	check(stopped(pad), "Canceled and invalid-index presses cannot claim ownership")
	pad._gui_input(touch(3, Vector2(-1, 80)))
	pad._gui_input(touch(3, Vector2(164, 80)))
	check(stopped(pad), "Fixed control rejects presses outside its bounded rectangle")
	pad._gui_input(mouse(center, true, -1))
	check(stopped(pad), "Touch-emulated mouse cannot double-claim joystick")
	pad._gui_input(mouse(center + Vector2(60, 0)))
	pad._gui_input(touch(4, center))
	check(pad.mouse_owned and pad.owner_index == -1 and pad.direction.x > 0.9, "Mouse exclusively owns its sequence")
	var motion := InputEventMouseMotion.new()
	motion.position = pad.get_global_transform_with_canvas() * (center + Vector2(-200, 0))
	pad._input(motion)
	check(pad.direction.x < -0.99, "Mouse drag outside pad keeps analog direction")
	pad._input(mouse(Vector2.ZERO, false, -1))
	check(pad.mouse_owned, "Synthetic mouse release cannot cancel real mouse")
	pad._input(mouse(Vector2.ZERO, false))
	check(stopped(pad), "Real mouse release outside control stops movement")
	check(not pad.configure("invalid") and pad.mode == "fixed", "Unknown joystick mode rejected")

	check(pad.configure("floating"), "Configure floating mode")
	pad.size = Vector2(330, 210)
	for local in [Vector2(1, 1), Vector2(329, 1), Vector2(1, 209), Vector2(329, 209), Vector2(165, 105)]:
		pad._gui_input(touch(2, local))
		check(pad.owner_index == 2 and pad.direction == Vector2.ZERO, "Floating press starts with zero movement at every zone edge")
		var origin: Vector2 = pad.get_origin()
		check(origin.x >= Joystick.PAD_MARGIN and origin.y >= Joystick.PAD_MARGIN and origin.x <= pad.size.x - Joystick.PAD_MARGIN and origin.y <= pad.size.y - Joystick.PAD_MARGIN, "Floating visual pad stays readable within bounded zone")
		pad._input(drag(2, pad.get_global_transform_with_canvas() * (local + Vector2(2, 1))))
		check(pad.direction == Vector2.ZERO, "Tiny edge drag has no clamping jump")
		pad._input(drag(2, pad.get_global_transform_with_canvas() * (local + Vector2(35, 0))))
		check(pad.direction.x > 0 and pad.direction.x < 1 and is_zero_approx(pad.direction.y), "Floating press-relative motion preserves analog strength")
		pad._gui_input(touch(5, Vector2(100, 100)))
		pad._input(touch(5, Vector2.ZERO, false, true))
		check(pad.owner_index == 2 and pad.get_origin() == origin, "Second touch cannot recenter or cancel floating stick")
		pad._input(drag(2, pad.get_global_transform_with_canvas() * (local + Vector2(500, -500))))
		check(is_equal_approx(pad.direction.length(), 1), "Floating drag remains capped outside activation zone")
		pad._input(touch(2, Vector2.ZERO, false, true))
		check(stopped(pad) and pad.get_origin() == pad.size * 0.5, "Cancel releases floating origin and movement")
	for local in [Vector2(-1, 50), Vector2(331, 50), Vector2(50, -1), Vector2(50, 211)]:
		pad._gui_input(touch(2, local))
		check(stopped(pad), "Floating activation never extends outside bottom-side control rectangle")
	pad._gui_input(mouse(Vector2(1, 1)))
	check(pad.mouse_owned and pad.direction == Vector2.ZERO, "Floating supports mouse without initial movement")
	pad.configure("fixed")
	check(stopped(pad) and emitted.back() == Vector2.ZERO, "Mode switch stops owned pointer immediately")
	pad.configure("floating")
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.configure("floating")
	check(stopped(pad), "Reapplying mode does not retain ownership")

	for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_DISABLED]:
		pad._gui_input(touch(2, Vector2(100, 100)))
		pad._input(drag(2, pad.get_global_transform_with_canvas() * Vector2(160, 100)))
		pad._notification(notification)
		check(stopped(pad) and emitted.back() == Vector2.ZERO, "Interruption releases input: %s" % notification)
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.hide()
	check(stopped(pad), "Hiding joystick clears owner")
	pad._gui_input(touch(2, Vector2(100, 100)))
	check(stopped(pad), "Hidden joystick cannot claim touch")
	pad.show()
	pad._gui_input(touch(2, Vector2(100, 100)))
	host.hide()
	check(stopped(pad), "Hiding ancestor also releases movement")
	host.show()
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.size += Vector2(20, 0)
	check(stopped(pad), "Resizing zone releases old input origin")
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.position += Vector2(20, 0)
	check(stopped(pad), "Moving same-size zone for handedness releases input origin")
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.scale = Vector2(0.95, 1)
	check(stopped(pad), "Changing control scale releases input origin")
	pad.scale = Vector2.ONE
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.set_input_enabled(false)
	check(stopped(pad) and pad.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Modal disable stops input and gives UI ownership")
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad._gui_input(mouse(Vector2(100, 100)))
	pad.set_position_input(Vector2(300, 100))
	pad._input(drag(2, Vector2(600, 600)))
	check(stopped(pad), "Disabled stick rejects touch, mouse, drag and direct updates")
	pad.set_input_enabled(true)
	pad._input(drag(2, Vector2(600, 600)))
	check(stopped(pad), "Reopening controls cannot resurrect an old pointer")
	pad._gui_input(touch(2, Vector2(100, 100)))
	pad.set_position_input(Vector2(NAN, INF))
	check(stopped(pad), "Malformed coordinates safely release input")

	# Handedness changes placement only; every persisted mode/side combination
	# must retain the same world-relative analog direction via native routing.
	for selected_mode in ["fixed", "floating"]:
		for left_handed in [false, true]:
			pad.configure(selected_mode)
			pad.size = Vector2(164, 164) if selected_mode == "fixed" else Vector2(330, 210)
			pad.position = Vector2(1280 - pad.size.x - 30 if left_handed else 30, 450)
			var local_start: Vector2 = pad.size * 0.5
			if selected_mode == "fixed":
				local_start += Vector2(60, 0)
			Input.parse_input_event(touch(0, pad.get_global_transform_with_canvas() * local_start))
			await process_frame
			check(pad.owner_index == 0, "Viewport claims %s controls on handedness=%s" % [selected_mode, left_handed])
			if selected_mode == "floating":
				check(pad.direction == Vector2.ZERO, "Mirrored floating activation starts neutral")
				Input.parse_input_event(drag(0, pad.get_global_transform_with_canvas() * (local_start + Vector2(60, 0))))
				await process_frame
			check(pad.direction.x > 0.9 and is_zero_approx(pad.direction.y), "All four combinations preserve world-relative movement")
			Input.parse_input_event(touch(0, Vector2(800, 200), false))
			await process_frame
			check(stopped(pad), "All four combinations release outside their activation zone")
	pad.configure("floating")
	pad.size = Vector2(350, 210)

	# Test native viewport routing with transformed UI and multiple pointer IDs.
	pad.scale = Vector2(1.1, 0.9)
	pad.position = Vector2(50, 440)
	var start: Vector2 = pad.get_global_transform_with_canvas() * Vector2(120, 100)
	Input.parse_input_event(touch(0, start))
	await process_frame
	check(pad.owner_index == 0 and pad.direction == Vector2.ZERO, "Viewport routes floating touch to bounded activation zone")
	Input.parse_input_event(drag(0, pad.get_global_transform_with_canvas() * Vector2(190, 100)))
	await process_frame
	check(pad.direction.x > 0.99 and is_zero_approx(pad.direction.y), "Viewport drag maps transformed canvas to pad-local direction")
	var other := Control.new()
	other.position = Vector2(1000, 500)
	other.size = Vector2(180, 100)
	other.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(other)
	var ui_touches: Array[int] = []
	other.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed:
			ui_touches.append(event.index)
			other.accept_event())
	Input.parse_input_event(touch(1, Vector2(1050, 550)))
	await process_frame
	check(ui_touches.has(1) and pad.owner_index == 0 and pad.direction.x > 0.99, "Second finger still reaches another UI control while movement is held")
	Input.parse_input_event(touch(1, Vector2(1050, 550), false))
	Input.parse_input_event(touch(0, Vector2(800, 200), false))
	await process_frame
	check(stopped(pad), "Native owner release outside floating zone stops movement")
	Input.parse_input_event(touch(0, Vector2(800, 200)))
	await process_frame
	check(stopped(pad), "Native out-of-zone press cannot activate floating controls")
	Input.parse_input_event(touch(0, Vector2(800, 200), false))
	pad._gui_input(touch(2, Vector2(100, 100)))
	host.remove_child(pad)
	check(stopped(pad), "Scene removal releases pointer before next screen")
	pad.free()
	host.queue_free()
	await process_frame

func run() -> void:
	test_persistence()
	await test_joystick()
	print("Control preferences checks: %d failures: %d" % [checks, failures])
	quit(1 if failures else 0)
