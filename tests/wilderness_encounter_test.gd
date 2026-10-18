extends SceneTree
var checks := 0
var failures := 0
const Encounter = preload("res://src/wilderness_encounter.gd")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var e = Encounter.new()
	var clear := func(_p: Vector2): return true
	check(e.enemies.size() == 3 and e.hp == 100,"Three enemies and full trial health")
	var home: Vector2 = e.enemies[0].home
	for i in 15: e.tick(0.05,home+Vector2(30,0),clear)
	check(e.hp == 86,"Windup commits one hit")
	for i in 50: e.tick(0.05,home+Vector2(500,0),clear)
	check(e.enemies[0].mode == "idle" and e.enemies[0].position == home,"Leash returns and heals")
	e.reset()
	e.tick(0.05,home+Vector2(30,0),clear)
	check(e.enemies[0].mode == "windup","Readable windup")
	for i in 15: e.tick(0.05,home+Vector2(100,0),clear)
	check(e.hp == 100,"Stepping out avoids locked strike")
	e.reset()
	check(not e.attack(home+Vector2(400,0),clear),"Out of range rejects attack")
	var wall := func(p: Vector2): return p.x < home.x+12 or p.x > home.x+18
	check(not e.attack(home+Vector2(30,0),wall),"Attack cannot cross wall")
	check(e.attack(home+Vector2(30,0),clear),"Basic attack hits")
	check(not e.attack(home+Vector2(30,0),clear) and e.enemies[0].hp == 24,"Spam obeys cooldown")
	for enemy in e.enemies:
		while enemy.hp > 0:
			e.attack_cooldown = 0
			e.attack(enemy.position,clear)
	check(e.victory and e.living_count() == 0,"All three required for victory")
	check(not e.attack(home,clear),"No repeated victory attack")
	e.reset()
	for i in 400: e.tick(0.05,home+Vector2(30,0),clear)
	check(e.defeated and e.hp == 0,"Defeat stops at zero")
	e.reset()
	check(not e.defeated and not e.victory and e.living_count() == 3 and e.hp == 100,"Retry restores full encounter")
	var world = preload("res://src/starter_world.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.username = "WildernessQA"
	world.state.path = "user://wilderness_test_%d.json" % Time.get_ticks_usec()
	check(world.state.create(draft.payload()),"Create test character")
	root.add_child(world)
	world.set_process(false)
	await process_frame
	for p in Encounter.SPAWNS+[Encounter.RETRY_POINT]: check(world.can_stand(p),"Encounter point clear: "+str(p))
	# Actual swept travel from the existing south branch to retry and each spawn.
	for destination in Encounter.SPAWNS:
		world.player = Vector2(880,1990)
		for waypoint in [Encounter.RETRY_POINT,destination]:
			for step in 200:
				if world.player.distance_to(waypoint) < 2: break
				world.move_player((waypoint-world.player).limit_length(7.75))
			check(world.player.distance_to(waypoint) < 2,"Swept meadow access to "+str(waypoint))
	check(world.wilderness_nodes.size() == 14,"Fourteen approved wilderness accents")
	for rect in world.wilderness_footprints: check(not world.can_stand(rect.get_center()),"New solid footprint")
	for enemy in world.enemy_nodes: check(not enemy.visible,"No ambush before guild assignment")
	check(world.state.transfer("warrior_01_weapon",false),"Collect starter for valid assignment")
	var helper = preload("res://tests/tutorial_save_test.gd").new()
	for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]:
		helper.take_step(world.state,action)
	world.state.set_location("starter_region",Vector2(1000,2020))
	helper.free()
	world._process_encounter(0)
	for enemy in world.enemy_nodes: check(enemy.visible,"Assigned encounter spawns")
	# Exercise actual terrain collision throughout a pursuit, then leash home.
	for i in 200:
		world.encounter.tick(0.05,Vector2(1120,2260),world.can_stand)
		for enemy in world.encounter.enemies: check(world.can_stand(enemy.position),"Slime remains on walkable ground")
	world.encounter.reset()
	world.encounter.hp = 0
	world.encounter.defeated = true
	world._process_encounter(0.05)
	check(is_instance_valid(world.overlay),"Defeat presents retry")
	world.cancel_overlay()
	check(world.encounter.hp == 100 and world.player == Encounter.RETRY_POINT,"Back retries safely")
	world.hud.attack_button.set_meta("combat_touch",2)
	world._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not world.hud.attack_button.has_meta("combat_touch"),"Focus loss cancels held attack")
	world.hud.attack_button.set_meta("combat_touch",2)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 2
	canceled.pressed = false
	canceled.canceled = true
	world._input(canceled)
	check(not world.hud.attack_button.has_meta("combat_touch"),"Canceled secondary touch clears attack owner")
	world.encounter.reset()
	world.player = Encounter.SPAWNS[0]+Vector2(40,0)
	world.open_menu()
	var paused_hp: int = world.encounter.hp
	for i in 100: world._process_encounter(0.05)
	check(world.encounter.hp == paused_hp and world.encounter.enemies[0].mode == "idle","Modal pauses AI and damage")
	world.attack_nearby()
	check(world.encounter.enemies[0].hp == 36,"Modal prevents attacks")
	world.cancel_overlay()
	world.queue_free()
	await process_frame
	print("Wilderness encounter: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
