extends SceneTree
# Exercise existing wildlife/guardian AI; no new enemies, stats or art.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,reason:String)->bool:
	if not ok:
		push_error("EXTENDED ENEMY AI TEST FAILED: "+reason)
		quit(1)
		return false
	return true

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene.data["guild_training_completed"]=true
	scene.data["level"]=3
	scene._enter_world("forest",Vector2(420,650))
	await process_frame
	scene.set_process(false)
	if not _check(scene.mobs.size()==7,"four slimes plus existing wildlife trio"):return
	for i in range(4,7):
		for other in scene.mobs:
			other["alive"]=false
		var mob:Dictionary=scene.mobs[i]
		mob["alive"]=true
		var species:String=str(mob["species"])
		if not _check(species in ["wolf","goblin","fungus"],"forest creature identity"):return
		mob["node"].position=mob["home"]
		mob["state"]="wander"
		mob["attack_cd"]=0.0
		scene.player.position=mob["home"]+Vector2(215,0)
		scene._tick_slime_ai(0.1)
		if not _check(mob["state"]=="pursue",species+" pursues nearby adventurer"):return
		scene.player.position=mob["node"].position+Vector2(75,0)
		var hp_before:int=int(scene.data["hp"])
		scene._tick_slime_ai(0.1)
		if not _check(mob["state"]=="windup" and int(scene.data["hp"])==hp_before,species+" warns before damage"):return
		for n in range(7):scene._tick_slime_ai(0.1)
		if not _check(mob["state"]=="pursue" and float(mob["attack_cd"])>1.0,species+" resolves attack with cooldown"):return
		mob["hp"]=10
		mob["retreat_cd"]=0.0
		scene.player.position=mob["node"].position+Vector2(75,0)
		scene._tick_slime_ai(0.1)
		if not _check(mob["state"]=="retreat",species+" retreats at low HP"):return
		mob["state"]="pursue"
		mob["hp"]=int(mob["max_hp"])
		mob["node"].position=mob["home"]+Vector2(190,0)
		scene.player.position=Vector2(80,180)
		scene._tick_slime_ai(0.1)
		if not _check(mob["state"]=="return",species+" stops chasing past leash"):return
		mob["alive"]=false
		var fallen_pos:Vector2=mob["node"].position
		scene._tick_slime_ai(0.1)
		if not _check(mob["node"].position==fallen_pos,species+" stays defeated"):return
	scene._enter_world("sanctum",Vector2(175,650))
	if not _check(scene.mobs.size()==1,"existing sanctum guardian spawned"):return
	var boss:Dictionary=scene.mobs[0]
	boss["hp"]=140
	boss["attack_cd"]=0.0
	scene.player.position=boss["node"].position+Vector2(210,0)
	scene._tick_slime_ai(0.1)
	if not _check(bool(boss.get("phase_two",false)) and int(boss["attack_damage"])==16,"guardian enrages at half HP"):return
	scene.player.position=boss["node"].position+Vector2(130,0)
	scene._tick_slime_ai(0.1)
	if not _check(boss["state"]=="windup" and float(boss["windup"])>1.0,"guardian telegraphs large-range attack"):return
	scene._enter_world("town",Vector2(1030,980))
	if not _check(scene.mobs.is_empty(),"map transition clears enemies"):return
	print("ADVENTURE ODYSSEY EXTENDED ENEMY AI TEST: PASS / wolf goblin fungus and guardian")
	quit(0)
