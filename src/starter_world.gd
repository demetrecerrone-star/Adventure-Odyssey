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
var last_level_up := 0
var combat_stats_revision := -1
var combat_weapon_upgrade := -1
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
		hud.set_wallets(state.wallet_gold,state.wallet_sigils)
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
	if not _checkpoint_combat(): return
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
var combat_data: Dictionary = {}
var combat_checkpoint_elapsed := 0.0
var pending_combat: Dictionary = {}
var pending_combat_retry := 0.0
var combat_touch_buttons: Array[Button] = []
const SupplyPanel = preload("res://src/ui/combat_supply_panel.gd")

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
		if encounter.shield_timer > 0 and encounter.shield_charges > 0:
			draw_arc(player+Vector2(0,-30),48,0,TAU,40,Color("a8d7ff"),4,true)
		if encounter.buff_timer > 0:
			draw_arc(player,30,0,TAU,24,Color("ffbe61"),3,true)
		if encounter.trap_timer > 0:
			draw_arc(encounter.trap_position,80,0,TAU,32,Color("80dfbb"),3,true)
			draw_line(encounter.trap_position-Vector2(15,15),encounter.trap_position+Vector2(15,15),Color("80dfbb"),3,true)
		if encounter.summon_timer > 0:
			var at: Vector2 = encounter.summon_position
			var bone := Color("d5eadb")
			draw_circle(at-Vector2(0,35),10,bone)
			draw_circle(at-Vector2(4,37),2,Color("26352e")); draw_circle(at-Vector2(-4,37),2,Color("26352e"))
			draw_line(at-Vector2(0,25),at-Vector2(0,6),bone,4,true)
			for y in [17,22]: draw_line(at-Vector2(9,y),at-Vector2(-9,y),bone,3,true)
			for side in [-1,1]:
				draw_line(at-Vector2(0,21),at+Vector2(side*16,-13),bone,3,true)
				draw_line(at-Vector2(0,6),at+Vector2(side*11,6),bone,3,true)
		if encounter.skill_flash > 0:
			var color: Color = {"burn":Color("ff975a"),"nova":Color("8edbff"),"poison":Color("98dc73"),"drain":Color("c392e8"),"holy":Color("ffec9b"),"heal":Color("9be4b1")}.get(encounter.skill_kind,Color("c8c4ff"))
			if encounter.skill_kind in ["ranged","burn","drain","holy"]: draw_line(encounter.skill_origin-Vector2(0,25),encounter.strike_target-Vector2(0,15),color,5,true)
			else: draw_arc(encounter.skill_origin,35+(0.6-encounter.skill_flash)*140,0,TAU,40,color,4,true)
		for enemy in encounter.enemies:
			if enemy.hp <= 0: continue
			var at: Vector2 = enemy.position
			if enemy.stun > 0: draw_arc(at-Vector2(0,50),13,0,TAU,16,Color("ffdd7a"),3,true)
			if enemy.slow > 0: draw_arc(at,28,0,TAU,24,Color("91deef"),3,true)
			if enemy.burn > 0 or enemy.poison > 0: draw_circle(at-Vector2(18,35),5,Color("ff9355") if enemy.burn > 0 else Color("99df65"))

func _load_wilderness() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/wilderness.json"))
	var placements: Array = data.placements.duplicate(true)
	if FileAccess.file_exists("res://assets/starter-region/forest_patrol.json"):
		var forest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/forest_patrol.json"))
		placements.append_array(forest.get("placements",[]))
	for item in placements:
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
	combat_data = {}
	if state.tutorial.stage in ["forest_patrol_active","return_guild_forest","forest_patrol_complete"] and FileAccess.file_exists("res://assets/starter-region/forest_patrol.json"):
		combat_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/forest_patrol.json"))
	encounter.configure(combat_data,state.character["class"],state.get_stat_summary(),state.weapon_upgrade_level())
	encounter.apply_resources(state.combat)
	_restore_defeated_spawns()
	for enemy in encounter.enemies:
		var renderer = load(combat_data.get("renderer","res://src/wilderness_slime.gd"))
		var node = renderer.new()
		stage.add_child(node)
		node.sync(enemy)
		node.hide()
		enemy_nodes.append(node)
	combat_fx = CombatFX.new()
	combat_fx.encounter = encounter
	combat_fx.z_index = 1900
	stage.add_child(combat_fx)
	hud.attack_button.pressed.connect(attack_nearby)
	_bind_combat_touch(hud.attack_button,attack_nearby)
	for slot in 3:
		hud.skill_buttons[slot].pressed.connect(use_class_skill.bind(slot))
		_bind_combat_touch(hud.skill_buttons[slot],use_class_skill.bind(slot))
	hud.potion_button.pressed.connect(open_field_supplies)
	_bind_combat_touch(hud.potion_button,open_field_supplies)

