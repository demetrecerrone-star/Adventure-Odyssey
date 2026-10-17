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
	root.size = Vector2i(1280,720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.elapsed = 0.0
	scene.set_process(false)
	scene._process(0.0)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	await capture("res://screenshots/title_preview.png")
	for runner in scene.runners:
		runner.pause()
	for frame in range(4):
		for runner in scene.runners:
			runner.frame = frame
		await capture("res://screenshots/title_chase_%d.png" % frame)
	scene.open_modal("signin")
	await capture("res://screenshots/title_signin.png")
	scene.close_modal()
	scene.open_modal("create")
	await capture("res://screenshots/title_create.png")
	scene.close_modal()
	root.size = Vector2i(1600,720)
	await process_frame
	scene._layout()
	scene._process(0.0)
	await capture("res://screenshots/title_wide.png")
	quit()
