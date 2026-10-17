extends "res://src/bedroom.gd"
# Shared room travel and static service-NPC presentation. No economy or quest grants.
const ROOMS := {
 "guild_interior":{"label":"Adventurer Guild","entrance":"guild","return":[2433.3,1002.45]},
 "blacksmith_interior":{"label":"Blacksmith","entrance":"blacksmith_workyard","return":[3681.25,1737.5]},
 "apothecary_interior":{"label":"Apothecary","entrance":"shop_south_plaza","return":[2990.1,1684.2]},
 "general_store_interior":{"label":"General store","entrance":"shop_southwest","return":[2502.0,1519.8]}
}
var room_id := "guild_interior"
var room_data: Dictionary = {}
var npc_nodes := {}
var elapsed := 0.0
static func available(id:String) -> bool:
 return ROOMS.has(id) and FileAccess.file_exists("res://assets/town-interiors/"+id+"/layout.json")
static func entry_point(id:String) -> Vector2:
 var data:Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-interiors/"+id+"/layout.json"))
 return Vector2(data.entry_spawn[0],data.entry_spawn[1])
func _ready() -> void:
 room_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town-interiors/"+room_id+"/layout.json"))
 super._ready()
 for child in stage.get_children():
  if child != actor: child.free()
 prop_nodes.clear()
 var plate := Sprite2D.new()
 plate.centered = false
 plate.texture = load(_asset(room_data.plate))
 stage.add_child(plate)
 for item in room_data.props:
  prop_nodes[item.id] = _layer(item,item.file)
 for item in room_data.npcs:
  npc_nodes[item.id] = _layer(item,item.asset_file)
 _update_actor()
 message.text = "Explore the room. Speak to the attendant with [E], or return through the door."
 status.text = state.character.get("username","")+" • "+ROOMS[room_id].label
func _asset(file:String) -> String:
 return "res://assets/town-interiors/"+room_id+"/"+file
func _layer(item:Dictionary,file:String) -> Sprite2D:
 var sprite := Sprite2D.new()
 sprite.name = item.id
 sprite.texture = load(_asset(file))
 sprite.centered = false
 sprite.offset = -Vector2(item.source_anchor[0],item.source_anchor[1])
 sprite.position = Vector2(item.position[0],item.position[1])
 sprite.scale = Vector2.ONE * float(item.scale)
 sprite.z_index = int(item.depth_y)
 stage.add_child(sprite)
 return sprite
func _load_layout() -> void:
 prop_rects = {}
 anchors = {"door":Vector2(room_data.exit_anchor[0],room_data.exit_anchor[1])}
 wake_spawn = Vector2(room_data.entry_spawn[0],room_data.entry_spawn[1])
 for item in room_data.props + room_data.npcs:
  var r = item.get("collision_rect")
  if r is Array: prop_rects[item.id] = Rect2(r[0],r[1],r[2],r[3])
 for item in room_data.npcs:
  anchors[item.id] = Vector2(item.interaction_anchor[0],item.interaction_anchor[1])
func _start_character() -> void:
 super._start_character()
 if state.location.scene == room_id:
  var p:Array = state.location.position
  var candidate := Vector2(p[0],p[1])
  if can_stand(candidate): player = candidate
 movement_speed = 155.0
 _update_actor()
func can_stand(point:Vector2) -> bool:
 var floor_points := PackedVector2Array()
 for p in room_data.get("floor_polygon",[]): floor_points.append(Vector2(p[0],p[1]))
 if floor_points.size() < 3 or not Geometry2D.is_point_in_polygon(point,floor_points): return false
 for rect in prop_rects.values():
  if rect.grow(16).has_point(point): return false
 return true
func nearest_prop() -> String:
 var result := ""
 var closest := 100.0
 for id in anchors:
  var radius := 90.0 if id == "door" else 75.0
  var distance:float = player.distance_to(anchors[id])
  if distance <= radius and distance < closest:
   result = id
   closest = distance
 return result
func _process(delta:float) -> void:
 super._process(delta)
 if state.character.is_empty() or is_instance_valid(overlay): return
 elapsed += delta
 if elapsed >= 10.0:
  elapsed = 0
  if not state.set_location(room_id,player): message.text = state.error
func interact() -> void:
 if sleeping or is_instance_valid(overlay): return
 var id := nearest_prop()
 if id.is_empty(): return
 _reset_movement()
 if id == "door":
  var p:Array = ROOMS[room_id]["return"]
  if state.set_location("starter_region",Vector2(p[0],p[1])): world_requested.emit()
  else: message.text = state.error
 else: _speak()
func _speak() -> void:
 overlay = Control.new()
 overlay.z_index = 2100
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(overlay)
 var dim := ColorRect.new()
 dim.color = Color(0.02,0.03,0.05,0.9)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(dim)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(center)
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",16)
 center.add_child(box)
 label(ROOMS[room_id].label,box)
 var notice := label("Welcome. Services and tutorial conversations are being prepared.",box)
 notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 notice.custom_minimum_size.x = minf(460,size.x-48)
 var close := button("Leave conversation",box)
 close.pressed.connect(_close_overlay)
 close.grab_focus()
func _exit() -> void:
 _reset_movement()
 if state.set_location(room_id,player): exited.emit()
 else: message.text = state.error
