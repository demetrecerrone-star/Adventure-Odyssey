extends SceneTree
# Isolated screenshot fixtures only. The runtime has no level-up/award control.
# Real input events exercise the same Preview and Confirm buttons as gameplay.
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var stamp := str(Time.get_ticks_usec())
var captured := 0
var validate_only := OS.get_cmdline_user_args().has("--validate-only")
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for _i in range(6): await process_frame
func snap(filename: String) -> void:
	await settle()
	if validate_only:
		captured += 1
		return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/" + filename) == OK)
	captured += 1
func click(button: Button) -> void:
	assert(button.is_visible_in_tree() and not button.disabled)
	var point: Vector2 = button.get_global_rect().get_center()
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for dimensions in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		for left in [false, true]:
			var prefix := "stats_%dx%d_%s" % [dimensions.x, dimensions.y, "left" if left else "right"]
			var state = Save.new()
			state.path = "user://" + prefix + "_" + stamp + ".json"
			var draft = Draft.new()
			draft.set_base("female")
			draft.character_class = "Warrior"
			draft.username = "Aeloria"
			assert(state.create(draft.payload()))
			var room = load("res://src/bedroom.gd").new()
			room.state = state
			room.control_preferences.path = "user://" + prefix + "_preferences_" + stamp + ".json"
			assert(room.control_preferences.apply("fixed", left))
			root.add_child(room)
			room.set_process(false)
			await settle()
			room.open_menu()
			room.overlay.show_page("stats")
			await snap(prefix + "_zero.png")
			# This earned-level seed exists only in the capture harness.
			assert(state.advance_character_level(2, state.get_stat_summary().revision).ok)
			room.overlay.refresh_state()
			await snap(prefix + "_unspent.png")
			await click(room.overlay.stat_rows.STR.plus)
			await click(room.overlay.stat_rows.STR.plus)
			await click(room.overlay.stat_rows.WIS.plus)
			assert(room.overlay._stat_total() == 3 and state.get_stat_summary().unspent_points == 5)
			await snap(prefix + "_draft.png")
			await click(room.overlay.stat_primary)
			assert(room.overlay._stat_reviewing and room.overlay.stat_primary.name == "StatConfirm")
			await snap(prefix + "_review.png")
			await click(room.overlay.stat_primary)
			assert(state.get_stat_summary().attributes.STR == 12 and state.get_stat_summary().attributes.WIS == 11 and state.get_stat_summary().attributes.LUK == 10 and state.get_stat_summary().unspent_points == 2)
			await snap(prefix + "_confirmed.png")
			room.overlay.body_scroll.scroll_vertical = 10000
			await snap(prefix + "_effects.png")
			# Real gameplay does not call this future discovery service yet. These
			# isolated capture receipts show the bar with genuine persisted data.
			assert(state.record_luck_event("capture.luck.1", "capture.source.1", "first_discovery", "", state.get_stat_summary().revision).ok)
			room.overlay.refresh_state()
			room.overlay.set_notice("")
			room.overlay.body_scroll.set_deferred("scroll_vertical", 0)
			assert(room.overlay.stat_rows.LUK.xp_label.text == "25 / 100 XP")
			await snap(prefix + "_luck_xp.png")
			for index in range(2, 5):
				assert(state.record_luck_event("capture.luck.%d" % index, "capture.source.%d" % index, "first_discovery", "", state.get_stat_summary().revision).ok)
			room.overlay.refresh_state()
			room.overlay.body_scroll.set_deferred("scroll_vertical", 0)
			assert(room.overlay.stat_rows.LUK.value.text == "11" and room.overlay.stat_rows.LUK.xp_label.text == "0 / 125 XP")
			await snap(prefix + "_luck_rank.png")
			var preferences_path: String = room.control_preferences.path
			room.free()
			await settle()
			DirAccess.remove_absolute(state.path)
			DirAccess.remove_absolute(preferences_path)
	print("STAT SCREENSHOTS: %d capture states validated without rendering" % captured if validate_only else "STAT SCREENSHOTS: %d native desktop/phone frames saved" % captured)
	quit()
