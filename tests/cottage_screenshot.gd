extends SceneTree
# Capture the actual cottage viewport using the Godot software renderer.
func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("cottage",Vector2(1040,740))
	for i in range(12):
		await process_frame
	var image=root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	if image.get_width()<500 or image.get_height()<300:
		push_error("COTTAGE SCREENSHOT: viewport too small")
		quit(1)
		return
	var err=image.save_png("res://screenshots/starter_cottage.png")
	if err!=OK:
		push_error("COTTAGE SCREENSHOT: failed to save PNG")
		quit(1)
		return
	print("COTTAGE SCREENSHOT: screenshots/starter_cottage.png")
	quit(0)
