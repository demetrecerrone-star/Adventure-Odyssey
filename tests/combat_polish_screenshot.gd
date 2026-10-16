extends SceneTree
# Screenshots come directly from the running native Godot gameplay renderer.
func _initialize()->void:
	call_deferred("_run")

func _snap(filename:String)->bool:
	var image:Image=root.get_viewport().get_texture().get_image()
	return image.get_width()>=500 and image.save_png("res://screenshots/"+filename)==OK

func _frames(n:int)->void:
	for i in range(n):await process_frame

func _grid(game,entries:Array)->Array:
	var nodes:Array=[]
	var origins=[Vector2(-300,-170),Vector2(0,-170),Vector2(300,-170),Vector2(-300,160),Vector2(0,160),Vector2(300,160)]
	var classes=["Warrior","Mage","Mage","Mage","Paladin","Paladin"]
	for i in range(entries.size()):
		var name:String=str(entries[i][0])
		var kind:String=str(entries[i][1])
		var origin:Vector2=game.player.position+origins[i]
		var fx=Node2D.new()
		fx.set_script(load("res://scripts/skill_effect.gd"))
		game.world.add_child(fx)
		var tint:Color=Color(str(game.CLASS_ACCENTS.get(classes[i],"#ffffff")))
		var target:Vector2=origin+Vector2(125,0) if kind in ["projectile","volley","dash","mark","drain"] else origin
		fx.call("configure",name,origin,target,tint,kind)
		nodes.append(fx)
		var title=Label.new()
		title.text=name.to_upper()
		title.position=origin+Vector2(-105,-104)
		title.add_theme_font_size_override("font_size",19)
		title.add_theme_color_override("font_color",Color("#fff1d4"))
		game.world.add_child(title)
		nodes.append(title)
	return nodes

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	game._random_default()
	game.data["class"]="Mage"
	game.data["guild_training_completed"]=true
	game._enter_world("forest",Vector2(1030,720))
	await process_frame
	game._dismiss_message()
	game.set_process(false)
	var first=_grid(game,[
		["Power Slash","cleave"],["Firebolt","projectile"],["Frost Nova","nova"],
		["Arcane Barrier","barrier"],["Holy Strike","holy"],["Divine Heal","heal"]
	])
	await _frames(10)
	if not _snap("combat_effects_starters.png"):
		push_error("AO COMBAT SCREENSHOT FAILED: starters")
		quit(1)
		return
	for node in first:node.queue_free()
	await process_frame
	var second=_grid(game,[
		["Earthshaker","impact"],["Hunter's Mark","mark"],["Meteor Burst","nova"],
		["Death Echo","drain"],["Smoke Veil","smoke"],["Consecration","heal"]
	])
	await _frames(10)
	if not _snap("combat_effects_mentors.png"):
		push_error("AO COMBAT SCREENSHOT FAILED: mentors")
		quit(1)
		return
	for node in second:node.queue_free()
	print("ADVENTURE ODYSSEY COMBAT SCREENSHOTS: PASS / native starter and mentor FX")
	quit(0)
