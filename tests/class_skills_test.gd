extends SceneTree
# Regression: the 18 original skills work from character creation with no mentor gate.
func _initialize()->void:
	call_deferred("_run")

func _ok(value:bool,description:String)->bool:
	if not value:
		push_error("CLASS SKILLS TEST FAILED: "+description)
		quit(1)
		return false
	return true

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	var classes=["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]
	var expected={
		"Warrior":["Power Slash","Shield Bash","Battle Cry"],
		"Ranger":["Aimed Shot","Quick Volley","Snare Trap"],
		"Mage":["Firebolt","Frost Nova","Arcane Barrier"],
		"Necromancer":["Raise Skeleton","Soul Bolt","Life Drain"],
		"Assassin":["Backstab","Shadowstep","Poison Blade"],
		"Paladin":["Holy Strike","Divine Heal","Sacred Shield"]
	}
	var unique:Dictionary={}
	for hero_class in classes:
		scene._random_default()
		scene.data["class"]=hero_class
		scene.data["skill_unlocked"]=false # old save field cannot lock starters
		scene.data["guild_training_completed"]=false
		var skillset:Array=scene._starter_skills()
		if not _ok(skillset.size()==3,hero_class+" has exactly three starters"):return
		for slot in range(3):
			if not _ok(str(skillset[slot]["name"])==expected[hero_class][slot],hero_class+" original skill name and slot"):return
			unique[str(skillset[slot]["name"])]=true
		scene._enter_world("forest",Vector2(430,640))
		await process_frame
		scene._dismiss_message()
		if not _ok(scene.skill_cooldowns.size()==3,hero_class+" has three skill cooldowns"):return
		# All three skill buttons are visible before any Guild or mentor quest.
		var names:Array=[]
		for control in scene.hud.get_children():
			if control is Button:
				names.append(control.text)
		for name in expected[hero_class]:
			if not _ok(names.has(str(name).to_upper()),hero_class+" HUD shows "+str(name)):return
		var target:Dictionary=scene.mobs[0]
		scene.player.position=target["node"].position+Vector2(70,10)
		scene.data["hp"]=65
		for slot in range(3):
			scene.skill_cooldowns[slot]=0.0
			target=scene.mobs[0]
			if not target["alive"]:
				target=scene.mobs[1]
			scene.player.position=target["node"].position+Vector2(70,10)
			var previous_hp:int=int(target["hp"])
			var previous_player_hp:int=int(scene.data["hp"])
			var kind:String=str(skillset[slot]["kind"])
			if kind=="step":
				scene.player.position=target["node"].position+Vector2(120,0)
			scene._use_starting_skill(slot)
			if not _ok(scene.skill_cooldowns[slot]>0.0,hero_class+" skill "+str(slot)+" is ready from level one"):return
			match kind:
				"cleave","stun","ranged","volley","burn","nova","drain","backstab","poison","holy":
					if not _ok(int(target["hp"])<previous_hp,hero_class+" "+kind+" damages an enemy"):return
				"buff":
					if not _ok(scene.battle_cry_timer>0.0,hero_class+" gets battle cry buff"):return
				"trap":
					if not _ok(scene.trap_timer>0.0,hero_class+" can lay a trap"):return
				"barrier","shield":
					if not _ok(scene.barrier_charges>0,hero_class+" shield has damage blocks"):return
				"summon":
					if not _ok(scene.summon_actor!=null and scene.summon_timer>0.0,hero_class+" summoned ally exists"):return
				"step":
					if not _ok(scene.player.position.distance_to(target["node"].position)<=80.0,hero_class+" shadowstep repositions"):return
				"heal":
					if not _ok(int(scene.data["hp"])>previous_player_hp,hero_class+" healing works"):return
			if kind=="stun" and not _ok(float(target.get("stun_timer",0.0))>0.0,"Shield Bash stuns"):return
			if kind=="burn" and not _ok(float(target.get("burn_timer",0.0))>0.0,"Firebolt burns"):return
			if kind=="nova" and not _ok(float(target.get("slow_timer",0.0))>0.0,"Frost Nova slows"):return
			if kind=="poison" and not _ok(float(target.get("poison_timer",0.0))>0.0,"Poison Blade poisons"):return
			if kind=="drain" and not _ok(int(scene.data["hp"])>previous_player_hp,"Life Drain heals"):return
			var hp_after:int=int(target["hp"])
			scene._use_starting_skill(slot)
			if not _ok(int(target["hp"])==hp_after,hero_class+" cooldown prevents spam"):return
			scene._dismiss_message()
		scene._save()
		if not _ok(scene._load_save() and str(scene.data["class"])==hero_class,hero_class+" save works"):return
		if not _ok(scene._starter_skills().size()==3 and scene._starter_skills()[0]["name"]==expected[hero_class][0],hero_class+" starter availability after reload"):return
	if not _ok(unique.size()==18,"all original eighteen starter skills are distinct"):return
	print("ADVENTURE ODYSSEY CLASS SKILLS TEST: PASS")
	quit(0)
