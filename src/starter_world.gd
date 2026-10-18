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
var occlusion_masks := {}
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
	_load_wilderness()
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
	for rect in wilderness_footprints:
		if rect.grow(FOOT_RADIUS).has_point(point): return false
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
	_update_wilderness_depth()
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
				obscures_player = _opaque_over_player(sprite)
		sprite.z_index = depth
		# Foreground fortifications must not hide the controlled character or
		# a nearby shop entrance. Only the overlapping module fades locally.
		sprite.self_modulate.a = 0.38 if obscures_player else 1.0
func _opaque_over_player(sprite:Sprite2D) -> bool:
	# Source canvases include transparent padding. Sample the visible head/torso/
	# legs, rather than fading a nearby object merely because its canvas overlaps.
	# Cache one-bit masks per texture, not full CPU RGBA copies per placement.
	var key := sprite.texture.resource_path
	if not occlusion_masks.has(key):
		var image := sprite.texture.get_image()
		if image.is_compressed(): image.decompress()
		var mask := BitMap.new()
		mask.create_from_image_alpha(image, 0.15)
		occlusion_masks[key] = mask
	var mask:BitMap = occlusion_masks[key]
	var bounds := Rect2i(Vector2i.ZERO,mask.get_size())
	for source_point in [Vector2(128,64),Vector2(128,100),Vector2(110,120),Vector2(146,120),Vector2(128,160),Vector2(128,200),Vector2(76,120),Vector2(180,120),Vector2(88,180),Vector2(168,180),Vector2(92,212),Vector2(164,212)]:
		var world_point:Vector2 = player+(source_point-Vector2(128,232))*actor.scale
		var pixel := Vector2i((world_point-sprite.position)/sprite.scale)
		if bounds.has_point(pixel) and mask.get_bitv(pixel): return true
	return false
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
		var obscures_player := false
		var visual := Rect2(sprite.position,Vector2(item.display_size[0],item.display_size[1]))
		if visual.intersects(actor_rect):
			# A diagonal foundation has different foreground Y at each X. Keep
			# the player in front at every accessible facade, not only the door.
			if player.y >= building_front_y(item,player.x): depth = mini(depth,actor.z_index-2)
			else:
				depth = maxi(depth,actor.z_index+2)
				obscures_player = _opaque_over_player(sprite)
		sprite.z_index = depth
		sprite.self_modulate.a = 0.38 if obscures_player else 1.0
func _process(delta: float) -> void:
	super._process(delta)
	if world_ready and not state.character.is_empty(): _process_encounter(delta)
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

# First bounded wilderness encounter. Quest/save code is the sole reward owner.
const Encounter = preload("res://src/wilderness_encounter.gd")
const Slime = preload("res://src/wilderness_slime.gd")
var encounter = Encounter.new()
var enemy_nodes: Array[Node2D] = []
var encounter_saved := false
var encounter_save_retry := 0.0
var wilderness_nodes: Array[Sprite2D] = []
var wilderness_footprints: Array[Rect2] = []
var combat_fx: Node2D
var defeat_panel: Control

class CombatFX:
	extends Node2D
	var encounter
	var player := Vector2.ZERO
	func _draw() -> void:
		if encounter == null: return
		if encounter.strike_flash > 0:
			var target: Vector2 = encounter.strike_target-player
			draw_arc(player+Vector2(0,-25),65,target.angle()-0.65,target.angle()+0.65,16,Color("fff0bb"),5,true)
		if encounter.hit_flash > 0:
			draw_arc(player,24,0,TAU,24,Color("ff8064"),3,true)

func _load_wilderness() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/wilderness.json"))
	for item in data.placements:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/starter-region/"+item.file)
		sprite.centered = false
		var display := Vector2(item.display_size[0],item.display_size[1])
		sprite.scale = display/sprite.texture.get_size()
		sprite.position = Vector2(item.position[0],item.position[1])-Vector2(item.anchor[0],item.anchor[1])*display
		sprite.z_index = int(item.position[1]*0.4) if item.get("depth_sort",true) else 1
		stage.add_child(sprite)
		wilderness_nodes.append(sprite)
		if item.has("collision"):
			var r: Array = item.collision
			wilderness_footprints.append(Rect2(r[0],r[1],r[2],r[3]))
	for enemy in encounter.enemies:
		var node = Slime.new()
		stage.add_child(node)
		node.sync(enemy)
		node.hide()
		enemy_nodes.append(node)
	combat_fx = CombatFX.new()
	combat_fx.encounter = encounter
	combat_fx.z_index = 1900
	stage.add_child(combat_fx)
	hud.attack_button.pressed.connect(attack_nearby)
	# Same secondary-finger release semantics as the established interaction button.
	hud.attack_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.index > 0:
			if event.pressed and not event.canceled and not hud.attack_button.disabled: hud.attack_button.set_meta("combat_touch",event.index)
			elif hud.attack_button.get_meta("combat_touch",-1) == event.index:
				hud.attack_button.remove_meta("combat_touch")
				if not event.canceled and not hud.attack_button.disabled and Rect2(Vector2.ZERO,hud.attack_button.size).has_point(event.position): attack_nearby()
			hud.attack_button.accept_event()
	)

func _combat_active() -> bool:
	return state.tutorial.get("stage","") == "first_combat_active" and not encounter_saved