func _bind_combat_touch(control: Button, action: Callable) -> void:
	combat_touch_buttons.append(control)
	control.set_meta("combat_action",action)
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.index > 0:
			if event.pressed and not event.canceled and not control.disabled:
				control.set_meta("combat_touch",event.index)
				control.set_meta("combat_start",control.get_global_transform_with_canvas()*event.position)
				control.set_meta("combat_dragged",false)
			control.accept_event()
	)

func _restore_defeated_spawns() -> void:
	for index in encounter.enemies.size():
		if state.enemy_is_defeated(encounter.encounter_id,index):
			encounter.enemies[index].hp = 0
			encounter.enemies[index].mode = "dead"
	encounter.victory = encounter.living_count() == 0

func _save_monster_rewards() -> bool:
	var dead: Array = []
	for index in encounter.enemies.size():
		if encounter.enemies[index].hp <= 0 and not state.enemy_is_defeated(encounter.encounter_id,index): dead.append(index)
	if dead.is_empty(): return true
	var old_level: int = state.stats.level
	if not state.record_enemy_defeats(encounter.encounter_id,dead,encounter.resource_state(int(state.combat.revision))):
		message.text = "Rewards could not save. Combat paused; keep this area open to retry. " + state.error
		return false
	var reward: Dictionary = state.Rewards.ENCOUNTERS[encounter.encounter_id]
	message.text = "+%d gold · +%d XP · +%d Sigils" % [dead.size()*reward.gold,dead.size()*reward.xp,dead.size()*reward.sigils]
	if state.stats.level > old_level:
		last_level_up = int(state.stats.level)
		message.text += " · Level %d! 5 stat points ready." % state.stats.level
	_refresh_hud()
	return true

func _combat_active() -> bool:
	return state.tutorial.get("stage","") in ["first_combat_active","forest_patrol_active"] and not encounter_saved

func attack_nearby() -> void:
	if _combat_active() and not _save_monster_rewards(): return
	if not _combat_active() or is_instance_valid(overlay) or encounter.defeated or state.equipped_weapon.is_empty() or not pending_combat.is_empty(): return
	if encounter.attack(player,can_stand):
		message.text = "Keep moving. Amber ring means an enemy is about to strike."
	elif encounter.attack_cooldown <= 0:
		message.text = "Move closer to an enemy to attack. [F] or Attack."
	if not _save_monster_rewards(): return
	_sync_encounter_visuals()

func _checkpoint_combat() -> bool:
	if _combat_active() and not _save_monster_rewards(): return false
	if not pending_combat.is_empty(): return false
	var current := encounter.resource_state(int(state.combat.revision))
	if current.hp == state.combat.hp and current.mana == state.combat.mana and current.skills == state.combat.skills and current.potion == state.combat.potion: return true
	if state.commit_combat_resources(current):
		combat_checkpoint_elapsed = 0.0
		return true
	message.text = "Progress could not save. " + state.error
	return false

func use_class_skill(slot: int) -> void:
	if _combat_active() and not _save_monster_rewards(): return
	if not _combat_active() or is_instance_valid(overlay) or encounter.defeated or not pending_combat.is_empty(): return
	var before: Dictionary = encounter.capture()
	var result: Dictionary = encounter.use_skill(slot,player,can_stand)
	message.text = result.message
	if not result.ok: return
	if not _checkpoint_combat():
		encounter.restore(before)
		message.text = "Skill was not used because progress could not save. " + state.error
		return
	player = result.position
	_update_actor()
	_process_encounter(0)

func open_field_supplies() -> void:
	if _combat_active() and not _save_monster_rewards(): return
	if is_instance_valid(overlay) or encounter.defeated or not pending_combat.is_empty(): return
	var panel = SupplyPanel.new()
	panel.z_index = 2100
	panel.configure_supplies(state,encounter)
	panel.dismissed.connect(_close_overlay)
	panel.action_requested.connect(_use_field_potion)
	overlay = panel
	add_child(panel)
	_sync_modal_input()

