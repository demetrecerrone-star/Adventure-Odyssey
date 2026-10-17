extends SceneTree
func _initialize()->void: call_deferred("run")
func snap(path:String)->void:
	for tick in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+path)==OK)
func run()->void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var world = preload("res://src/starter_world.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.set_base("female")
	draft.character_class = "Ranger"
	draft.username = "WorldPreview"
	draft.skin = "blue"
	world.state.path = "user://world_capture.json"
	DirAccess.remove_absolute(world.state.path)
	assert(world.state.create(draft.payload()))
	assert(world.state.transfer("ranger_01_weapon",false) and world.state.equip("ranger_01_weapon"))
	assert(world.state.set_location("starter_region",world.HOME))
	root.add_child(world)
	world.set_process(false)
	for view in [{"id":"home","p":[1644,1333]},{"id":"guild","p":[2424,1128]},{"id":"forest","p":[445,750]},{"id":"meadow","p":[690,2150]},{"id":"foothill","p":[4025,1150]}]:
		world.player = Vector2(view.p[0],view.p[1])
		assert(world.can_stand(world.player))
		world._update_actor()
		world.actor.advance(0,false,0)
		await snap("world_"+view.id+".png")
	for item in world.building_data:
		world.player = Vector2(item.door_approach[0],item.door_approach[1])
		assert(world.can_stand(world.player))
		world._update_actor()
		await snap("world_door_"+item.id+".png")
	for item in world.building_data:
		if item.id not in ["starter_home","guild"]: continue
		var top:float = INF
		for v in item.collision_polygon: top = minf(top,v[1])
		world.player = Vector2(item.position[0],top-32)
		assert(world.can_stand(world.player))
		world._update_actor()
		await snap("world_behind_"+item.id+".png")
	world.player = Vector2(247,1220)
	assert(world.can_stand(world.player) and not world.can_stand(Vector2(247,1148)))
	world._update_actor()
	await snap("world_corrected_forest_ledge.png")
	world.player = Vector2(2850,1268)
	world.touch_direction = Vector2.RIGHT
	for frame in range(72):
		world._process(1.0/36.0)
		await snap("world_motion_%02d.png" % frame)
	world._reset_movement()
	var first_prop:Rect2 = world.prop_rects.values()[0]
	for side in [{"id":"behind","offset":Vector2(-48,-10)},{"id":"front","offset":Vector2(0,120)}]:
		world.player = first_prop.get_center()+side.offset
		assert(world.can_stand(world.player))
		world._update_actor()
		await snap("world_tree_"+side.id+".png")
	world.open_chest(false)
	await snap("world_inventory.png")
	world.cancel_overlay()
	world.player = world.HOME
	world.interact()
	assert(world.state.location.scene == "bedroom")
	var room = preload("res://src/bedroom.gd").new()
	room.state = world.state
	world.hide()
	root.add_child(room)
	room.set_process(false)
	room.player = Vector2(780,440)
	room._update_actor()
	await snap("world_return_bedroom.png")
	room.queue_free()
	await process_frame
	world.show()
	root.size = Vector2i(2304,1536)
	world.camera_zoom = 0.5
	world.player = world.HOME
	world._update_actor()
	world.message.text = "Full-region exterior checkpoint • interiors and quests pending"
	await snap("world_overview.png")
	world.queue_free()
	await process_frame
	print("Starter world native captures complete")
	quit()
