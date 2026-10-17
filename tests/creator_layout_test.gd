extends SceneTree
const Creator = preload("res://src/creator/creator_panel.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in range(6):
		await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	for mirror in [false, true]:
		var screen = Creator.new()
		screen.local_guest_mode = true
		screen.mirror_mode = mirror
		if mirror:
			screen.draft.username = "MirrorHero"
		root.add_child(screen)
		for dimensions in [Vector2(1280, 720), Vector2(960, 540), Vector2(720, 400), Vector2(640, 360)]:
			screen.size = dimensions
			await settle()
			check(screen.panel.size.x >= dimensions.x - 16, "creator uses full available width")
			check(screen.panel.get_global_rect().encloses(screen.preview.stage.get_global_rect()), "preview stays in screen")
			check(screen.preview.stage.size.y > 100, "normal landscape has usable preview height")
			var avatar = screen.preview.stage.get_child(0)
			var frame_rect := Rect2(avatar.position + Vector2(-128, -232) * avatar.scale, Vector2(256, 256) * avatar.scale)
			check(Rect2(Vector2.ZERO, screen.preview.stage.size).encloses(frame_rect), "full avatar frame fits without cutting off head or feet")
			check(screen.panel.get_global_rect().encloses(screen.name_field.get_global_rect()), "username stays in screen")
			check(screen.panel.get_global_rect().encloses(screen.submit.get_global_rect()), "submit stays in screen")
			check(screen.left_scroll.global_position.x < screen.preview.global_position.x and screen.right_scroll.global_position.x > screen.preview.global_position.x, "options flank center preview")
			check(screen.name_field.global_position.y >= screen.preview.get_global_rect().end.y, "username below character")
			check(screen.left_scroll.scroll_vertical == 0 and screen.right_scroll.scroll_vertical == 0, "opening or resizing never scrolls options to focus")
			check(screen.base_option.get_parent() == screen.left_options and screen.skin_option.get_parent() == screen.left_options, "body and skin on left")
			check(screen.hair_option.get_parent() == screen.right_options and screen.eye_option.get_parent() == screen.right_options, "hair and eyes on right")
		check(screen.base_option.disabled == mirror and screen.class_option.disabled == mirror and screen.name_field.editable != mirror, "mirror preserves identity locks")
		screen.size = Vector2(720, 400)
		screen.safe_override = Rect2(30, 15, 660, 370)
		screen.keyboard_height_override = 150
		screen.name_field.grab_focus()
		await settle()
		check(screen.panel.get_global_rect().end.y <= 238, "screen preserves full 12 px gap above simulated keyboard")
		check(screen.preview.stage.size.y > 0, "preview remains present with keyboard")
		check(screen.panel.get_global_rect().encloses(screen.name_field.get_global_rect()), "keyboard cannot hide fixed username")
		check(screen.panel.get_global_rect().encloses(screen.submit.get_global_rect()), "keyboard cannot hide submit")
		# Stress larger text metrics as well as the normal font. Container minimum
		# height must not silently defeat the keyboard-safe requested rectangle.
		for font_size in [20, 16]:
			screen.theme.default_font_size = font_size
			screen.notice.text = "A deliberately long validation explanation must not force the keyboard layout beyond its safe rectangle. Please choose another username."
			await settle()
			var diagnostic := "font=%d mirror=%s panel=%s min=%s available=(660,223) center=%s center_min=%s heading_min=%s footer_min=%s" % [font_size, mirror, screen.panel.get_global_rect(), screen.panel.get_combined_minimum_size(), screen.center.size, screen.center.get_combined_minimum_size(), screen.content.get_child(0).get_combined_minimum_size(), screen.notice.get_parent().get_combined_minimum_size()]
			check(screen.panel.get_global_rect().end.y <= 238, "keyboard-safe bounds survive taller font metrics: " + diagnostic)
			check(screen.panel.get_combined_minimum_size().y <= 223, "compact content minimum fits available keyboard region: " + diagnostic)
			check(screen.panel.get_global_rect().encloses(screen.name_field.get_global_rect()), "name stays visible with taller text metrics")
			check(screen.panel.get_global_rect().encloses(screen.submit.get_global_rect()), "submit stays visible with taller text metrics")
			check(screen.preview.stage.size.y >= 24, "keyboard retains preview rather than hiding character")
		for side in [screen.left_scroll, screen.right_scroll]:
			var preview_rect: Rect2 = screen.preview.get_global_rect()
			var name_rect: Rect2 = screen.name_field.get_global_rect()
			var point: Vector2 = side.global_position + Vector2(side.size.x - 22, side.size.y * 0.5)
			for i in range(8):
				var pan := InputEventPanGesture.new()
				pan.position = point
				pan.delta = Vector2(0, 4)
				root.push_input(pan)
			await settle()
			check(side.scroll_vertical > 0, "viewport pan gesture reaches lower options")
			for i in range(8):
				var pan := InputEventPanGesture.new()
				pan.position = point
				pan.delta = Vector2(0, -4)
				root.push_input(pan)
			await settle()
			check(side.scroll_vertical == 0, "viewport reverse pan returns to first option")
			for i in range(12):
				var wheel := InputEventMouseButton.new()
				wheel.position = point
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				root.push_input(wheel)
			await settle()
			check(side.scroll_vertical > 0, "viewport wheel reaches lower options")
			for i in range(12):
				var wheel := InputEventMouseButton.new()
				wheel.position = point
				wheel.button_index = MOUSE_BUTTON_WHEEL_UP
				wheel.pressed = true
				root.push_input(wheel)
			await settle()
			check(side.scroll_vertical == 0, "viewport wheel returns to first option without focus snapback")
			check(screen.preview.get_global_rect() == preview_rect and screen.name_field.get_global_rect() == name_rect, "scrolling never moves preview or username")
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		screen._input(tab)
		screen.eye_option.grab_focus()
		await settle()
		check(screen.right_scroll.get_global_rect().encloses(screen.eye_option.get_global_rect()), "keyboard focus reveals the selected side option")
		var finger := InputEventScreenTouch.new()
		finger.pressed = true
		screen._input(finger)
		screen.right_scroll.scroll_vertical = 0
		await settle()
		check(screen.right_scroll.scroll_vertical == 0, "returning to touch never snaps back to focused option")
		screen.keyboard_height_override = 0
		await settle()
		check(screen.preview.stage.size.y > 100, "preview restores after keyboard dismissal")
		screen.queue_free()
		await settle()
	print("CREATOR LAYOUT TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
