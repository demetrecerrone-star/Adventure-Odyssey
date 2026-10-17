extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty(), "Native renderer required for creator capture")
	var parchment := image.get_pixel(image.get_width() / 2, 12)
	assert(parchment.r > 0.7 and parchment.g > 0.6, "Creator must render the light parchment surface")
	assert(image.save_png(path) == OK)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var creator = preload("res://src/creator/creator_panel.gd").new()
	creator.local_guest_mode = true
	root.add_child(creator)
	creator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	await capture("res://screenshots/creator_fullscreen.png")
	root.size = Vector2i(720, 400)
	await capture("res://screenshots/creator_landscape.png")
	creator.name_field.grab_focus()
	creator.keyboard_height_override = 150
	await capture("res://screenshots/creator_keyboard.png")
	creator.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	var mirror = preload("res://src/creator/creator_panel.gd").new()
	mirror.local_guest_mode = true
	mirror.mirror_mode = true
	mirror.draft.username = "MirrorPreview"
	root.add_child(mirror)
	mirror.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await capture("res://screenshots/creator_mirror.png")
	quit()
