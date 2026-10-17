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
	for frame in [0, 3, 6, 9, 12, 15, 18, 21, 23]:
		for runner in scene.runners:
			runner.frame = frame
		await capture("res://screenshots/title_chase_%d.png" % frame)
	scene.open_modal("signin")
	await capture("res://screenshots/title_signin.png")
	scene.close_modal()
	scene.open_modal("create")
	await capture("res://screenshots/title_create.png")
	scene.fields[0].text = "hero@example.com"
	scene.fields[1].text = "preview-only"
	scene.fields[2].text = "different-preview"
	scene._submit_preview()
	await capture("res://screenshots/title_create_validation.png")
	scene.close_modal()
	for document_kind in ["privacy", "terms"]:
		scene.open_modal(document_kind)
		await capture("res://screenshots/title_%s.png" % document_kind)
		scene.close_modal()
	root.size = Vector2i(800,450)
	await process_frame
	scene.open_modal("create")
	await capture("res://screenshots/title_create_narrow.png")
	# Exercise scrolling with a simulated keyboard/cutout region. This is not
	# a device screenshot or evidence of an actual Android keyboard session.
	scene._layout_modal(Rect2(44, 24, 712, 244))
	scene.fields[2].grab_focus()
	scene._keep_focused_field_visible()
	await process_frame
	await process_frame
	await process_frame
	assert(scene.modal_scroll.get_global_rect().encloses(scene.fields[2].get_global_rect()), "Focused field must be visible in native keyboard-region capture")
	await capture("res://screenshots/title_create_keyboard_region.png")
	scene.close_modal()
	root.size = Vector2i(1600,720)
	await process_frame
	scene._layout()
	scene._process(0.0)
	await capture("res://screenshots/title_wide.png")
	quit()