func attack_nearby() -> void:
	if not _combat_active() or is_instance_valid(overlay) or encounter.defeated or state.equipped_weapon.is_empty(): return
	if encounter.attack(player,can_stand):
		message.text = "Keep moving. Amber ring means a slime is about to strike."
	elif encounter.attack_cooldown <= 0:
		message.text = "Move closer to a slime to attack. [F] or Attack."
	_sync_encounter_visuals()

func _process_encounter(delta: float) -> void:
	var active := _combat_active()
	var paused := is_instance_valid(overlay) or sleeping
	# Keep the center of the fight clear; contextual Use returns near real targets.
	interact_button.visible = not active or not nearest_prop().is_empty()
	hud.attack_button.disabled = not active or paused or encounter.defeated or state.equipped_weapon.is_empty() or encounter.attack_cooldown > 0
	hud.combat_status.text = "Skills / potions pending" if active else "Guild field assignment"
	hud.attack_button.tooltip_text = "Basic training strike [F] • move within 108 world pixels" if active else "Accept your field assignment at the guild."
	if active:
		hud.set_tutorial_objective("South meadow: %d slimes remaining." % encounter.living_count() if player.distance_to(Encounter.RETRY_POINT) < 700 else "West bridge, then south path to the meadow.")
		hud.hp_label.text = "Trial HP %d / %d" % [encounter.hp,Encounter.MAX_HP]
		if not paused:
			encounter.tick(delta,player,can_stand)
			if encounter.defeated: _show_encounter_defeat()
			elif encounter.victory:
				encounter_save_retry -= delta
				if encounter_save_retry <= 0:
					encounter_save_retry = 2.0
					if state.has_method("record_encounter_victory") and state.record_encounter_victory(Encounter.ID):
						encounter_saved = true
						_refresh_hud()
						message.text = "Meadow cleared! Return to the guild for your reward."
					else: message.text = "Meadow cleared; progress could not save. Keep this area open to retry. " + state.error
	else: hud.hp_label.text = "HP unavailable"
	_sync_encounter_visuals()

func _sync_encounter_visuals() -> void:
	for i in enemy_nodes.size():
		enemy_nodes[i].sync(encounter.enemies[i])
		enemy_nodes[i].visible = _combat_active() and encounter.enemies[i].hp > 0
	if is_instance_valid(combat_fx):
		combat_fx.player = player
		combat_fx.visible = _combat_active()
		combat_fx.queue_redraw()
	actor.modulate = Color(1.0,0.55,0.45) if _combat_active() and encounter.hit_flash > 0 else Color.WHITE

func _show_encounter_defeat() -> void:
	_reset_movement()
	var modal := Control.new()
	modal.z_index = 2100
	overlay = modal
	defeat_panel = modal
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05,0.08,0.06,0.7)
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460,210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("26352e")
	style.border_color = Color("bd9855")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	margin.add_child(content)
	label("You were overwhelmed",content)
	label("No items or gold were lost.\nRetry restores trial HP and all three slimes.",content)
	var retry := button("Retry from the meadow path",content)
	for appearance in ["normal","hover","pressed","focus","disabled"]:
		retry.add_theme_stylebox_override(appearance,preload("res://src/ui/ornate_panel.gd").make_button_style(appearance in ["hover","pressed"]))
	retry.add_theme_color_override("font_color",Color("362c21"))
	retry.pressed.connect(_retry_encounter)
	_sync_modal_input()

func _retry_encounter() -> void:
	encounter.reset()
	player = Encounter.RETRY_POINT
	_close_overlay()
	_update_actor()
	message.text = "Trial restarted. Use Attack [F], then step out of amber strikes."
	_process_encounter(0)

func cancel_overlay() -> void:
	if is_instance_valid(defeat_panel) and overlay == defeat_panel: _retry_encounter()
	else: super.cancel_overlay()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		attack_nearby()
		get_viewport().set_input_as_handled()
	else: super._unhandled_key_input(event)

func _update_wilderness_depth() -> void:
	var actor_rect := Rect2(player-Vector2(128,232)*actor.scale,Vector2(256,256)*actor.scale)
	for sprite in wilderness_nodes + scenery_nodes.values():
		# Reuse cached one-bit alpha masks so trees reveal the controlled actor.
		var visual := Rect2(sprite.position,sprite.texture.get_size()*sprite.scale)
		sprite.self_modulate.a = 0.38 if sprite.z_index > actor.z_index and visual.intersects(actor_rect) and _opaque_over_player(sprite) else 1.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index > 0 and not event.pressed and is_instance_valid(hud):
		var attack: Button = hud.attack_button
		if attack.get_meta("combat_touch",-1) == event.index:
			attack.remove_meta("combat_touch")
			var point: Vector2 = attack.get_global_transform_with_canvas().affine_inverse()*event.position
			if not event.canceled and not attack.disabled and not is_instance_valid(overlay) and Rect2(Vector2.ZERO,attack.size).has_point(point): attack_nearby()
			get_viewport().set_input_as_handled()

func _sync_modal_input() -> void:
	super._sync_modal_input()
	if is_instance_valid(overlay) and is_instance_valid(hud):
		hud.attack_button.disabled = true
		if hud.attack_button.has_meta("combat_touch"): hud.attack_button.remove_meta("combat_touch")

func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_PAUSED] and is_instance_valid(hud):
		if hud.attack_button.has_meta("combat_touch"): hud.attack_button.remove_meta("combat_touch")
