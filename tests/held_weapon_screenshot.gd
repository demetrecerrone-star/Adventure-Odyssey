extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
func run() -> void:
	root.size = Vector2i(1280, 1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var canvas := Control.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 1000)
	bg.color = Color("eee5d2")
	canvas.add_child(bg)
	for selected_class in preload("res://src/creator/catalog.gd").CLASSES:
		for row in range(4):
			for direction in range(4):
				var avatar = preload("res://src/layered_avatar.gd").new()
				canvas.add_child(avatar)
				avatar.configure("male" if row < 2 else "female", selected_class, {"skin":"blue" if row == 3 else "warm", "eyes":"Green"})
				avatar.set_equipped_weapon(selected_class.to_lower() + "_01_weapon")
				avatar.advance(direction, row % 2 == 1, 0.1875)
				avatar.position = Vector2(direction * 320 + 160, row * 250 + 244)
				var title := Label.new()
				title.text = ("male" if row < 2 else "female") + (" walk " if row % 2 else " idle ") + ["down", "left", "right", "up"][direction]
				title.position = Vector2(direction * 320 + 12, row * 250 + 4)
				title.add_theme_color_override("font_color", Color("30291e"))
				canvas.add_child(title)
		await capture("res://screenshots/held_weapon_" + selected_class.to_lower() + ".png")
		for child in canvas.get_children():
			if child != bg: child.queue_free()
		await process_frame
	canvas.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	var room = preload("res://src/bedroom.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.username = "HeldWeaponPreview"
	room.state.path = "user://weapon_capture.json"
	assert(room.state.create(draft.payload()))
	assert(room.state.transfer("warrior_01_weapon", false))
	assert(room.state.equip("warrior_01_weapon"))
	root.add_child(room)
	await process_frame
	room.set_process(false)
	room.player = Vector2(335, 735)
	room._update_actor()
	room.actor.advance(0, true, 0.1875)
	await capture("res://screenshots/held_weapon_behind_chest.png")
	room.player = Vector2(335, 890)
	room._update_actor()
	await capture("res://screenshots/held_weapon_front_chest.png")
	DirAccess.remove_absolute(room.state.path)
	quit()
