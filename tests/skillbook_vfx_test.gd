extends SceneTree
func _initialize()->void:
	call_deferred("_run")
func _ok(yes:bool,desc:String)->bool:
	if not yes:
		push_error("SKILLBOOK TEST FAILED: "+desc)
		quit(1)
		return false
	return true
func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	var classes=["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]
	for klass in classes:
		game._random_default()
		game.data["class"]=klass
		game._enter_world("forest",Vector2(430,640))
		await process_frame
		game._dismiss_message()
		var named_buttons:Array=[]
		for child in game.hud.get_children():
			if child is Button:named_buttons.append(child.text)
		if not _ok(named_buttons.has("SKILLBOOK") and named_buttons.has("QUEST JOURNAL"),klass+" HUD contains navigation"):return
		game._open_skillbook()
		if not _ok(game.popup!=null and game.popup.get_child_count()>12,klass+" all skills are documented"):return
		game._dismiss_message()
		game._open_quest_journal()
		if not _ok(game.popup!=null and game.popup.get_child_count()>9,klass+" categorized journal exists"):return
		game._dismiss_message()
		for skill in game._starter_skills():
			game._play_ability_fx(str(skill["name"]),str(skill["kind"]))
		game._play_ability_fx(str(game._mentor_skill_info()["name"]),"advanced")
		var count:int=0
		for effect in game.world.get_children():
			if effect.has_method("configure"):
				count+=1
				if not _ok(effect.has_method("configure"),klass+" effect draws world geometry"):return
		if not _ok(count==4,klass+" three starters plus advanced effect"):return
	print("ADVENTURE ODYSSEY SKILLBOOK VFX TEST: PASS")
	quit(0)
