extends SceneTree
# Real Oldstone scene assets, connected dungeon floor progression and rewards.
func _initialize()->void:
	call_deferred("_run")

func _ok(value:bool,detail:String)->bool:
	if not value:
		push_error("OLDSTONE DUNGEON TEST FAILED: "+detail)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game.data["guild_training_completed"]=true
	game.data["level"]=3
	var maps=["ruins","halls","library","chapel","sanctum"]
	for m in maps:
		var path:String="res://assets/world/oldstone_%s.svg" % ("entrance" if m=="ruins" else m)
		if not _ok(ResourceLoader.exists(path),"real map exists: "+m):return
		var texture:Texture2D=load(path)
		if not _ok(texture!=null and texture.get_width()==2048 and texture.get_height()==1280,"2048x1280 map: "+m):return
		game._enter_world(m,Vector2(175,650))
		await process_frame
		if not _ok(game.current_map==m and game._is_adventure_combat_zone(),"active combat map: "+m):return
		if not _ok(game._walkable(Vector2(175,650)) and game._walkable(Vector2(1040,650)) and game._walkable(Vector2(1880,650)),"walkable east-west route: "+m):return
		if not _ok(game.mobs.size()==(1 if m=="sanctum" else 3),"encounters exist in "+m):return
		for mob in game.mobs:
			var creature_path:String=str(mob["sprite"].texture.resource_path)
			if not _ok(creature_path=="res://assets/creatures/animated/"+str(mob["appearance"])+".png","native Oldstone sprite on "+m):return
			if not _ok(mob["sprite"].texture.get_width()>=150,"actual illustrated enemy texture "+m):return
	if not _ok(game._oldstone_next_room("halls")=="library" and game._oldstone_next_room("library")=="chapel" and game._oldstone_next_room("chapel")=="sanctum","correct forward floor order"):return
	if not _ok(game._oldstone_previous_room("halls")=="ruins" and game._oldstone_previous_room("library")=="halls" and game._oldstone_previous_room("chapel")=="library","correct retreat order"):return
	if not _ok(game.mobs[0]["species"]=="guardian" and int(game.mobs[0]["hp"])==300,"old Guardian combat stats preserved"):return
	if not _ok(int(game.MONSTER_LOOT_PROFILES["guardian"]["sigil_amount"])==5 and absf(float(game.MONSTER_LOOT_PROFILES["guardian"]["sigil_chance"])-0.10)<0.0001,"independent 10 percent for 5 Sigils"):return
	for enemy in ["skeleton","bat","archer","golem"]:
		if not _ok(game.MONSTER_LOOT_PROFILES.has(enemy) and float(game.MONSTER_LOOT_PROFILES[enemy]["sigil_chance"])==0.0,"no regular enemy drops Sigils "+enemy):return
	if not _ok(int(game.GUARDIAN_FIRST_QUEST_SIGILS)==30,"30 Sigils one-time quest reward preserved"):return
	if not _ok(ResourceLoader.exists("res://assets/creatures/oldstone/moss_slime.svg"),"extra slime variation installed for later encounters"):return
	print("ADVENTURE ODYSSEY OLDSTONE DUNGEON TEST: PASS / 5 maps, 4 floors, 3 encounters each, real creature art, boss rewards")
	quit(0)
