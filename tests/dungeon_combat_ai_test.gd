extends SceneTree
# Regressions for shared AI after the original forest expanded into Oldstone.
var failures:int=0

func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,detail:String)->void:
	if not ok:
		failures+=1
		push_error("DUNGEON COMBAT AI TEST FAILED: "+detail)

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game.set_process(false)
	game._random_default()
	game.data["guild_training_completed"]=true
	game.data["level"]=3
	# A blocked hit still completes the attack cycle. Protect HP so the test
	# can exercise every live enemy in the same tick without random dodges.
	for room in ["forest","ruins","halls","library","chapel","sanctum"]:
		game._enter_world(room,Vector2(900,650))
		game._dismiss_message()
		game.barrier_charges=100
		game.barrier_timer=100.0
		var count:int=game.mobs.size()
		for mob in game.mobs:
			mob["node"].position=Vector2(975,650)
			mob["home"]=mob["node"].position
			mob["state"]="windup"
			mob["windup"]=0.01
			mob["attack_cd"]=0.0
		game._tick_slime_ai(0.1)
		_check(game.barrier_charges==100-count,room+": all due attacks resolve in one tick")
		for mob in game.mobs:
			var cooldown:float=3.5 if mob["species"]=="guardian" else 2.25
			_check(mob["state"]=="pursue" and is_equal_approx(float(mob["attack_cd"]),cooldown),room+": "+str(mob["species"])+" receives full cooldown")
		for i in range(10):game._tick_slime_ai(0.1)
		_check(game.barrier_charges==100-count,room+": no extra attacks during cooldown")

	# The Guardian begins its windup at <165 units and can hit up to 175.
	# Both positions must survive the old ordinary-enemy 133-unit cutoff.
	for distance in [150.0,175.0,176.0]:
		game._enter_world("sanctum",Vector2(175,650))
		game.barrier_charges=2
		game.barrier_timer=100.0
		var boss:Dictionary=game.mobs[0]
		boss["attack_cd"]=0.0
		game.player.position=boss["node"].position+Vector2(150,0)
		game._tick_slime_ai(0.1)
		_check(boss["state"]=="windup","Guardian starts a telegraphed attack at 150 units")
		game.player.position=boss["node"].position+Vector2(distance,0)
		for i in range(12):game._tick_slime_ai(0.1)
		if distance<=175.0:
			_check(game.barrier_charges==1 and float(boss["attack_cd"])>3.0,"Guardian completes one attack at "+str(distance)+" units")
		else:
			_check(game.barrier_charges==2,"stepping beyond Guardian reach avoids the attack")

	# A lethal hit replaces the world. Never tick the remaining old enemies.
	game._enter_world("halls",Vector2(900,650))
	var old_mobs:Array=game.mobs.duplicate()
	for mob in old_mobs:
		mob["node"].position=Vector2(975,650)
		mob["state"]="windup"
		mob["windup"]=0.01
		mob["attack_cd"]=0.0
	game.data["hp"]=1
	# Choose a reproducible first roll outside the capped 35% dodge chance.
	var hit_seed:int=0
	seed(hit_seed)
	while randf()<0.35:
		hit_seed+=1
		seed(hit_seed)
	seed(hit_seed)
	game._tick_slime_ai(0.1)
	_check(game.current_map=="town" and game.mobs.is_empty(),"fainting returns to town and clears dungeon enemies")
	_check(is_equal_approx(float(old_mobs[1]["windup"]),0.01),"no old-room enemy ticks after fainting")
	if failures==0:
		print("ADVENTURE ODYSSEY DUNGEON COMBAT AI TEST: PASS / six maps, cooldowns, Guardian reach, faint cleanup")
	quit(0 if failures==0 else 1)
