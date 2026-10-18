extends "res://src/bedroom.gd"
# Playable exterior checkpoint: imported terrain, scenery, buildings and persisted home return.
signal returned
signal interior_requested(scene_id:String)
const Interior = preload("res://src/town_interior.gd")
const WORLD_SIZE := Vector2(4608,3072)
const HOME := Vector2(1644,1333)
const FOOT_RADIUS := 16.0
const ENVELOPE := Vector2(1708,1340)
var envelope_node: Sprite2D
var world_layout: Dictionary = {}
var blocked: Array[PackedVector2Array] = []
var blocked_bounds: Array[Rect2] = []
var chunks := {}
var camera_position := HOME
var camera_zoom := 1.0 # Diagnostic overview only; normal play stays at native 1:1 scale.
var peak_chunks := 0
var chunk_loads := 0
var chunk_evictions := 0
var autosave_elapsed := 0.0
var world_ready := false
var scenery_nodes := {}
var resident_ids := {}
var building_nodes := {}
var building_data: Array = []
var fortification_nodes := {}
var fortification_data: Array = []
var entrance_labels := {"envelope":"Guild letter", "home":"Home", "guild":"Adventurer Guild", "shop_southwest":"General store", "shop_south_plaza":"Apothecary", "blacksmith_workyard":"Blacksmith"}
func _ready() -> void:
	world_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/layout.json"))
	for block in world_layout.blocked_polygons:
		var points := PackedVector2Array()
		for p in block.polygon: points.append(Vector2(p[0],p[1]))
		blocked.append(points)
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point in points: bounds = bounds.expand(point)
		blocked_bounds.append(bounds.grow(FOOT_RADIUS))
	super._ready()
	# Reuse the established inventory, input and modal controls, without room artwork.
	for child in stage.get_children():
		if child != actor: child.free()
	stage.z_index = 0
	actor.scale = Vector2.ONE * (96.0 / 190.0)
	world_ready = true
	_load_scenery()
	_load_buildings()
	_load_fortifications()
	_load_envelope()
	if not can_stand(player): player = HOME
	_update_actor()
	message.text = "Explore the paths. Return home here with [E]. Enter the guild and shops from their doors."
func _load_layout() -> void:
	prop_rects = {}
	anchors = {"home":HOME, "envelope":ENVELOPE}
	wake_spawn = HOME
func _start_character() -> void:
	super._start_character()
	if state.location.scene == "starter_region":
		var p: Array = state.location.position
		var candidate := Vector2(p[0],p[1])
		if can_stand(candidate): player = candidate
	movement_speed = 155.0
func _layout() -> void:
	if not is_instance_valid(stage): return
	stage.scale = Vector2.ONE * camera_zoom
	var half := size / camera_zoom * 0.5
	camera_position = Vector2(clampf(player.x,ceilf(half.x),floorf(WORLD_SIZE.x-half.x)),clampf(player.y,ceilf(half.y),floorf(WORLD_SIZE.y-half.y)))
	stage.position = size * 0.5 - camera_position * camera_zoom
	if is_instance_valid(overlay): overlay.size = size
	if world_ready: update_chunks()
func can_stand(point: Vector2) -> bool:
	if point.x < 48 or point.x > 4560 or point.y < 112 or point.y > 3024: return false
	for index in blocked.size():
		if not blocked_bounds[index].has_point(point): continue
		var polygon := blocked[index]
		if _contains_point(point,polygon): return false
		for i in polygon.size():
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) < FOOT_RADIUS: return false
	for rect in prop_rects.values():
		if rect.grow(FOOT_RADIUS).has_point(point): return false
	return true
func _contains_point(point: Vector2, polygon: PackedVector2Array) -> bool:
	# Half-open horizontal ray avoids rare false-positive ray/vertex hits in the
	# engine helper on the large traced river polygon. Scalar math is float64.
	var inside := false
	var previous := polygon[polygon.size()-1]
	for current in polygon:
		if (float(current.y) > float(point.y)) != (float(previous.y) > float(point.y)):
			var crossing: float = float(current.x) + (float(point.y)-float(current.y)) * (float(previous.x)-float(current.x)) / (float(previous.y)-float(current.y))
			if float(point.x) < crossing: inside = not inside
		previous = current
	return inside
func _update_actor() -> void:
	if not is_instance_valid(actor): return
	super._update_actor()
	actor.z_index = int(player.y * 0.4)
	_update_building_depth()
	_update_fortification_depth()
	_layout()
	if is_instance_valid(status) and not state.character.is_empty():
		status.text = "Local save • Starter region"
