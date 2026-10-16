extends SceneTree
# Native Godot screenshots of original level-one skills; no generated effect sheets.
func _initialize()->void:
	call_deferred("_run")
func _snap(name:String)->bool:
	var img=root.get_viewport().get_texture().get_image()
	return img.get_width()>=500 and img.save_png("res://screenshots/"+name)==OK
func _frames()->void:
	for i in range(14):await process_frame
func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for hero_class in ["Warrior","Mage","Necromancer"]:
		game._random_default()
		game.data["class"]=hero_class
		game._enter_world("forest",Vector2(430,640))
		await process_frame
		game._dismiss_message()
		game.player.position=game.mobs[0]["node"].position+Vector2(65,10)
		game._use_starting_skill(0)
		await _frames()
		var path="starter_skills_"+hero_class.to_lower()+".png"
		if not _snap(path):
			push_error("STARTING SKILLS SCREENSHOT FAILED: "+hero_class)
			quit(1)
			return
	print("STARTING SKILLS SCREENSHOTS: PASS")
	quit(0)
