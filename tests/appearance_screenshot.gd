extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 1200)
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("eee5d2")
	background.size = Vector2(1200, 1200)
	canvas.add_child(background)
	var avatars: Array = []
	var titles: Array = []
	var combinations := [["male", "Warrior"], ["female", "Mage"], ["male", "Ranger"], ["female", "Paladin"]]
	var palettes := [["warm", "Brown"], ["blue", "Violet"], ["red", "Green"]]
	for row in range(4):
		for column in range(3):
			var avatar = preload("res://src/layered_avatar.gd").new()
			canvas.add_child(avatar)
			assert(avatar.configure(combinations[row][0], combinations[row][1], {"skin":palettes[column][0], "eyes":palettes[column][1]}))
			assert(avatar.palette_ready)
			avatars.append(avatar)
			avatar.position = Vector2(column * 400 + 200, row * 300 + 278)
			avatar.scale = Vector2.ONE * 1.15
			var title := Label.new()
			title.text = "%s %s | %s / %s" % [combinations[row][0], combinations[row][1], palettes[column][0], palettes[column][1]]
			title.position = Vector2(column * 400 + 16, row * 300 + 8)
			title.add_theme_color_override("font_color", Color("30291e"))
			canvas.add_child(title)
			titles.append(title)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	assert(image.save_png("res://screenshots/appearance_palettes.png") == OK)
	for index in range(avatars.size()):
		avatars[index].advance(index % 4, true, 0.1875)
		titles[index].text += " | " + ["down", "left", "right", "up"][index % 4]
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/appearance_walk_palettes.png") == OK)
	quit()
