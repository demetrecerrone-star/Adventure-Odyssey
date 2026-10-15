extends SceneTree
# Run under xvfb-run to capture the actual Godot-rendered creator.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._open_creator()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.get_width() < 1000 or frame.get_height() < 500:
		push_error("Creator screenshot was blank or unexpectedly small.")
		quit(1)
		return
	if frame.save_png("res://screenshots/character_creator.png") != OK:
		push_error("Unable to save character creator screenshot.")
		quit(1)
		return
	print("CREATOR VISUAL CAPTURE: saved "+str(frame.get_width())+"x"+str(frame.get_height())+" screenshot")
	quit(0)
