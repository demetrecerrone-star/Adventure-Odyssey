extends SceneTree
# Side-by-side native replay: legacy resets vs current continuous turn playback.
# Before differs only by replaying the old elapsed=0 rule on a moving turn.
const Avatar = preload("res://src/layered_avatar.gd")
var subjects: Array = []
var phase_label: Label
func _initialize() -> void: call_deferred("run")
func label_at(parent: Node, text: String, at: Vector2, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("30291e"))
	parent.add_child(label)
	return label
func capture(path: String) -> void:
	for unused in range(2): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var canvas := Control.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color("eee5d2")
	canvas.add_child(bg)
	label_at(canvas, "Same approved art, 6 drawings, 9 fps, 155 px/s | Turning stride continuity", Vector2(16, 6), 20)
	phase_label = label_at(canvas, "", Vector2(16, 35), 16)
	var classes: Array = preload("res://src/creator/catalog.gd").CLASSES
	for row in range(4):
		var base := "male" if row < 2 else "female"
		var legacy := row % 2 == 0
		for column in range(classes.size()):
			var cls: String = classes[column]
			var avatar = Avatar.new()
			canvas.add_child(avatar)
			var appearance := {"hair":base + ("_hair_01" if column % 2 == 0 else "_hair_11"), "hair_color":"Brown" if row < 2 else "Silver", "skin":"warm" if row < 2 else "blue", "eyes":"Green"}
			assert(avatar.configure(base, cls, appearance))
			avatar.set_equipped_weapon(cls.to_lower() + "_01_weapon")
			avatar.scale = Vector2.ONE * (96.0 / 190.0)
			var origin := Vector2(105 + column * 213, 156 + row * 155)
			avatar.position = origin
			avatar.advance(0, false, 0)
			label_at(canvas, ("Before " if legacy else "After ") + base + " " + cls, Vector2(8 + column * 213, 60 + row * 155), 14)
			subjects.append({"actor":avatar, "legacy":legacy, "origin":origin})
	for tick in range(144):
		var direction: int = [0, 1, 3, 2][(tick / 9) % 4]
		var strength := 1.0 if tick < 72 else 0.5
		var moving := tick < 108 or tick >= 120
		# Four directions, then half-speed steering, then a true stop/restart.
		phase_label.text = "%s | frame %03d / 143 | %s" % ["Full-speed steering" if tick < 72 else ("Half-speed steering" if tick < 108 else ("Stopped" if tick < 120 else "Resume")), tick, ["down", "left", "right", "up"][direction]]
		for subject in subjects:
			var avatar = subject.actor
			if subject.legacy and moving and avatar.current_animation.begins_with("walk_") and avatar.facing != direction:
				avatar.elapsed = 0
			avatar.advance(direction, moving, strength / 36.0 if moving else 0.0)
			if moving:
				avatar.position += [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP][direction] * (155.0 * strength / 36.0)
		await capture("res://screenshots/avatar_turn_motion_%03d.png" % tick)
		if tick in [8, 9, 17, 18, 35, 80, 107, 119, 120, 143]:
			assert(root.get_texture().get_image().save_png("res://screenshots/avatar_turn_review_%03d.png" % tick) == OK)
	canvas.queue_free()
	await process_frame
	quit()
