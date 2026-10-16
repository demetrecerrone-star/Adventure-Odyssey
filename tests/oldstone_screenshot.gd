extends SceneTree
# Real Godot renders, not standalone design mockups.
func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene.data["guild_training_completed"]=true
	scene.data["level"]=3
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for zone in ["ruins","halls","library","chapel","sanctum"]:
		scene._enter_world(zone,Vector2(1024,654))
		await process_frame
		scene._dismiss_message()
		for frame in range(16):
			await process_frame
		var img=root.get_viewport().get_texture().get_image()
		if img.get_width()<500 or img.get_height()<300:
			push_error("OLDSTONE SCREENSHOT FAILED: invalid viewport in "+zone)
			quit(1)
			return
		var file:String="res://screenshots/oldstone_%s.png" % ("entrance" if zone=="ruins" else zone)
		if img.save_png(file)!=OK:
			push_error("OLDSTONE SCREENSHOT FAILED: "+file)
			quit(1)
			return
	print("ADVENTURE ODYSSEY OLDSTONE SCREENSHOTS: PASS / 5 real playable locations")
	quit(0)