func _use_field_potion(item: String) -> void:
	if not is_instance_valid(overlay) or not overlay is SupplyPanel: return
	var result: Dictionary = state.consume_combat_potion(item, "potion:"+state._new_id(), encounter.resource_state(int(state.combat.revision)))
	if not result.ok:
		overlay.show_error(result.message)
		return
	encounter.apply_resources(state.combat)
	overlay.configure_supplies(state,encounter)
	overlay.notice_label.text = result.message
	_refresh_hud()
	_update_combat_hud()

func _uses_touch_hints() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or get_viewport_rect().size.x <= 900

func _update_combat_hud() -> void:
	var active := _combat_active()
	var paused := is_instance_valid(overlay) or sleeping or not pending_combat.is_empty()
	interact_button.visible = not nearest_prop().is_empty()
	hud.attack_button.disabled = not active or paused or encounter.defeated or state.equipped_weapon.is_empty() or encounter.attack_cooldown > 0
	hud.combat_status.text = "Tap skills • Bag: potions" if _uses_touch_hints() else "Skills [1–3] • Supplies [P]"
	hud.attack_button.tooltip_text = "Basic strike [F]. Equip your weapon." if active else "Accept a field assignment at the guild."
	hud.hp_label.text = "HP %d / %d" % [encounter.hp,encounter.max_hp]
	hud.mp_label.text = "MP %d / %d" % [int(encounter.mana),int(encounter.max_mana)]
	hud.potion_button.disabled = paused or encounter.defeated
	hud.potion_button.tooltip_text = "Choose healing or mana potion [P]"
	var skills := Encounter.Abilities.for_class(encounter.hero_class)
	for slot in 3:
		var button: Button = hud.skill_buttons[slot]
		var skill: Dictionary = skills[slot]
		button.text = str(ceili(encounter.skill_cooldowns[slot])) if encounter.skill_cooldowns[slot] > 0 else skill.short
		button.tooltip_text = "%s • %d MP • %.1fs cooldown" % [skill.name,skill.mana,skill.cd]
		button.disabled = not active or paused or encounter.defeated or encounter.skill_cooldowns[slot] > 0 or encounter.mana < skill.mana
		button.queue_redraw()
	if active:
		var label_text: String = combat_data.get("label","South meadow")
		hud.set_tutorial_objective("%s: %d remaining." % [label_text,encounter.living_count()] if player.distance_to(encounter.retry_point) < 700 else ("West bridge, then north trail to the forest." if encounter.encounter_id != Encounter.ID else "West bridge, then south path to the meadow."))

func _process_encounter(delta: float) -> void:
	# Stat allocation and weapon upgrades are infrequent; avoid validating the
	# complete save ledger on every rendered frame. Transactions still validate.
	var upgrade: int = state.weapon_upgrade_level()
	if combat_stats_revision != int(state.stats.revision) or combat_weapon_upgrade != upgrade:
		encounter.refresh_stats(state.get_stat_summary(),upgrade)
		combat_stats_revision = int(state.stats.revision)
		combat_weapon_upgrade = upgrade
	if not pending_combat.is_empty():
		pending_combat_retry -= delta
		if pending_combat_retry <= 0:
			pending_combat_retry = 2.0
			var pending_resources: Dictionary = pending_combat.resources
			pending_resources.revision = state.combat.revision
			if state.commit_combat_resources(pending_resources):
				encounter.restore(pending_combat.simulation)
				pending_combat = {}
				message.text = "Progress saved. You can continue."
		_update_combat_hud()
		return
	var active := _combat_active()
	var paused := is_instance_valid(overlay) or sleeping
	if active and not _save_monster_rewards():
		for control in combat_touch_buttons: control.disabled = true
		return
	if not paused:
		var before: Dictionary = encounter.capture()
		if active:
			encounter.tick(delta,player,can_stand)
		else:
			# Safe in-town resource recovery; no inactive enemy/summon simulation.
			var dt := clampf(delta,0,0.05)
			encounter.mana = minf(encounter.max_mana,encounter.mana+encounter.mana_recovery*dt)
			for slot in 3: encounter.skill_cooldowns[slot] = maxf(0,encounter.skill_cooldowns[slot]-dt)
			encounter.potion_cooldown = maxf(0,encounter.potion_cooldown-dt)
		combat_checkpoint_elapsed += delta
		if encounter.hp != before.hp or combat_checkpoint_elapsed >= 5.0:
			if not _checkpoint_combat():
				pending_combat = {"resources":encounter.resource_state(int(state.combat.revision)),"simulation":encounter.capture()}
				encounter.restore(before)
				pending_combat_retry = 2.0
				message.text = "Combat paused until progress can save. " + state.error
				_update_combat_hud()
				return
		if active and not _save_monster_rewards(): return
		if active and encounter.defeated: _show_encounter_defeat()
		elif active and encounter.victory:
			encounter_save_retry -= delta
			if encounter_save_retry <= 0:
				encounter_save_retry = 2.0
				if state.record_encounter_victory(encounter.encounter_id):
					encounter_saved = true
					_refresh_hud()
					message.text = "Level %d! +5 stat points. Area cleared; return to the guild." % last_level_up if last_level_up > 0 else "Area cleared! Return to the guild for your reward."
				else: message.text = "Area cleared; progress could not save. Keep this area open to retry. " + state.error
	_update_combat_hud()
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
	label("No extra items or gold were lost. Used potions stay consumed.\nRetry restores HP and mana. Defeated monsters stay cleared.",content)
	var retry := button("Retry from the safe path",content)
	for appearance in ["normal","hover","pressed","focus","disabled"]:
		retry.add_theme_stylebox_override(appearance,preload("res://src/ui/ornate_panel.gd").make_button_style(appearance in ["hover","pressed"]))
	retry.add_theme_color_override("font_color",Color("362c21"))
	retry.pressed.connect(_retry_encounter)
	_sync_modal_input()

