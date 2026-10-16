extends SceneTree
# Six distinct catalog entries, 576 registered transparent frames, 48 sheets.
func _initialize()->void:call_deferred("_run")
func _ok(good:bool,what:String)->bool:
	if not good:
		push_error("AO GUARDIAN WEAPONS TEST FAILED: "+what)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	var class_weapons:Dictionary={
		"Warrior":"Oldstone Oathblade",
		"Ranger":"Oldstone Starbow",
		"Mage":"Oldstone Astral Staff",
		"Necromancer":"Oldstone Soulreaper",
		"Assassin":"Oldstone Twin Fangs",
		"Paladin":"Oldstone Dawnlance"
	}
	if not _ok(game.GUARDIAN_LEGACY_WEAPONS==class_weapons,"all six actual starting classes mapped correctly"):return
	var expected_sheets:int=0
	var expected_frames:int=0
	for klass in class_weapons.keys():
		var name:String=class_weapons[klass]
		var definition:Dictionary=game._gear_def(name)
		if not _ok(str(definition.get("slot",""))=="weapon" and str(definition.get("rarity",""))=="Epic",klass+" quest heirloom is an Epic item"):return
		var slug:String=name.to_lower().replace(" ","_")
		if not _ok(ResourceLoader.exists("res://assets/equipment_item_icons/"+slug+".png"),klass+" has inventory icon"):return
		for body in range(1,9):
			var sheet:String="res://assets/guardian_weapon_sheets/%s/base_variant_%02d.png" % [slug,body]
			if not _ok(ResourceLoader.exists(sheet),klass+" sheet for body "+str(body)):return
			if not _ok(load(sheet).get_width()==231 and load(sheet).get_height()==512,"sheets are 3x4 synchronized 77x128 frames"):return
			expected_sheets+=1
			for face in ["down","left","up","right"]:
				for frame in range(3):
					var path:String="res://assets/equipment_worn/weapon/%s/base_variant_%02d/%s_%02d.png" % [slug,body,face,frame]
					if not _ok(ResourceLoader.exists(path),klass+" transparent pose exists "+path):return
					expected_frames+=1
	game._enter_world("town",Vector2(1010,900))
	await process_frame
	for klass in class_weapons.keys():
		game.data["class"]=klass
		game.data["guardian_defeated"]=true
		game.data["guardian_quest_state"]="ready"
		game.data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()
		game.data["sigils"]=0
		var weapon:String=class_weapons[klass]
		if not _ok(game._claim_guardian_quest_reward(),"quest claim succeeds for "+klass):return
		if not _ok(int(game.data["inventory"].get(weapon,0))>0 and game.data["guardian_quest_weapon"]==weapon,klass+" received its correct item"):return
		if not _ok(game._sigils_balance()==30,"30 fixed quest Sigils for "+klass):return
		if not _ok(not game._claim_guardian_quest_reward(),"quest cannot double-claim for "+klass):return
		game._dismiss_message()
		game._equip_item(weapon)
		if not _ok(game._equipped("weapon")==weapon,"item is wearable regardless of class"):return
		for face in ["down","left","up","right"]:
			game.facing=face
			for frame in range(3):
				game.anim_frame=frame
				game._set_player_frame()
				var visible:Sprite2D=game.worn_equipment_sprites["weapon"]
				if not _ok(visible.visible and visible.texture!=null,klass+" uses actual attached frames on "+face+"/"+str(frame)):return
		if not _ok(game._save() and game._load_save() and game._equipped("weapon")==weapon,"equipment persists in save"):return
	if not _ok(expected_sheets==48 and expected_frames==576,"all 48 sheets and 576 overlays were checked"):return
	print("ADVENTURE ODYSSEY GUARDIAN WEAPONS TEST: PASS / 6 real class weapons, 576 frames, 48 sheets, one-time claims")
	quit(0)
