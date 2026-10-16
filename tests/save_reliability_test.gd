extends SceneTree
var failures:int=0
func _initialize()->void:call_deferred("_run")
func _check(value:bool,label:String)->void:
	if not value:
		failures+=1
		push_error("SAVE RELIABILITY: "+label)
func _write(path:String,value:String)->void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()
func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	# Test uses an isolated HOME in CI; preserve any preexisting files anyway.
	var originals:Dictionary={}
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		var path:String=game.SAVE_PATH+suffix
		if FileAccess.file_exists(path):originals[path]=FileAccess.get_file_as_bytes(path)
		DirAccess.remove_absolute(path)
	var legacy:Dictionary={"class":"Mage","body":2,"stats":{"Strength":10,"Agility":11,"Vitality":12,"Intelligence":13,"Wisdom":14}}
	_write(game.SAVE_PATH,JSON.stringify(legacy))
	_check(game._load_save(),"incomplete legacy save normalized")
	_check(game.data["pos"].size()==2 and game.data["map"]=="bedroom","missing location safely placed in bedroom")
	_check(game.data.has("inventory") and game.data["level"]==1,"required older-save defaults")
	game._continue()
	await process_frame
	_check(game.player!=null,"incomplete legacy save can Continue without crash")
	for invalid in [[],{}, {"class":"bad","stats":{},"body":0}]:
		_check(game._normalized_save(invalid).is_empty(),"reject malformed root or identity")
	for key in ["hp","level","body","inventory","stats"]:
		var invalid:Dictionary=game._default_character()
		invalid[key]="broken"
		_check(game._normalized_save(invalid).is_empty(),"reject invalid field "+key)
	var invalid:Dictionary=game._default_character()
	invalid["pos"]=["bad",1]
	_check(game._normalized_save(invalid).is_empty(),"reject nonnumeric coordinates")
	game.data["custom_future_data"]={"keep":true}
	game.data["gold"]=123
	_check(game._save(),"initial checked atomic write")
	game.data["gold"]=456
	_check(game._save(),"second write creates backup")
	_check(game._read_save(game.SAVE_PATH)["gold"]==456,"latest primary saved")
	_check(game._read_save(game.SAVE_PATH+".bak")["gold"]==123,"previous known-good saved")
	DirAccess.remove_absolute(game.SAVE_PATH)
	_check(game._has_save() and game._load_save(),"backup-only save can Continue")
	_check(game._save(),"backup-only recovery restores primary")
	_write(game.SAVE_PATH,"{truncated")
	_check(game._has_save() and game._load_save(),"corrupt primary recovers backup")
	_check(game.data["gold"]==123 and game.data["custom_future_data"]["keep"],"recovered progress and unknown fields preserved")
	_check(game._save(),"recovered character can save")
	_check(game._read_save(game.SAVE_PATH+".bak")["gold"]==123,"corrupt primary never overwrites good backup")
	var before:String=FileAccess.get_file_as_string(game.SAVE_PATH)
	DirAccess.make_dir_absolute(game.SAVE_PATH+".tmp")
	game.data["gold"]=789
	_check(not game._save(),"unwritable temp reports failure")
	_check(FileAccess.get_file_as_string(game.SAVE_PATH)==before,"failed write preserves primary")
	DirAccess.remove_absolute(game.SAVE_PATH+".tmp")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game._read_save(game.SAVE_PATH)["gold"]==789,"application suspend saves active character")
	game.data["level"]=4
	game._refresh_hud()
	_check(game.character_label.text.contains("Lv 4"),"HUD refresh updates level immediately")
	_check(game._combat_target_prompt({"species":"goblin","hp":12,"max_hp":50}).contains("Goblin Scout 12/50"),"target prompt names actual species")
	_check(not game._combat_target_prompt({}).contains("slime"),"empty combat prompt is species neutral")
	game.current_map="forest"
	game.data["quest_kills"]=3
	game.data["guild_training_completed"]=false
	_check(game._tutorial_hint().contains("report"),"unclaimed training reward still directs report")
	game.data["guild_training_completed"]=true
	_check(not game._tutorial_hint().contains("report"),"completed training does not direct duplicate report")
	game._clear_world()
	game._random_default()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game._read_save(game.SAVE_PATH)["gold"]==789,"title/creator focus change cannot overwrite save")
	_write(game.SAVE_PATH,"invalid")
	_write(game.SAVE_PATH+".bak","invalid")
	var live_before:Dictionary=game.data.duplicate(true)
	_check(not game._has_save() and not game._load_save(),"both invalid files rejected")
	_check(game.data==live_before,"failed load leaves live data unchanged")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:DirAccess.remove_absolute(game.SAVE_PATH+suffix)
	for path in originals:
		var file=FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(originals[path])
		file.close()
	game.queue_free()
	await process_frame
	if failures==0:print("ADVENTURE ODYSSEY SAVE RELIABILITY TEST: PASS")
	quit(0 if failures==0 else 1)
