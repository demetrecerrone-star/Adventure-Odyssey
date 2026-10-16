extends SceneTree
func _initialize()->void:
	call_deferred("_run")
func _check(value:bool,label:String)->bool:
	if not value:
		push_error("AO WORLD TEST FAILED: "+label)
		quit(1)
		return false
	return true
func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("forest",Vector2(430,640))
	await process_frame
	if not _check(scene.mobs.size()==4,"beginner forest keeps four slimes"):return
	scene._dismiss_message()
	scene.data["guild_training_completed"]=true
	scene.data["level"]=3
	scene._enter_world("forest",Vector2(430,640))
	await process_frame
	scene._dismiss_message()
	if not _check(scene.mobs.size()==7,"advanced forest adds three distinct monsters"):return
	for i in range(4,7):
		var m:Dictionary=scene.mobs[i]
		if not _check(m["sprite"].texture!=null and m["sprite"].texture.resource_path.contains("/creatures/"),"new monster sprite imported"):return
	scene._accept_expedition()
	if not _check(scene._expedition_state()=="active","side quest accepted"):return
	scene._dismiss_message()
	for i in [4,5]:
		var mob:Dictionary=scene.mobs[i]
		scene._apply_slime_damage(mob,999,true)
	if not _check(scene._expedition_state()=="ready","two wild enemies completed side quest"):return
	if not _check(int(scene.data["quest_kills"])==0,"non-slimes do not advance the starter Guild quest"):return
	if not _check(int(scene.data["inventory"].get("Iron Ore",0))>=1,"goblins drop forging materials"):return
	if not _check(scene._save() and scene._load_save() and scene._expedition_state()=="ready","side progress survives load"):return
	scene._enter_world("ruins",Vector2(130,655))
	await process_frame
	if not _check(scene.current_map=="ruins" and scene.mobs.size()==3,"Oldstone has unique inhabitants"):return
	if not _check(scene._walkable(Vector2(450,650)),"ruins trails can be traversed"):return
	scene._enter_world("sanctum",Vector2(175,650))
	await process_frame
	if not _check(scene.current_map=="sanctum" and scene.mobs.size()==1,"sanctum has one guardian boss"):return
	var boss:Dictionary=scene.mobs[0]
	if not _check(int(boss["hp"])==300 and boss["species"]=="guardian","guardian is a multi-hit boss"):return
	scene.player.position=boss["node"].position+Vector2(50,0)
	scene._apply_slime_damage(boss,500,true)
	if not _check(bool(scene.data.get("guardian_defeated",false)),"boss defeated flag stored"):return
	if not _check(scene._sigils_balance() in [0,5],"boss-only Sigils are a rare 5-Sigil roll, not a guaranteed 25"):return
	var first_boss_sigils:int=scene._sigils_balance()
	if not _check(scene.data.get("guardian_quest_state","")=="ready","story quest becomes claimable"):return
	if not _check(int(scene.data["inventory"].get("Guardian Relic",0))==0,"relic waits for quest claim"):return
	scene._enter_world("ruins",Vector2(1900,655))
	scene._enter_world("sanctum",Vector2(175,650))
	if not _check(scene.mobs.is_empty(),"return honors first-victory cooldown"):return
	if not _check(scene._claim_guardian_quest_reward(),"quest can be claimed once"):return
	if not _check(int(scene.data["inventory"].get("Guardian Relic",0))==1,"quest awards unique relic"):return
	if not _check(int(scene.data["inventory"].get("Oldstone Oathblade",0))==1,"class reward delivered"):return
	if not _check(scene._sigils_balance()==first_boss_sigils+30,"quest bonus adds thirty Sigils"):return
	if not _check(not scene._claim_guardian_quest_reward(),"repeat claim denied"):return
	scene._dismiss_message()
	scene.data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()-61.0
	scene._enter_world("ruins",Vector2(1900,655))
	scene._enter_world("sanctum",Vector2(175,650))
	if not _check(scene.mobs.size()==1,"boss returns after sixty second cooldown"):return
	if not _check(scene._save() and scene._load_save() and bool(scene.data["guardian_defeated"]),"boss progress saved"):return
	print("ADVENTURE ODYSSEY WORLD EXPANSION TEST: PASS")
	quit(0)
