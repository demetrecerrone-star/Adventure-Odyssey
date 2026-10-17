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
	check(world.building_nodes.size() == 8,"Eight exterior placements loaded")
	for item in world.building_data:
		var stand := Vector2(item.door_approach[0],item.door_approach[1])
		check(world.can_stand(stand),"Usable building approach "+item.id)
		world.player = stand
		world._update_actor()
		check(world.building_nodes[item.id].z_index < world.actor.z_index,"Actor renders in front at door "+item.id)
		var rear:Vector2 = Vector2.ZERO
		for v in item.collision_polygon: rear += Vector2(v[0],v[1])
		rear /= item.collision_polygon.size()
		check(not world.can_stand(rear),"Building floor is solid "+item.id)
		var top:float = INF
		for v in item.collision_polygon: top = minf(top,v[1])
		world.player = Vector2(item.position[0],top-32)
		world._update_actor()
		check(world.building_nodes[item.id].z_index > world.actor.z_index,"Actor renders behind building "+item.id)
	world.player = world.HOME
	world._update_actor()
	check(world.can_stand(Vector2(2267.28,1299.561)),"No false-positive river vertex snag on home route")
	check(not world.can_stand(Vector2(247,1148)),"Painted low forest ledge blocks feet")
	check(not world.can_stand(Vector2(66,1109)),"Cliff face forest_low_west_ledge")
	check(world.can_stand(Vector2(66,1069)),"Clear cliff neighbor forest_low_west_ledge")
	check(not world.can_stand(Vector2(151,497)),"Cliff face forest_west_short_face")
	check(world.can_stand(Vector2(171,467)),"Clear cliff neighbor forest_west_short_face")
	check(not world.can_stand(Vector2(1408,465)),"Cliff face forest_upper_long_face")
	check(world.can_stand(Vector2(1378,505)),"Clear cliff neighbor forest_upper_long_face")
	check(not world.can_stand(Vector2(857,863)),"Cliff face forest_lower_long_face")
	check(world.can_stand(Vector2(827,903)),"Clear cliff neighbor forest_lower_long_face")
	check(not world.can_stand(Vector2(1287,764)),"Cliff face forest_middle_face_extension")
	check(world.can_stand(Vector2(1307,714)),"Clear cliff neighbor forest_middle_face_extension")
	check(not world.can_stand(Vector2(3008,345)),"Cliff face foothill_southwest_terrace_face")
	check(world.can_stand(Vector2(2950,470)),"Clear cliff neighbor foothill_southwest_terrace_face")
	check(not world.can_stand(Vector2(3223,117)),"Cliff face foothill_upper_terrace_face")
	check(world.can_stand(Vector2(3193,157)),"Clear cliff neighbor foothill_upper_terrace_face")
	check(not world.can_stand(Vector2(4324,358)),"Cliff face foothill_east_road_shelf")
	check(world.can_stand(Vector2(4284,388)),"Clear cliff neighbor foothill_east_road_shelf")
	check(not world.can_stand(Vector2(4512,723)),"Cliff face foothill_east_boundary_face")
	check(world.can_stand(Vector2(4492,763)),"Clear cliff neighbor foothill_east_boundary_face")
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
