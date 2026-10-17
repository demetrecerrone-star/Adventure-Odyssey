extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	if path.ends_with("bedroom_play.png"):
		var warm_pixels := 0
		for y in range(120, 620, 4):
			for x in range(260, 1020, 4):
				var pixel := image.get_pixel(x, y)
				if pixel.r > pixel.b + 0.04 and pixel.r > 0.15:
					warm_pixels += 1
		assert(warm_pixels > 4000, "Painted room must be visibly rendered, not covered by backdrop")
	assert(image.save_png(path) == OK)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var room = preload("res://src/bedroom.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.username = "BedroomPreview"
	room.state.path = "user://bedroom_capture.json"
	assert(room.state.create(draft.payload()))
	root.add_child(room)
	await process_frame
	assert(room.actor.artwork_ready, "Refuse a nude or missing-character screenshot")
	assert(room.actor.visible and not room.sleeping, "Character is immediately visible without a wake step")
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	await capture("res://screenshots/bedroom_play.png")
	room.player = room.anchors.chest
	room._update_actor()
	room.interact()
	await capture("res://screenshots/bedroom_chest.png")
	room._close_overlay()
	room.player = room.anchors.mirror
	room._update_actor()
	room.interact()
	await capture("res://screenshots/bedroom_mirror.png")
	DirAccess.remove_absolute(room.state.path)
	quit()
