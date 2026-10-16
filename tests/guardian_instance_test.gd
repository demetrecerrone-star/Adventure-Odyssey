extends SceneTree
var failures:int=0
func _initialize()->void:call_deferred("_run")
func _check(ok:bool,label:String)->void:
	if not ok:
		failures+=1
		push_error("GUARDIAN INSTANCE TEST FAILED: "+label)
func _enter(game,room:String)->void:
	game._enter_world(room,Vector2(175,650))
	game._dismiss_message()
func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game.set_process(false)
	game._random_default()
	game.data["guild_training_completed"]=true
	game.data["level"]=3
	_enter(game,"sanctum")
	_check(game.mobs.size()==1 and game.mobs[0]["guardian_encounter"]=="story","first visit is story")
	game._spawn_sanctum_guardian()
	_check(game.mobs.size()==1,"duplicate spawn call cannot add another boss")
	# Leaving unfinished or fainting must not consume the story encounter.
	_enter(game,"chapel")
	_enter(game,"sanctum")
	_check(game.mobs[0]["guardian_encounter"]=="story","unfinished revisit is story")
	game.data["hp"]=1
	var boss:Dictionary=game.mobs[0]
	boss["node"].position=Vector2(225,650)
	boss["state"]="windup"
	boss["windup"]=0.01
	var hit_seed:int=0
	seed(hit_seed)
	while randf()<0.35:
		hit_seed+=1
		seed(hit_seed)
	seed(hit_seed)
	game._tick_slime_ai(0.1)
	_check(game.current_map=="town" and not bool(game.data.get("guardian_defeated",false)),"player faint keeps story incomplete")
	_enter(game,"sanctum")
	_check(game.mobs[0]["guardian_encounter"]=="story","story retries after faint")
	_check(game._save() and game._load_save(),"unfinished story reload")
	_enter(game,"sanctum")
	_check(game.mobs[0]["guardian_encounter"]=="story","reload before victory retries story")
	boss=game.mobs[0]
	game._apply_slime_damage(boss,999,true)
	_check(game.data.get("guardian_quest_state","")=="ready","first victory makes unique reward claimable")
	var gold:int=int(game.data["gold"])
	var xp:int=int(game.data["xp"])
	var sigils:int=game._sigils_balance()
	game._apply_slime_damage(boss,999,true)
	_check(int(game.data["gold"])==gold and int(game.data["xp"])==xp and game._sigils_balance()==sigils,"duplicate death gives no reward")
	game.data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()-61.0
	game._tick_guardian_respawn()
	_check(game.mobs.size()==1 and not game.mobs[0]["alive"],"completed story instance stays cleared after cooldown")
	_check(game._save() and game._load_save(),"cleared story save reload")
	_enter(game,"sanctum")
	_check(game.mobs.is_empty(),"reloading cleared story room does not replace it with regular encounter")
	_enter(game,"chapel")
	game.data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()
	_enter(game,"sanctum")
	_check(game.mobs.is_empty(),"return still honors existing 60-second cooldown")
	game.data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()-61.0
	game._tick_guardian_respawn()
	_check(game.mobs.size()==1 and game.mobs[0]["guardian_encounter"]=="regular","normal encounter unlocks without claiming Guild reward")
	boss=game.mobs[0]
	gold=int(game.data["gold"])
	game._apply_slime_damage(boss,999,true)
	_check(int(game.data["gold"])-gold in range(73,82),"regular victory has ordinary gold without first-clear 100 bonus")
	_check(game.data["guardian_quest_state"]=="ready","regular victory preserves unclaimed story reward")
	_check(not bool(game.data.get("guardian_story_exit_pending",false)),"regular victory never reopens story instance")
	game.data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()-61.0
	game._tick_guardian_respawn()
	_check(game.mobs.size()==2 and game.mobs.back()["alive"],"regular encounter repeats on original cooldown")
	_check(game._claim_guardian_quest_reward(),"delayed unique claim succeeds")
	var weapon:String=game._guardian_reward_weapon()
	_check(int(game.data["inventory"][weapon])==1,"one heirloom awarded")
	_check(game._save() and game._load_save(),"claimed progress reload")
	sigils=game._sigils_balance()
	_check(not game._claim_guardian_quest_reward() and game._sigils_balance()==sigils and int(game.data["inventory"][weapon])==1,"claim stays unique across reload")
	# Old pre-quest saves retain their relic and can return immediately without
	# a nonexistent timestamp continually restarting their cooldown.
	var old:Dictionary=game._default_character()
	old["guardian_defeated"]=true
	old["inventory"]["Guardian Relic"]=1
	game.data=game._normalized_save(old)
	_check(game.data["guardian_quest_state"]=="ready","old first-clear save migrates to unclaimed reward")
	_enter(game,"sanctum")
	_check(game.mobs.size()==1 and game.mobs[0]["guardian_encounter"]=="regular","old cleared save enters regular encounter without timestamp")
	_check(game._claim_guardian_quest_reward() and int(game.data["inventory"]["Guardian Relic"])==1,"old relic not duplicated by new claim")
	_check(game._guardian_respawn_ready(),"claim does not restart cooldown")
	old=game._default_character()
	old["guardian_quest_state"]="claimed"
	game.data=game._normalized_save(old)
	_enter(game,"sanctum")
	_check(game.mobs[0]["guardian_encounter"]=="regular" and not game._claim_guardian_quest_reward(),"legacy claimed marker prevents story replay even without defeated flag")
	if failures==0:print("ADVENTURE ODYSSEY GUARDIAN INSTANCE TEST: PASS")
	quit(1 if failures else 0)