func _retry_encounter() -> void:
	if not encounter.defeated: return
	var before: Dictionary = encounter.capture()
	encounter.reset()
	_restore_defeated_spawns()
	if not _checkpoint_combat():
		encounter.restore(before)
		return
	player = encounter.retry_point
	_close_overlay()
	_update_actor()
	message.text = "Recovered. Use Attack [F] or skills [1–3]; step out of amber strikes."
	_process_encounter(0)

func cancel_overlay() -> void:
	if is_instance_valid(defeat_panel) and overlay == defeat_panel: _retry_encounter()
	else: super.cancel_overlay()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F,KEY_1,KEY_2,KEY_3,KEY_P]:
		if event.keycode == KEY_F: attack_nearby()
		elif event.keycode == KEY_P: open_field_supplies()
		else: use_class_skill(int(event.keycode-KEY_1))
		get_viewport().set_input_as_handled()
	else: super._unhandled_key_input(event)

func _update_wilderness_depth() -> void:
	var actor_rect := Rect2(player-Vector2(128,232)*actor.scale,Vector2(256,256)*actor.scale)
	for sprite in wilderness_nodes + scenery_nodes.values():
		# Reuse cached one-bit alpha masks so trees reveal the controlled actor.
		var visual := Rect2(sprite.position,sprite.texture.get_size()*sprite.scale)
		sprite.self_modulate.a = 0.38 if sprite.z_index > actor.z_index and visual.intersects(actor_rect) and _opaque_over_player(sprite) else 1.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index > 0:
		for control in combat_touch_buttons:
			if control.get_meta("combat_touch",-1) == event.index and Vector2(control.get_meta("combat_start",event.position)).distance_to(event.position) > 14:
				control.set_meta("combat_dragged",true)
	if event is InputEventScreenTouch and event.index > 0 and not event.pressed:
		for control in combat_touch_buttons:
			if control.get_meta("combat_touch",-1) == event.index:
				control.remove_meta("combat_touch")
				var point: Vector2 = control.get_global_transform_with_canvas().affine_inverse()*event.position
				if not event.canceled and not control.get_meta("combat_dragged",false) and not control.disabled and not is_instance_valid(overlay) and Rect2(Vector2.ZERO,control.size).has_point(point): control.get_meta("combat_action").call()
				get_viewport().set_input_as_handled()

func _clear_combat_touch() -> void:
	for control in combat_touch_buttons:
		if is_instance_valid(control) and control.has_meta("combat_touch"): control.remove_meta("combat_touch")

func _sync_modal_input() -> void:
	super._sync_modal_input()
	if is_instance_valid(overlay) and is_instance_valid(hud):
		for control in combat_touch_buttons: control.disabled = true
		_clear_combat_touch()

func _notification(what: int) -> void:
	super._notification(what)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_PAUSED] and is_instance_valid(hud):
		_clear_combat_touch()