func update_chunks() -> void:
	var needed := Rect2(camera_position-size/camera_zoom/2,size/camera_zoom).grow(128)
	for i in world_layout.chunks.size():
		var data: Dictionary = world_layout.chunks[i]
		var r: Array = data.world_rect
		var rect := Rect2(r[0],r[1],r[2],r[3])
		if needed.intersects(rect):
			if not chunks.has(i):
				var sprite := Sprite2D.new()
				sprite.texture = ResourceLoader.load("res://assets/starter-region/"+data.file,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE)
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				sprite.centered = false
				sprite.region_enabled = true
				sprite.region_rect = Rect2(2,2,r[2],r[3])
				sprite.region_filter_clip_enabled = false
				sprite.position = rect.position
				sprite.z_index = 0
				stage.add_child(sprite)
				chunks[i] = sprite
				chunk_loads += 1
		elif chunks.has(i):
			chunks[i].free()
			chunks.erase(i)
			chunk_evictions += 1
	peak_chunks = maxi(peak_chunks,chunks.size())
func _load_scenery() -> void:
	var path := "res://assets/starter-region/scenery.json"
	if not FileAccess.file_exists(path): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for item in data.get("placements",[]):
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/starter-region/"+item.file)
		sprite.centered = false
		var display := Vector2(item.display_size[0],item.display_size[1])
		var anchor := Vector2(item.anchor[0],item.anchor[1])
		sprite.scale = display / sprite.texture.get_size()
		sprite.position = Vector2(item.position[0],item.position[1]) - anchor * display
		sprite.z_index = int(item.position[1] * 0.4) if item.get("depth_sort",true) else 1
		stage.add_child(sprite)
		scenery_nodes[item.id] = sprite
		if item.get("kind", "") == "npc":
			resident_ids[item.id] = true
			anchors[item.id] = Vector2(item.interaction_stand[0],item.interaction_stand[1])
			entrance_labels[item.id] = "Town guard" if item.id.begins_with("guard_") else "Town resident"
		if item.has("collision"):
			var r: Array = item.collision
			prop_rects[item.id] = Rect2(r[0],r[1],r[2],r[3])
func _load_buildings() -> void:
	var path := "res://assets/starter-region/buildings.json"
	if not FileAccess.file_exists(path): return
	var data:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	building_data = data.placements
	for item in building_data:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/starter-region/"+item.file)
		sprite.centered = false
		var display := Vector2(item.display_size[0],item.display_size[1])
		sprite.scale = display / sprite.texture.get_size()
		sprite.position = Vector2(item.position[0],item.position[1])-Vector2(item.anchor[0],item.anchor[1])*display
		sprite.z_index = int(item.depth_anchor_world[1]*0.4)
		stage.add_child(sprite)
		building_nodes[item.id] = sprite
		var key:String = "home" if item.id == "starter_home" else item.id
		anchors[key] = Vector2(item.door_approach[0],item.door_approach[1])
		if not entrance_labels.has(key): entrance_labels[key] = "Town home"
func _load_fortifications() -> void:
	var path := "res://assets/starter-region/fortifications.json"
	if not FileAccess.file_exists(path): return
	var data:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	fortification_data = data.get("placements",[])
	for item in fortification_data:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/starter-region/"+item.file)
		sprite.centered = false
		var display := Vector2(item.display_size[0],item.display_size[1])
		sprite.scale = display / sprite.texture.get_size()
		sprite.position = Vector2(item.position[0],item.position[1])-Vector2(item.anchor[0],item.anchor[1])*display
		sprite.z_index = int(item.depth_anchor_world[1]*0.4)
		stage.add_child(sprite)
		fortification_nodes[item.id] = sprite
		# The same measured ground footprint controls depth and collision.
		var polygon := PackedVector2Array()
		for point in item.collision_polygon: polygon.append(Vector2(point[0],point[1]))
		blocked.append(polygon)
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		blocked_bounds.append(bounds.grow(FOOT_RADIUS))
func _update_fortification_depth() -> void:
	var actor_rect := Rect2(player-Vector2(128,232)*actor.scale,Vector2(256,256)*actor.scale)
	for item in fortification_data:
		var sprite:Sprite2D = fortification_nodes[item.id]
		var depth := int(item.depth_anchor_world[1]*0.4)
		var visual := Rect2(sprite.position,Vector2(item.display_size[0],item.display_size[1]))
		var obscures_player := false
		if visual.intersects(actor_rect):
			if player.y >= building_front_y(item,player.x): depth = mini(depth,actor.z_index-2)
			else:
				depth = maxi(depth,actor.z_index+2)
				obscures_player = true
		sprite.z_index = depth
		# Foreground fortifications must not hide the controlled character or
		# a nearby shop entrance. Only the overlapping module fades locally.
		sprite.self_modulate.a = 0.38 if obscures_player else 1.0
