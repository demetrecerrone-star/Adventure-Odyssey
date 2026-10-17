extends SceneTree
const Catalog = preload("res://src/creator/catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func snap(path: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(path) == OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	root.size = Vector2i(1200, 1200)
	for base in ["male", "female"]:
		for page in range(3):
			var canvas := Control.new()
			root.add_child(canvas)
			var bg := ColorRect.new()
			bg.color = Color("514b55")
			bg.size = Vector2(1200,1200)
			canvas.add_child(bg)
			var avatars: Array = []
			for row in range(5):
				var index := page * 5 + row + 1
				for direction in range(4):
					var avatar = preload("res://src/layered_avatar.gd").new()
					canvas.add_child(avatar)
					assert(avatar.configure(base, "Warrior", {"skin":"warm", "eyes":"Green", "hair":"%s_hair_%02d" % [base,index], "hair_color":"Brown"}))
					avatar.advance(direction, false, 0)
					assert(avatar.hair_renderer.ready)
					avatar.position = Vector2(direction*300+150,row*240+232)
					avatar.scale = Vector2.ONE * 0.9
					avatars.append(avatar)
					var label := Label.new()
					label.text = "%02d %s / %s" % [index,Catalog.hair_label(base,index),["D","L","R","U"][direction]]
					label.position = Vector2(direction*300+8,row*240+4)
					label.add_theme_font_size_override("font_size",13)
					canvas.add_child(label)
			await snap("res://screenshots/hair_%s_%d_idle.png" % [base,page+1])
			for i in range(avatars.size()):
				avatars[i].advance(i%4, true, 0.1875)
			await snap("res://screenshots/hair_%s_%d_walk.png" % [base,page+1])
			canvas.queue_free()
			await process_frame
	var canvas := Control.new()
	root.add_child(canvas)
	for row in range(2):
		var base := "male" if row == 0 else "female"
		for c in range(6):
			var avatar = preload("res://src/layered_avatar.gd").new()
			canvas.add_child(avatar)
			assert(avatar.configure(base,"Warrior",{"skin":"warm", "eyes":"Green", "hair":base+"_hair_01", "hair_color":Catalog.HAIR_COLORS[c]}))
			avatar.position=Vector2(c*200+100,row*450+420)
			var label:=Label.new()
			label.text=base+" "+Catalog.HAIR_COLORS[c]
			label.position=Vector2(c*200+10,row*450+80)
			canvas.add_child(label)
	await snap("res://screenshots/hair_six_colors.png")
	quit()
