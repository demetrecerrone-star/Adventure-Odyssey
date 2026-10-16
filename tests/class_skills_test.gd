extends SceneTree
# All six classes: accepted mentor skill trials, unlocks, cool downs and scaling.
func _initialize()->void:
	call_deferred("_run")
func _ok(ok:bool,why:String)->bool:
	if not ok:
		push_error("CLASS SKILLS TEST FAILED: "+why)
		quit(1)
		return false
	return true
func _find_mentor(scene:Node, name:String)->Dictionary:
	for person in scene.npcs:
		if str(person["name"])==name:return person
	return {}
func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	var classes=["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]
	var names=[]
	for hero_class in classes:
		scene._random_default()
		scene.data["class"]=hero_class
		scene.data["guild_training_completed"]=true
		scene.data["world_minutes"]=720.0
		scene._enter_world("town",Vector2(1030,980))
		await process_frame
		var skill=scene._class_skill()
		var mentor_name=scene._skill_mentor()
		names.append(skill["name"])
		var mentor=_find_mentor(scene,mentor_name)
		if not _ok(not mentor.is_empty(),hero_class+" mentor present in town at noon"):return
		if not _ok(not bool(scene.data.get("skill_unlocked",false)),hero_class+" skill initially locked"):return
		scene._interact_resident(mentor)
		if not _ok(scene.popup!=null and scene.popup.mode=="npc" and scene.popup.quest_accept_callback.is_valid(),hero_class+" class quest offer"):return
		if not _ok(not bool(scene.data.get("skill_trial_accepted",false)),hero_class+" quest not accepted just by talking"):return
		scene.popup._accept_quest_pressed()
		if not _ok(bool(scene.data.get("skill_trial_accepted",false)),hero_class+" skill trial accepted"):return
		if not _ok(scene.popup.mode=="tutorial" and scene.popup.pages.size()==4,hero_class+" skill journal opened"):return
		scene._dismiss_message()
		scene._enter_world("forest",Vector2(430,640))
		await process_frame
		scene._dismiss_message()
		for hit in range(4):
			var mob=scene.mobs[0] if hit<3 else scene.mobs[1]
			scene.player.position=mob["node"].position+Vector2(45,12)
			scene.attack_cooldown=0.0
			scene._attack()
			if not _ok(int(scene.data.get("skill_trial_hits",0))==hit+1,hero_class+" basic-hit trial progress"):return
		if not _ok(scene.popup!=null and scene.popup.mode=="tutorial" and scene.popup.chapter.contains("TRIAL COMPLETE"),hero_class+" fourth hit completion journal"):return
		scene._dismiss_message()
		scene._enter_world("town",Vector2(1030,980))
		await process_frame
		mentor=_find_mentor(scene,mentor_name)
		if not _ok(not mentor.is_empty(),hero_class+" mentor returns for turn-in"):return
		scene._interact_resident(mentor)
		if not _ok(bool(scene.data.get("skill_unlocked",false)),hero_class+" skill unlocked"):return
		if not _ok(scene.popup.mode=="tutorial" and scene.popup.chapter=="NEW CLASS SKILL UNLOCKED",hero_class+" unlock journal"):return
		scene._dismiss_message()
		scene._enter_world("forest",Vector2(430,640))
		await process_frame
		scene._dismiss_message()
		var enemy=scene.mobs[0]
		scene.player.position=enemy["node"].position+Vector2(70,8)
		scene.skill_cooldown=0.0
		scene.data["hp"]=75
		var hp0:int=int(enemy["hp"])
		scene._use_class_skill()
		if not _ok(int(enemy["hp"])<hp0,hero_class+" skill damages a slime"):return
		if not _ok(scene.skill_cooldown>0.0,hero_class+" skill starts cooldown"):return
		var hp1:int=int(enemy["hp"])
		scene._use_class_skill()
		if not _ok(int(enemy["hp"])==hp1,hero_class+" skill cannot spam on cooldown"):return
		if hero_class in ["Necromancer","Paladin"]:
			if not _ok(int(scene.data["hp"])>75,hero_class+" healing skill grants HP"):return
		else:
			if not _ok(int(scene.data["hp"])==75,hero_class+" damage-only skill does not heal"):return
		scene._save()
		if not _ok(scene._load_save() and bool(scene.data.get("skill_unlocked",false)),hero_class+" unlock persists after load"):return
		scene._dismiss_message()
	if not _ok(names.size()==6 and names[0]!=names[1] and names[4]!=names[5],"six distinct signature skills"):return
	print("ADVENTURE ODYSSEY CLASS SKILLS TEST: PASS")
	quit(0)
