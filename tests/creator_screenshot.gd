extends SceneTree
# Capture three actual Godot UI states with the native OpenGL renderer under Xvfb.
func _initialize() -> void:
	call_deferred("_capture")

func _snap(filename: String) -> bool:
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.get_width() < 1000 or frame.get_height() < 500:
		push_error("Creator screenshot blank or unexpectedly small: " + filename)
		return false
	var distinct: Dictionary = {}
	for y in range(0, frame.get_height(), 60):
		for x in range(0, frame.get_width(), 80):
			distinct[frame.get_pixel(x, y).to_html(false)] = true
	if distinct.size() < 8:
		push_error("Creator screenshot appears blank: " + filename)
		return false
	if frame.save_png("res://screenshots/"+filename) != OK:
		push_error("Unable to save creator screenshot: " + filename)
		return false
	print("CREATOR VISUAL CAPTURE: "+filename+" "+str(frame.get_width())+"x"+str(frame.get_height())+" with "+str(distinct.size())+" sampled colors")
	return true

func _capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._open_creator()
	for i in range(5):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	if not _snap("character_creator.png"):
		quit(1)
		return
	scene.char_input.text = "Test Hero"
	scene._select_class(3)
	scene._select_body(5)
	scene._select_hair(8)
	scene._select_hair_tint(4)
	scene._select_skin(3)
	scene._select_eye(2)
	scene._rotate_preview(1)
	for i in range(5):
		await process_frame
	if not _snap("character_creator_customized.png"):
		quit(1)
		return
	scene._confirm_character()
	for i in range(5):
		await process_frame
	if not _snap("character_creator_confirmation.png"):
		quit(1)
		return
	print("CREATOR VISUAL CHECK: PASS")
	quit(0)
