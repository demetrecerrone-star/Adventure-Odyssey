extends SceneTree
const Interior = preload("res://src/town_interior.gd")
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const IDS = ["guild_interior","blacksmith_interior","apothecary_interior","general_store_interior"]
var checks := 0
var failures := 0
func check(ok:bool,message:String)->void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func point(p:Array)->Vector2: return Vector2(p[0],p[1])
func inventory(s)->String: return JSON.stringify([s.character,s.bag,s.chest,s.equipped_weapon,s.equipped_armor])
func clear_segment(room,a:Vector2,b:Vector2)->bool:
	var steps := maxi(1,int(ceil(a.distance_to(b)/4.0)))
	for i in range(steps+1):
		if not room.can_stand(a.lerp(b,float(i)/steps)): return false
	return true
func grid_route(room,start:Vector2,goal:Vector2)->Array[Vector2]:
	var pending:Array[Vector2] = [start]
	var parents := {start:start}
	var head := 0
	while head < pending.size():
		var current := pending[head]; head += 1
		if current.distance_to(goal) <= 24 and clear_segment(room,current,goal):
			var result:Array[Vector2] = [goal,current]
			while current != start:
				current = parents[current]; result.append(current)
			result.reverse(); return result
		for delta in [Vector2(16,0),Vector2(-16,0),Vector2(0,16),Vector2(0,-16)]:
			var next:Vector2 = current + delta
			if not parents.has(next) and clear_segment(room,current,next):
				parents[next] = current; pending.append(next)
	return []
func travel(room,route:Array[Vector2],label:String)->void:
	if route.is_empty(): return
	room.player = route[0]
	for i in range(1,route.size()):
		check(clear_segment(room,route[i-1],route[i]),label + " segment " + str(i))
		room.move_player(route[i]-room.player)
		check(room.player.distance_to(route[i]) < 0.05,label + " swept movement reaches node " + str(i))
func _initialize()->void: call_deferred("run")
func run()->void:
	root.size = Vector2i(1280,720)
	var state = Save.new()
	var path := "user://interior_playability_%s.json" % Time.get_ticks_usec()
	state.path = path
	var draft = Draft.new(); draft.set_base("female"); draft.character_class = "Ranger"; draft.username = "WalkQA"
	check(state.create(draft.payload()),"Create playability fixture")
	check(state.transfer("healing_potion",false),"Fixture potion withdrawn")
	check(state.transfer("ranger_01_weapon",false) and state.equip("ranger_01_weapon"),"Fixture bow equipped")
	var before := inventory(state)
	for id in IDS:
		var layout:Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-interiors/"+id+"/layout.json"))
		var spawn := point(layout.entry_spawn); var exit_point := point(layout.exit_anchor)
		check(state.set_location(id,spawn),id+" fixture saved")
		var room = Interior.new(); room.room_id = id; room.state = state
		root.add_child(room); room.set_process(false)
		for npc in layout.npcs:
			var stand := point(npc.interaction_anchor)
			var outbound := grid_route(room,spawn,stand)
			var inbound := grid_route(room,stand,exit_point)
			check(not outbound.is_empty(),id+" entry to NPC route on 16 px grid")
			check(not inbound.is_empty(),id+" NPC to exit route on 16 px grid")
			travel(room,outbound,id+" outbound")
			travel(room,inbound,id+" inbound")
			var r:Array = npc.collision_rect
			check(not room.can_stand(Rect2(r[0],r[1],r[2],r[3]).get_center()),id+" NPC collision blocks feet")
			room.player = stand; room._update_actor()
			check(room.nearest_prop() == npc.id,id+" NPC stand targets attendant")
			check(state.set_location(id, stand),id+" persist conversation approach before nonmutating dialogue check")
			var disk_before := FileAccess.get_file_as_string(path)
			for repeat in range(3):
				room.joystick.set_position_input(room.joystick.size*0.5+Vector2(60,0))
				room.moving_to_target = true
				room.interact()
				check(is_instance_valid(room.overlay),id+" dialogue opens")
				check(room.touch_direction == Vector2.ZERO and room.joystick.direction == Vector2.ZERO and not room.moving_to_target,id+" dialogue clears joystick and tap target")
				var panel = room.overlay
				room.interact()
				check(room.overlay == panel,id+" repeated interact does not stack dialogue")
				var previous:Vector2 = room.player
				room._process(0.05)
				check(room.player == previous,id+" dialogue prevents motion")
				room._close_overlay()
				check(room.overlay == null and room.touch_direction == Vector2.ZERO,id+" dialogue closes with stopped input")
				check(inventory(state) == before and FileAccess.get_file_as_string(path) == disk_before,id+" dialogue never mutates inventory or save")
			for notification in [Control.NOTIFICATION_APPLICATION_FOCUS_OUT,Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
				room.joystick.set_position_input(room.joystick.size*0.5+Vector2(60,0)); room.moving_to_target = true
				room._notification(notification)
				check(room.touch_direction == Vector2.ZERO and room.joystick.direction == Vector2.ZERO and not room.moving_to_target,id+" focus loss stops joystick and tap target")
		for prop in layout.props:
			if prop.collision_rect == null: continue
			var node:Sprite2D = room.prop_nodes[prop.id]
			room.player = Vector2(prop.position[0],float(prop.depth_y)+20); room._update_actor()
			check(room.actor.z_index > node.z_index,id+" actor in front of furniture below depth line "+prop.id)
			room.player = Vector2(prop.position[0],float(prop.depth_y)-20); room._update_actor()
			check(room.actor.z_index < node.z_index,id+" actor behind furniture above depth line "+prop.id)
		check(inventory(state) == before,id+" playability checks preserve inventory")
		room.free(); await process_frame
	DirAccess.remove_absolute(path)
	print("INTERIOR PLAYABILITY CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
