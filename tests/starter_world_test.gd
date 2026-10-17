extends SceneTree
var checks := 0
var failures := 0
func check(ok:bool, text:String)->void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func _initialize()->void: call_deferred("run")
func run()->void:
	root.size = Vector2i(1280,720)
	var world = preload("res://src/starter_world.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.set_base("female")
	draft.character_class = "Ranger"
	draft.username = "WorldQA"
	world.state.path = "user://world_qa_%s.json" % Time.get_ticks_usec()
	check(world.state.create(draft.payload()),"Create character")
	check(world.state.transfer("ranger_01_weapon",false) and world.state.equip("ranger_01_weapon"),"Equip actual class bow")
	check(world.state.set_location("starter_region",world.HOME),"Persist world entry")
	root.add_child(world)
	world.set_process(false)
	await process_frame
	check(world.actor.artwork_ready and world.actor.hair_renderer.ready and world.actor.palette_ready,"Saved layered appearance in world")
	check(world.actor.equipped_weapon == "ranger_01_weapon","Equipped bow retained")
	check(world.player == world.HOME and world.can_stand(world.HOME),"Home spawn navigable")
	check(world.scenery_nodes.size() == 142 and world.prop_rects.size() == 90,"All approved scenery placements and colliders loaded")
	for id in world.scenery_nodes:
		var sprite:Sprite2D = world.scenery_nodes[id]
		check(sprite.texture != null and maxf(sprite.texture.get_width(),sprite.texture.get_height()) <= 512,"Bounded runtime texture "+id)
		check(sprite.z_index < 2000,"Scenery stays below interface "+id)
	for rect in world.prop_rects.values(): check(not world.can_stand(rect.get_center()),"Prop footprint blocks feet")
	check(world.can_stand(Vector2(2267.28,1299.561)),"No false-positive river vertex snag on home route")
	check(world.chunks.size() > 0 and world.chunks.size() <= 12,"Bounded imported chunk cache")
	for route in world.world_layout.routes:
		for i in range(route.points.size()-1):
			var a := Vector2(route.points[i][0],route.points[i][1])
			var b := Vector2(route.points[i+1][0],route.points[i+1][1])
			for step in range(int(a.distance_to(b)/8.0)+1):
				var center := a.lerp(b,float(step)/maxf(1,int(a.distance_to(b)/8.0)))
				var side := (b-a).normalized().orthogonal() * 20.0
				for offset in [Vector2.ZERO,side,-side]:
					check(world.can_stand(center+offset),"72px route clearance: "+route.id)
	for route in world.world_layout.routes:
		world.player = Vector2(route.points[0][0],route.points[0][1])
		for i in range(1,route.points.size()):
			var destination := Vector2(route.points[i][0],route.points[i][1])
			var distance:float = world.player.distance_to(destination)
			for step in range(int(ceil(distance/7.75))):
				world.move_player((destination-world.player).limit_length(7.75))
			check(world.player.distance_to(destination) < 0.01,"Actual swept movement follows %s target %s got %s delta %.6f" % [route.id,destination,world.player,world.player.distance_to(destination)])
	world.player = Vector2(2000,1370)
	world._update_actor()
	var before:Vector2 = world.player
	world.touch_direction = Vector2.RIGHT
	world._process(0.05)
	check(is_equal_approx(world.player.x-before.x,7.75),"155 px/s full analog")
	before = world.player
	world.touch_direction = Vector2(0.5,0)
	world._process(0.05)
	check(is_equal_approx(world.player.x-before.x,3.875),"Half analog")
	world._reset_movement()
	before = world.player
	world._process(0.05)
	check(world.player == before,"Stop clears held input")
	for p in [Vector2(48,112),Vector2(4560,112),Vector2(48,3024),Vector2(4560,3024)]:
		world.player = p
		world._update_actor()
		check(world.stage.position.x <= 0 and world.stage.position.y <= 0,"Camera has no exposed leading edge")
		check(world.stage.position.x+4608 >= root.size.x and world.stage.position.y+3072 >= root.size.y,"Camera covers trailing edge")
	check(world.chunk_evictions > 0 and world.peak_chunks <= 12,"Chunk cache evicts while crossing world")
	world.player = world.HOME
	world._update_actor()
	var returned := [false]
	world.returned.connect(func():returned[0]=true)
	world.interact()
	check(returned[0] and world.state.location.scene == "bedroom","Home interaction persists bedroom return")
	var loaded = preload("res://src/bedroom_save.gd").new()
	loaded.path = world.state.path
	check(loaded.load_saved() and loaded.location.scene == "bedroom","Return survives reload")
	check(loaded.equipped_weapon == "ranger_01_weapon" and loaded.chest.healing_potion == 5,"No equipment or potion duplication")
	world.touch_direction = Vector2.RIGHT
	world._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(world.touch_direction == Vector2.ZERO and not world.moving_to_target,"Focus loss clears world input")
	var prior:Dictionary = world.state.location.duplicate(true)
	world.state.path = "/missing-world-directory/save.json"
	check(not world.state.set_location("starter_region",world.HOME) and world.state.location == prior,"Save failure rolls back location")
	returned[0] = false
	world.interact()
	check(not returned[0] and world.state.location == prior,"Failed home transition stays in current scene")
	check(not world.state.valid_location({"scene":"starter_region","position":[NAN,0]}),"Non-finite location rejected")
	var obstructed = preload("res://src/starter_world.gd").new()
	obstructed.state = loaded
	var obstacle:Rect2 = world.prop_rects.values()[0]
	check(loaded.set_location("starter_region",obstacle.get_center()),"Save fixture at newly obstructed point")
	root.add_child(obstructed)
	obstructed.set_process(false)
	check(obstructed.player == obstructed.HOME,"Resume inside actual scenery falls back to home")
	obstructed.queue_free()
	world.queue_free()
	await process_frame
	var main = preload("res://src/main.gd").new()
	root.add_child(main)
	await process_frame
	var room = preload("res://src/bedroom.gd").new()
	room.state = loaded
	main._install_adventure(room)
	room.player = room.anchors.door
	room._update_actor()
	room.interact()
	check(main.bedroom.get_script() == preload("res://src/starter_world.gd"),"Actual title/bedroom door installs world")
	check(main.bedroom.state == loaded and main.bedroom.actor.equipped_weapon == "ranger_01_weapon","Scene handoff retains same saved character")
	main.bedroom.player = main.bedroom.HOME
	main.bedroom.interact()
	check(not main.bedroom.get_script() == preload("res://src/starter_world.gd") and main.bedroom.player == Vector2(780,440),"World home returns to actual bedroom door")
	check(main.bedroom.can_stand(main.bedroom.player),"Returned bedroom position clear")
	main.queue_free()
	await process_frame
	print("Starter world checks: %d failures: %d" % [checks,failures])
	quit(1 if failures else 0)
