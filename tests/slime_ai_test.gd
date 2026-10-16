extends SceneTree
# Deterministic AI state tests, forest collision, telegraph and return behavior.
func _initialize()->void:
	call_deferred("_run")
func _check(ok:bool,why:String)->bool:
	if not ok:
		push_error("SLIME AI TEST FAILED: "+why)
		quit(1)
		return false
	return true
func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("forest",Vector2(120,655))
	await process_frame
	scene._dismiss_message()
	if not _check(scene.mobs.size()==4,"four original slimes"):return
	var slime=scene.mobs[0]
	var home:Vector2=slime["home"]
	if not _check(slime["state"]=="wander" and slime["node"].position==home,"slimes spawn wandering at home"):return
	# Force a walk direction toward a passable opening; no teleporting.
	slime["roam_dir"]=Vector2.RIGHT
	slime["roam_timer"]=2.0
	scene.player.position=Vector2(125,655)
	scene._tick_slime_ai(0.1)
	if not _check(slime["node"].position.x>home.x,"unalerted slime wanders"):return
	if not _check(scene._walkable(slime["node"].position),"wandering respects painted forest collision"):return
	# A player inside detection range triggers pursuit with real movement.
	scene.player.position=home+Vector2(220,0)
	var old_x:float=slime["node"].position.x
	scene._tick_slime_ai(0.1)
	if not _check(slime["state"]=="pursue" and slime["node"].position.x>old_x,"slime chases nearby player"):return
	# Attacks must wind up, not hit immediately. Dodge is stat-driven.
	scene.player.position=slime["node"].position+Vector2(68,0)
	slime["attack_cd"]=0.0
	var hp_before:int=int(scene.data["hp"])
	scene._tick_slime_ai(0.1)
	if not _check(slime["state"]=="windup" and int(scene.data["hp"])==hp_before,"slime telegraphs before attacking"):return
	scene._update_slime_targeting()
	if not _check(slime["indicator"].attack_warning,"attack warning ring follows windup"):return
	for i in range(6):scene._tick_slime_ai(0.1)
	if not _check(slime["state"]=="pursue" and slime["attack_cd"]>1.5,"windup resolves into attack with per-slime cooldown"):return
	if not _check(int(scene.data["hp"])<=hp_before and int(scene.data["hp"])>=hp_before-5,"attacks retain HP damage/dodge"):return
	# Low health makes slimes back off; defeat still works.
	scene.player.position=slime["node"].position+Vector2(70,0)
	slime["hp"]=10
	slime["indicator"].call("update_health",10,35)
	slime["retreat_cd"]=0.0
	scene._tick_slime_ai(0.1)
	if not _check(slime["state"]=="retreat","wounded slime retreats"):return
	var d:float=slime["node"].position.distance_to(scene.player.position)
	scene._tick_slime_ai(0.1)
	if not _check(slime["node"].position.distance_to(scene.player.position)>=d,"retreat moves away from player"):return
	# Lost player makes slime return toward home without clipping.
	scene.player.position=Vector2(120,655)
	slime["node"].position=home+Vector2(0,335)
	slime["state"]="pursue"
	scene._tick_slime_ai(0.1)
	if not _check(slime["state"]=="return","leash breaks pursuit"):return
	var h:float=slime["node"].position.distance_to(home)
	scene._tick_slime_ai(0.1)
	if not _check(slime["node"].position.distance_to(home)<h,"return walks toward home"):return
	# A slain creature never resumes AI.
	slime["alive"]=false
	var dead_pos:Vector2=slime["node"].position
	scene._tick_slime_ai(0.15)
	if not _check(slime["node"].position==dead_pos,"dead slime never moves"):return
	scene._enter_world("town",Vector2(1030,980))
	if not _check(scene.mobs.is_empty(),"town cleanup removes AI mobs"):return
	print("ADVENTURE ODYSSEY SLIME AI TEST: PASS")
	quit(0)
