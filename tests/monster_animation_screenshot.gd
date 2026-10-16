extends SceneTree
# Native forest review capture. Requires a real display/rendering driver.
# Run: godot --path . --script res://tests/monster_animation_screenshot.gd
# Output: screenshots/wolf_directional_00.png ... 15.png (four frames per row).
func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game.data["guild_training_completed"]=true
	game._enter_world("forest",Vector2(1024,640))
	await process_frame
	game._dismiss_message()
	game.set_process(false)
	for mob in game.mobs:mob["node"].visible=false
	var gallery:Array=[]
	var directions:Array=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	for row in range(2):
		for col in range(4):
			var mob:Dictionary=game._spawn_custom_enemy("wolf",Vector2(740+col*190,540+row*220),52,7,135.0,42,6)
			mob["indicator"].visible=false
			var label=Label.new()
			label.text=["DOWN","RIGHT","UP","LEFT"][col]+(" / WALK" if row==0 else " / ATTACK")
			label.position=mob["node"].position+Vector2(-75,20)
			label.add_theme_color_override("font_outline_color",Color.BLACK)
			label.add_theme_constant_override("outline_size",7)
			label.add_theme_font_size_override("font_size",20)
			game.world.add_child(label)
			gallery.append(mob)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for frame in range(16):
		for i in range(gallery.size()):
			var mob:Dictionary=gallery[i]
			var direction:Vector2=directions[i%4]
			# Labeled art review; controller/combat synchronization is tested separately.
			var row:int=2 if direction==Vector2.UP else (0 if direction==Vector2.DOWN else 1)
			if i>=4:row+=3
			mob["sprite"].flip_h=direction==Vector2.LEFT
			mob["sprite"].frame=row*4+(frame%4)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture:Image=root.get_texture().get_image()
		if picture.is_empty() or picture.save_png("res://screenshots/wolf_directional_%02d.png"%frame)!=OK:
			push_error("Native directional wolf capture failed")
			quit(1)
			return
	print("DIRECTIONAL WOLF FOREST CAPTURE: PASS")
	quit(0)
