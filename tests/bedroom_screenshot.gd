extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
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
	room.wake_up()
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