func building_front_y(item:Dictionary, x:float) -> float:
	var crossings:Array[float] = []
	var polygon:Array = item.collision_polygon
	for i in polygon.size():
		var a:Array = polygon[i]
		var b:Array = polygon[(i+1)%polygon.size()]
		if x < minf(a[0],b[0]) or x > maxf(a[0],b[0]): continue
		if is_equal_approx(a[0],b[0]): crossings.append(maxf(a[1],b[1]))
		else: crossings.append(float(a[1])+(x-float(a[0]))*(float(b[1])-float(a[1]))/(float(b[0])-float(a[0])))
	if not crossings.is_empty(): return crossings.max()
	var nearest:Array = polygon[0]
	for vertex in polygon:
		if absf(vertex[0]-x) < absf(nearest[0]-x): nearest = vertex
	return float(nearest[1])
func _update_building_depth() -> void:
	var actor_rect := Rect2(player-Vector2(128,232)*actor.scale,Vector2(256,256)*actor.scale)
	for item in building_data:
		var sprite:Sprite2D = building_nodes[item.id]
		var depth := int(item.depth_anchor_world[1]*0.4)
		var visual := Rect2(sprite.position,Vector2(item.display_size[0],item.display_size[1]))
		if visual.intersects(actor_rect):
			# A diagonal foundation has different foreground Y at each X. Keep
			# the player in front at every accessible facade, not only the door.
			if player.y >= building_front_y(item,player.x): depth = mini(depth,actor.z_index-2)
			else: depth = maxi(depth,actor.z_index+2)
		sprite.z_index = depth
func _process(delta: float) -> void:
	super._process(delta)
	var nearby := nearest_prop()
	if is_instance_valid(interact_button) and not nearby.is_empty(): interact_button.text = entrance_labels.get(nearby,nearby.capitalize())+" [E]"
	if not world_ready or state.character.is_empty() or is_instance_valid(overlay): return
	autosave_elapsed += delta
	if autosave_elapsed >= 10.0:
		autosave_elapsed = 0
		if not state.set_location("starter_region",player): message.text = state.error
func interact() -> void:
	if is_instance_valid(overlay) or sleeping: return
	if resident_ids.has(nearest_prop()):
		open_tutorial_dialogue(nearest_prop())
	elif nearest_prop() == "envelope":
		open_tutorial_dialogue("envelope")
	elif nearest_prop() == "home":
		_reset_movement()
		if state.set_location("bedroom",Vector2(780,440)): returned.emit()
		else: message.text = state.error
	elif not nearest_prop().is_empty():
		for scene_id in Interior.ROOMS:
			if Interior.ROOMS[scene_id].entrance == nearest_prop() and Interior.available(scene_id):
				_reset_movement()
				if state.set_location(scene_id,Interior.entry_point(scene_id)): interior_requested.emit(scene_id)
				else: message.text = state.error
				return
		_reset_movement()
		message.text = entrance_labels.get(nearest_prop(),"This building")+" exterior. Its interior is not available yet."
func _exit() -> void:
	_reset_movement()
	if state.set_location("starter_region",player): exited.emit()
	else: message.text = state.error

func _load_envelope() -> void:
	envelope_node = Sprite2D.new()
	envelope_node.name = "GuildEnvelope"
	envelope_node.texture = load("res://assets/ui/guild-envelope.svg")
	envelope_node.position = ENVELOPE
	envelope_node.scale = Vector2.ONE * 0.7
	envelope_node.z_index = int(ENVELOPE.y * 0.4) - 4
	stage.add_child(envelope_node)

func nearest_prop() -> String:
	var result := ""
	var closest := 135.0
	for id in anchors:
		var radius := 72.0 if resident_ids.has(id) else (90.0 if id == "envelope" else 135.0)
		var distance: float = player.distance_to(anchors[id])
		if distance <= radius and distance < closest:
			closest = distance
			result = id
	return result
