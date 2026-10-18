extends "res://src/bedroom.gd"
# Shared room travel and NPC presentation. Save owns all tutorial transactions.
const ROOMS := {
 "guild_interior":{"label":"Adventurer Guild","entrance":"guild","return":[2433.3,1002.45]},
 "blacksmith_interior":{"label":"Blacksmith","entrance":"blacksmith_workyard","return":[3681.25,1737.5]},
 "apothecary_interior":{"label":"Apothecary","entrance":"shop_south_plaza","return":[2990.1,1684.2]},
 "general_store_interior":{"label":"General store","entrance":"shop_southwest","return":[2502.0,1519.8]}
}
var room_id := "guild_interior"
var room_data: Dictionary = {}
var npc_nodes := {}
var room_polygons := {}
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
 room_polygons = {}
 anchors = {"door":Vector2(room_data.exit_anchor[0],room_data.exit_anchor[1])}
 wake_spawn = Vector2(room_data.entry_spawn[0],room_data.entry_spawn[1])
 for item in room_data.props + room_data.npcs:
  var r = item.get("collision_rect")
  if item.get("collision_polygon") is Array:
   var polygon := PackedVector2Array()
   for point in item.collision_polygon: polygon.append(Vector2(point[0],point[1]))
   room_polygons[item.id] = polygon
  elif r is Array: prop_rects[item.id] = Rect2(r[0],r[1],r[2],r[3])
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
 for polygon in room_polygons.values():
  if Geometry2D.is_point_in_polygon(point,polygon): return false
  for index in polygon.size():
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])) < 16.0: return false
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
 var attendant: String = {"guild_interior":"guild_receptionist", "blacksmith_interior":"blacksmith", "apothecary_interior":"apothecary", "general_store_interior":"shopkeeper"}.get(room_id, "")
 if not attendant.is_empty(): open_tutorial_dialogue(attendant)
func _exit() -> void:
 _reset_movement()
 if state.set_location(room_id,player): exited.emit()
 else: message.text = state.error

func _update_actor() -> void:
 super._update_actor()
 if not is_instance_valid(actor): return
 var player_rect := Rect2(player-Vector2(128,232)*actor.scale,Vector2(256,256)*actor.scale)
 for item in room_data.get("props",[]):
  if not prop_nodes.has(item.id): continue
  var prop:Sprite2D = prop_nodes[item.id]
  prop.z_index = int(item.depth_y)
  if not item.get("occlusion_front_chain") is Array: continue
  var bounds := Rect2(prop.position+prop.offset*prop.scale,prop.texture.get_size()*prop.scale)
  if bounds.intersects(player_rect):
   prop.z_index = actor.z_index-2 if player.y >= _front_edge_y(item,player.x) else actor.z_index+2
  # Keep the attendant correctly behind their own counter when its depth changes
  # for the player standing on the opposite long side.
  for npc in room_data.get("npcs",[]):
   if not npc_nodes.has(npc.id): continue
   var sprite:Sprite2D = npc_nodes[npc.id]
   var npc_bounds := Rect2(sprite.position+sprite.offset*sprite.scale,sprite.texture.get_size()*sprite.scale)
   sprite.z_index = int(npc.depth_y)
   if npc.get("draw_before_prop_id", "") == item.id:
    sprite.z_index = prop.z_index-1
   elif npc_bounds.intersects(bounds):
    sprite.z_index = prop.z_index+1 if sprite.position.y >= _front_edge_y(item,sprite.position.x) else prop.z_index-1

func _front_edge_y(item:Dictionary,x:float)->float:
 var chain:Array = item.occlusion_front_chain
 if chain.is_empty(): return float(item.depth_y)
 var sorted := chain.duplicate(true)
 sorted.sort_custom(func(a,b): return a[0] < b[0])
 if x <= float(sorted[0][0]): return float(sorted[0][1])
 for index in range(1,sorted.size()):
  if x <= float(sorted[index][0]):
   var a:Array = sorted[index-1]; var b:Array = sorted[index]
   return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/maxf(0.001,float(b[0])-float(a[0])))
 return float(sorted[-1][1])
