extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const World = preload("res://src/starter_world.gd")
const Main = preload("res://src/main.gd")
var checks := 0
var failures := 0
func check(ok:bool, message:String)->void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func point(p:Array)->Vector2: return Vector2(p[0],p[1])
func snapshot(s)->Dictionary:
	return JSON.parse_string(JSON.stringify({"character":s.character.duplicate(true),"bag":s.bag.duplicate(true),"chest":s.chest.duplicate(true),"weapon":s.equipped_weapon,"armor":s.equipped_armor}))
func _initialize()->void: call_deferred("run")
func run()->void:
	root.size = Vector2i(1280,720)
	if not ResourceLoader.exists("res://src/town_interior.gd"):
		check(false,"town_interior.gd is required before integration tests can run")
		quit(1); return
	var Interior = load("res://src/town_interior.gd")
	var contract:Dictionary = {"rooms": [{"scene_id": "guild_interior", "exterior_entrance_id": "guild", "return_approach": [2433.3, 1002.45]}, {"scene_id": "blacksmith_interior", "exterior_entrance_id": "blacksmith_workyard", "return_approach": [3681.25, 1737.5]}, {"scene_id": "apothecary_interior", "exterior_entrance_id": "shop_south_plaza", "return_approach": [2990.1, 1684.2]}, {"scene_id": "general_store_interior", "exterior_entrance_id": "shop_southwest", "return_approach": [2502.0, 1519.8]}]}
	var path := "user://routing_regression_%s.json" % Time.get_ticks_usec()
	var state = Save.new()
	state.path = path
	var draft = Draft.new()
	draft.set_base("female"); draft.character_class = "Ranger"; draft.username = "RouteQA"
	check(state.create(draft.payload()),"Create routing fixture")
	check(state.transfer("healing_potion",false),"Take one potion")
	check(state.transfer("ranger_01_weapon",false) and state.equip("ranger_01_weapon"),"Equip bow")
	var inventory := snapshot(state)
	for spec in contract.rooms:
		var id:String = spec.scene_id
		var layout_path := "res://assets/town-interiors/" + id + "/layout.json"
		check(FileAccess.file_exists(layout_path),id + " layout exists")
		if not FileAccess.file_exists(layout_path): continue
		var layout:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		var spawn := point(layout.entry_spawn)
		var exit_point := point(layout.exit_anchor)
		var approach := point(spec.return_approach)
		check(state.set_location("starter_region",approach),id + " set exterior fixture")
		var world = World.new()
		world.state = state
		root.add_child(world); world.set_process(false)
		check(world.has_signal("interior_requested"),"World exposes interior_requested")
		if not world.has_signal("interior_requested"):
			world.free(); continue
		var requested := []
		world.connect("interior_requested",func(scene_id): requested.append({"id":scene_id,"location":state.location.duplicate(true)}))
		check(world.anchors.has(spec.exterior_entrance_id),id + " correct exterior anchor exists")
		check(world.player.distance_to(approach) < 0.01,id + " exterior resume at matching approach")
		check(world.nearest_prop() == spec.exterior_entrance_id,id + " matching entrance is nearest")
		var before:Dictionary = state.location.duplicate(true)
		var bytes := FileAccess.get_file_as_string(path)
		state.path = path + "/missing/save.json"
		world.interact()
		check(requested.is_empty(),id + " failed entry does not emit")
		check(state.location == before and snapshot(state) == inventory,id + " failed entry rolls back all state")
		check(FileAccess.get_file_as_string(path) == bytes,id + " failed entry preserves saved bytes")
		state.path = path
		world.interact()
		check(requested.size() == 1 and requested[0].id == id,id + " entry emits exact scene once")
		check(state.location.scene == id and point(state.location.position).distance_to(spawn) < 0.01,id + " entry persists configured spawn")
		if not requested.is_empty(): check(requested[0].location == state.location,id + " save precedes entry signal")
		check(snapshot(state) == inventory,id + " entry never mutates inventory")
		world.free()
		var reloaded = Save.new(); reloaded.path = path
		check(reloaded.load_saved(),id + " entry survives reload")
		var room = Interior.new(); room.room_id = id; room.state = reloaded
		root.add_child(room); room.set_process(false)
		check(room.player.distance_to(spawn) < 0.01,id + " interior restores spawn")
		check(room.can_stand(room.player) and room.can_stand(exit_point),id + " spawn and exit walkable")
		check(snapshot(reloaded) == inventory,id + " interior start never seeds or changes inventory")
		var emitted := []
		room.world_requested.connect(func():emitted.append(reloaded.location.duplicate(true)))
		room.player = exit_point
		before = reloaded.location.duplicate(true); bytes = FileAccess.get_file_as_string(path)
		reloaded.path = path + "/missing/save.json"
		room.interact()
		check(emitted.is_empty(),id + " failed exit does not signal")
		check(reloaded.location == before and snapshot(reloaded) == inventory,id + " failed exit restores state")
		check(FileAccess.get_file_as_string(path) == bytes,id + " failed exit preserves disk")
		reloaded.path = path
		room.interact()
		check(emitted.size() == 1,id + " successful exit signals once")
		check(reloaded.location.scene == "starter_region" and point(reloaded.location.position).distance_to(approach) < 0.01,id + " exit persists matching exterior")
		if not emitted.is_empty(): check(emitted[0] == reloaded.location,id + " save precedes exit signal")
		check(snapshot(reloaded) == inventory,id + " exit preserves inventory")
		room.free()
		# Router integration tests exercise actual connected signals and shared state.
		var main = Main.new(); root.add_child(main)
		var bedroom = load("res://src/bedroom.gd").new(); bedroom.state = reloaded
		main._install_adventure(bedroom); main._open_world()
		world = main.bedroom; world.set_process(false)
		world.player = approach; world.interact()
		check(main.bedroom.get_script() == Interior,id + " main routes exterior entry into TownInterior")
		if main.bedroom.get_script() == Interior:
			main.bedroom.set_process(false)
			check(main.bedroom.room_id == id and main.bedroom.state == reloaded,id + " router preserves room identity and shared state")
			var title_exit := []
			main.bedroom.exited.connect(func():title_exit.append(true))
			main.bedroom.player = spawn
			var title_before:Dictionary = reloaded.location.duplicate(true)
			var title_bytes := FileAccess.get_file_as_string(path)
			reloaded.path = path + "/missing/save.json"
			main.bedroom._exit()
			check(title_exit.is_empty() and main.bedroom != null,id + " failed Save & title keeps room open")
			check(reloaded.location == title_before and snapshot(reloaded) == inventory,id + " failed Save & title rolls back state")
			check(FileAccess.get_file_as_string(path) == title_bytes,id + " failed Save & title preserves disk")
			reloaded.path = path
			main.bedroom._exit()
			check(title_exit.size() == 1 and main.bedroom == null,id + " Save & title closes adventure")
			check(reloaded.location.scene == id,id + " Save & title retains interior scene")
			# Continue uses the default path in this isolated HOME only.
			var resume = Save.new(); var default_path:String = resume.path
			if FileAccess.file_exists(default_path):
				push_error("Refusing to overwrite an existing guest save; run routing test with isolated XDG_DATA_HOME.")
				quit(1); return
			reloaded.path = default_path; check(reloaded.save(),id + " isolated Continue fixture saved")
			main._open_bedroom()
			await process_frame; await process_frame
			check(main.bedroom != null and main.bedroom.get_script() == Interior,id + " Continue dispatches saved interior")
			if main.bedroom != null and main.bedroom.get_script() == Interior:
				main.bedroom.set_process(false)
				check(main.bedroom.room_id == id and snapshot(main.bedroom.state) == inventory,id + " Continue preserves room and inventory")
				main.bedroom.player = exit_point; main.bedroom.interact()
				check(main.bedroom.get_script() == World,id + " room door routes back to actual world")
				check(main.bedroom.player.distance_to(approach) < 0.01,id + " router returns to correct exterior approach")
			DirAccess.remove_absolute(default_path)
			reloaded.path = path
		main.free()
		await process_frame
		check(snapshot(reloaded) == inventory,id + " complete routing sequence preserves inventory")
	DirAccess.remove_absolute(path)
	print("INTERIOR ROUTING CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
