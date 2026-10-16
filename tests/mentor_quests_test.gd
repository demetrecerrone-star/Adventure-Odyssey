extends SceneTree
# Six class mentors, explicit offer, three starter demonstrations, two kills,
# persistence, and one distinct advanced ability per class.
func _initialize()->void:
	call_deferred("_run")

func _ok(value:bool,info:String)->bool:
	if not value:
		push_error("MENTOR QUEST TEST FAILED: "+info)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	var owners={
		"Warrior":"Captain Elara Voss",
		"Ranger":"Garrick Thorn",
		"Mage":"Mira Ashwood",
		"Necromancer":"Neris Crowe",
		"Assassin":"Kael Rook",
		"Paladin":"Sister Sera Vale"
	}
	var names={}
	for klass in owners.keys():
		game._random_default()
		game.data["class"]=klass
		game.data["level"]=2
		game.data["guild_training_completed"]=true
		if not _ok(game._skill_mentor()==owners[klass],klass+" correct original NPC mentor"):return
		game._enter_world("town",Vector2(1030,980))
		await process_frame
		game._dismiss_message()
		if not _ok(game._mentor_quest_state()=="" and not game._has_mentor_skill(),klass+" starts with only three unlocked starters"):return
		if not _ok(game.hud.get_node_or_null("MentorSkillButton")==null,klass+" no premature unlock button"):return
		if not _ok(game._starter_skills().size()==3,klass+" original starter list unchanged"):return
		game._accept_mentor_training()
		if not _ok(game._mentor_quest_state()=="active",klass+" accepted advanced trial"):return
		game._dismiss_message()
		game._enter_world("forest",Vector2(430,640))
		await process_frame
		game._dismiss_message()
		var state:Dictionary=game._mentor_quest()
		for slot in range(3):
			game._mentor_record_cast(slot)
		if not _ok(game._mentor_quest()["casts"]==[true,true,true],klass+" records each starter skill"):return
		game._mentor_record_kill()
		if not _ok(game._mentor_quest_state()=="active",klass+" requires a second defeat"):return
		game._mentor_record_kill()
		if not _ok(game._mentor_quest_state()=="ready",klass+" two defeats finish trial"):return
		if not _ok(not game._has_mentor_skill(),klass+" not rewarded before returning to mentor"):return
		if not _ok(game._save() and game._load_save(),klass+" quest is save compatible"):return
		if not _ok(game._mentor_quest_state()=="ready",klass+" quest progress persisted"):return
		game._enter_world("town",Vector2(1030,980))
		await process_frame
		game._dismiss_message()
		game._grant_mentor_skill({"name":owners[klass],"role":"Mentor","variant":"garrick_thorn","dialogue":"Welcome"})
		if not _ok(game._mentor_quest_state()=="complete" and game._has_mentor_skill(),klass+" rewards after return"):return
		var info:Dictionary=game._mentor_skill_info()
		if not _ok(not names.has(str(info["name"])),klass+" new advanced ability is unique"):return
		names[str(info["name"])]=true
		if not _ok(game.hud.get_node_or_null("MentorSkillButton")!=null,klass+" advanced skill button visible"):return
		game._dismiss_message()
		game._enter_world("forest",Vector2(430,640))
		await process_frame
		game._dismiss_message()
		game._use_mentor_skill()
		if not _ok(game.mentor_skill_cooldown>0.0,klass+" unlocked ability activates"):return
		if not _ok(game._save() and game._load_save() and game._has_mentor_skill(),klass+" learned ability persists"):return
		game._mentor_record_kill()
		if not _ok(game._mentor_quest_state()=="complete",klass+" quest reward never repeats"):return
	if not _ok(names.size()==6,"exactly six distinct advanced class abilities"):return
	print("ADVENTURE ODYSSEY MENTOR QUESTS TEST: PASS")
	quit(0)
