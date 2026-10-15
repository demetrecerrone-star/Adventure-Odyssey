extends SceneTree
# Godot-native 1280x720 review captures of both interaction interfaces.
func _initialize() -> void:
	call_deferred("_run")

func _snap(file_name: String) -> bool:
	var image = root.get_viewport().get_texture().get_image()
	if image.get_width() < 500 or image.get_height() < 300:
		push_error("DIALOGUE PREVIEW: small viewport")
		quit(1)
		return false
	var path = "res://screenshots/" + file_name
	if image.save_png(path) != OK:
		push_error("DIALOGUE PREVIEW: failed " + path)
		quit(1)
		return false
	print("DIALOGUE SCREENSHOT: " + path)
	return true

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._random_default()
	scene._enter_world("bedroom", scene.BEDROOM_SPAWN)
	scene._show_intro_tutorial()
	scene.popup.body_label.visible_characters = -1
	for i in range(12): await process_frame
	if not _snap("tutorial_dialogue.png"): return
	scene._dismiss_message()
	scene._enter_world("town", Vector2(915,870))
	scene._show_npc_chat(scene.npcs[0])
	scene.popup.body_label.visible_characters = -1
	for i in range(12): await process_frame
	if not _snap("npc_dialogue.png"): return
	print("ADVENTURE ODYSSEY DIALOGUE PREVIEWS: PASS")
	quit(0)
