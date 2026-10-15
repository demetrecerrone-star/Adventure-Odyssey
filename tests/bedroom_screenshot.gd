extends SceneTree
# Capture the actual game viewport with the new bedroom loaded.
func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("bedroom",scene.BEDROOM_SPAWN)
	for i in range(12):
		await process_frame
	var image=root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	if image.get_width()<500 or image.get_height()<300:
		push_error("BEDROOM SCREENSHOT: viewport too small")
		quit(1)
		return
	var err=image.save_png("res://screenshots/starter_bedroom.png")
	if err!=OK:
		push_error("BEDROOM SCREENSHOT: could not write PNG")
		quit(1)
		return
	print("BEDROOM SCREENSHOT: screenshots/starter_bedroom.png")
	quit(0)
