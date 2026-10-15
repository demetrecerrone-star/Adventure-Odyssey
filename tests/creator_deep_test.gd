extends SceneTree
# Exhaustive Godot creator regression test; no Android export required.
func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CREATOR DEEP TEST FAILED: " + message)
		quit(1)
		return false
	return true

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._open_creator()
	await process_frame
	if not _check(scene.preview_class.text == "Warrior", "default class"):return
	if not _check(scene.preview_base.texture != null and scene.preview_hair.texture != null, "initial preview textures"):return
	for i in range(6):
		if not _check(scene.preview_class.text == scene.CLASSES[i], "class cycling %d" % i):return
		if not _check(not scene.preview_class_description.text.is_empty(), "class descriptions %d" % i):return
		scene._select_class(1)
	if not _check(scene.preview_class.text == "Warrior", "classes wrap around"):return
	for i in range(8):
		if not _check(scene.body_index == i and scene.preview_base.texture != null, "body appearance %d" % i):return
		scene._select_body(1)
	if not _check(scene.body_index == 0, "body wrap around"):return
	for i in range(scene.HAIR.size()):
		if not _check(scene.hair_index == i and scene.preview_hair.texture != null, "hairstyle %d" % i):return
		scene._select_hair(1)
	if not _check(scene.hair_index == 0, "hair wrap around"):return
	for i in range(scene.HAIR_TINTS.size()):
		if not _check(scene.hair_tint_index == i, "hair color %d" % i):return
		scene._select_hair_tint(1)
	if not _check(scene.hair_tint_index == 0, "hair colors wrap around"):return
	for i in range(4):
		if not _check(scene.preview_direction_index == i and scene.preview_base.texture != null and scene.preview_hair.texture != null, "four-way preview %d" % i):return
		scene._rotate_preview(1)
	if not _check(scene.preview_direction_index == 0, "rotation wraps around"):return
	if not _check(not scene._valid_character_name(""), "empty name invalid"):return
	if not _check(not scene._valid_character_name(" "), "space-only invalid"):return
	if not _check(not scene._valid_character_name("A"), "short name invalid"):return
	if not _check(not scene._valid_character_name("No/Slash"), "slash invalid"):return
	if not _check(scene._valid_character_name("Test Hero"), "space in name accepted"):return
	if not _check(scene._valid_character_name("Renée"), "Unicode letters accepted"):return
	if not _check(scene._valid_character_name("Apostrophe's Hero"), "apostrophe accepted"):return
	# Check functional control geometry inside the landscape viewport.
	var button_count = 0
	for c in scene.ui.get_children():
		if c is Button:
			button_count += 1
			var rect: Rect2 = c.get_global_rect()
			if not _check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 1280 and rect.end.y <= 720, "off-screen button " + c.text):return
	if not _check(button_count >= 16, "all creator buttons present"):return
	scene.char_input.text = " "
	scene._confirm_character()
	if not _check(scene.creator_confirm_layer == null and not scene.creator_error.text.is_empty(), "invalid name blocks confirmation"):return
	scene.char_input.text = "Test Hero"
	scene._select_class(4)
	scene._select_body(5)
	scene._select_hair(7)
	scene._select_hair_tint(4)
	scene._confirm_character()
	if not _check(scene.creator_confirm_layer != null, "confirmation overlay opens"):return
	scene._cancel_creator_confirmation()
	await process_frame
	if not _check(scene.creator_confirm_layer == null, "confirmation can be canceled"):return
	scene._confirm_character()
	if not _check(scene.creator_confirm_layer != null, "confirmation reopens"):return
	scene._create_character()
	await process_frame
	if not _check(scene.player != null and scene.current_map == "town", "new character enters town"):return
	if not _check(scene.data["class"] == "Assassin" and scene.data["name"] == "Test Hero" and int(scene.data["body"]) == 5 and int(scene.data["hair"]) == 7 and int(scene.data["hair_tint"]) == 4, "selection data saved"):return
	if not _check(scene.hair_sprite.modulate == scene.HAIR_TINTS[4], "hair dye carried into world"):return
	if not _check(scene._load_save(), "saved character reloads"):return
	if not _check(int(scene.data["hair_tint"]) == 4 and int(scene.data["body"]) == 5, "saved appearance persisted"):return
	scene._enter_world("forest", Vector2(600,490))
	await process_frame
	if not _check(scene.hair_sprite.modulate == scene.HAIR_TINTS[4], "hair dye carried across maps"):return
	print("ADVENTURE ODYSSEY CREATOR DEEP TEST: PASS")
	quit(0)
