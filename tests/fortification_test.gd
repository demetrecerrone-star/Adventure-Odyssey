extends SceneTree
var checks := 0
var failures := 0
func check(ok:bool, note:String)->void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func point(value:Array)->Vector2: return Vector2(value[0],value[1])
func _initialize()->void: call_deferred("run")
func run()->void:
	root.size = Vector2i(1280,720)
	var world = preload("res://src/starter_world.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.username = "WallQA"
	world.state.path = "user://fortification_qa_%s.json" % Time.get_ticks_usec()
	check(world.state.create(draft.payload()),"Create isolated character")
	root.add_child(world)
	world.set_process(false)
	await process_frame
	var data:Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/fortifications.json"))
	check(data.get("missing",[]).is_empty(),"No missing wall modules")
	check(world.fortification_nodes.size() == data.placements.size() and world.fortification_nodes.size() > 40,"Complete measured fortification loaded")
	for item in world.fortification_data:
		var sprite:Sprite2D = world.fortification_nodes[item.id]
		check(sprite.texture != null and sprite.z_index < 2000,"Loaded wall below HUD: "+item.id)
		var center := Vector2.ZERO
		for vertex in item.collision_polygon: center += point(vertex)
		center /= item.collision_polygon.size()
		check(not world.can_stand(center),"Measured footing blocks feet: "+item.id)
		world.player = Vector2(center.x,world.building_front_y(item,center.x)-20)
		world._update_actor()
		check(sprite.z_index > world.actor.z_index and sprite.self_modulate.a < 0.5,"Occluding module fades behind player: "+item.id)
		world.player = Vector2(center.x,world.building_front_y(item,center.x)+30)
		world._update_actor()
		check(sprite.z_index < world.actor.z_index and is_equal_approx(sprite.self_modulate.a,1.0),"Front depth and opacity restore: "+item.id)
	world.player = Vector2(3495,1840)
	world._update_actor()
	for id in ["south_west_00_00","gate_workyard_south_post_0"]:
		check(is_equal_approx(world.fortification_nodes[id].self_modulate.a,1.0),"Transparent source padding beside south gate does not fade " + id)
	world.player = Vector2(2502.0,1519.8)
	world._update_actor()
	var visible_relief := 0
	for node in world.fortification_nodes.values():
		if node.self_modulate.a < 0.5:visible_relief += 1
	check(visible_relief > 0,"Genuine opaque wall overlap at general store still reveals player")
	var gates:Array = data.get("gates",[])
	check(gates.size() == 4,"Four open gates")
	for gate in gates:
		var points := [point(gate.outside_point),point(gate.center),point(gate.inside_point)]
		if gate.has("traversal_points"):
			points = []
			for vertex in gate.traversal_points: points.append(point(vertex))
		check(world.can_stand(point(gate.center)),"Gate center clear: "+gate.id)
		for reverse in [false,true]:
			if reverse: points.reverse()
			world.player = points[0]
			check(world.can_stand(world.player),"Gate starting point clear: "+gate.id)
			for destination in points.slice(1):
				var distance:float = world.player.distance_to(destination)
				for step in range(int(ceil(distance/4.0))): world.move_player((destination-world.player).limit_length(4.0))
				check(world.player.distance_to(destination) < 0.1,"Gate swept traversal: "+gate.id)
	var ring := PackedVector2Array()
	for vertex in data.get("perimeter_polygon",[]): ring.append(point(vertex))
	check(ring.size() >= 4,"Closed perimeter geometry supplied")
	if ring.size() >= 4:
		for item in world.building_data:
			var expected:bool = item.id != "starter_home"
			check(world._contains_point(point(item.position),ring) == expected,"Town membership: "+item.id)
	world.player = world.HOME
	world._update_actor()
	check(world.can_stand(world.player),"Home outside ring stays usable")
	world.queue_free()
	await process_frame
	print("Fortification checks: %d failures: %d" % [checks,failures])
	quit(1 if failures else 0)
