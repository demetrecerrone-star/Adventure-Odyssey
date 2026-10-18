extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
var stamp := str(Time.get_ticks_usec())
func check(ok:bool, description:String)->void:
 checks += 1
 if not ok: failures += 1; push_error(description)
func _initialize()->void: call_deferred("run")
func settle()->void:
 for tick in 3: await process_frame
func run()->void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(844,390)
 var state = Save.new()
 state.path = "user://tutorial_scene_"+stamp+".json"
 var draft = Draft.new(); draft.set_base("female"); draft.character_class = "Warrior"; draft.username = "QuestTester"
 check(state.create(draft.payload()), "Create isolated tutorial fixture")
 check(state.transfer("warrior_01_weapon",false) and state.equip("warrior_01_weapon"), "Carry starter weapon to smith")
 var world = load("res://src/starter_world.gd").new(); world.state = state
 root.add_child(world); world.set_process(false); await settle()
 check(world.can_stand(world.ENVELOPE), "Envelope is on accessible doorstep ground")
 world.player = world.ENVELOPE; world._update_actor()
 check(world.nearest_prop() == "envelope", "Envelope remains separate from home entrance")
 world.interact(); await settle()
 check(is_instance_valid(world.overlay), "Doorstep letter opens dialogue")
 check(not world.joystick.input_enabled, "Letter blocks joystick")
 world.overlay.action_requested.emit("read_envelope"); await settle()
 check(state.tutorial.stage == "visit_guild", "Letter action persists guild objective")
 check(world.hud.quest_label.text.contains("Adventurer Guild"), "HUD objective refreshes after letter")
 world._close_overlay(); root.remove_child(world); world.free()
 var steps := [
  ["guild_interior", "guild_assign_blacksmith"],
  ["blacksmith_interior", "blacksmith_claim_starter"],
  ["blacksmith_interior", "tutorial_upgrade"],
  ["guild_interior", "guild_after_blacksmith"],
  ["apothecary_interior", "apothecary_claim_gift"],
  ["guild_interior", "guild_after_apothecary"],
  ["general_store_interior", "general_store_claim_keepsake"],
  ["guild_interior", "guild_after_general_store"]]
 for step in steps:
  var room = load("res://src/town_interior.gd").new(); room.room_id = step[0]; room.state = state
  root.add_child(room); room.set_process(false); await settle()
  var npc:Dictionary = room.room_data.npcs[0]
  room.player = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1]); room._update_actor()
  check(room.can_stand(room.player), step[0]+" attendant stand remains accessible")
  for prop in room.room_data.props:
   if not prop.get("occlusion_front_chain") is Array: continue
   var node:Sprite2D = room.prop_nodes[prop.id]
   var expected_front:bool = room.player.y >= room._front_edge_y(prop,room.player.x)
   var visual := Rect2(node.position+node.offset*node.scale,node.texture.get_size()*node.scale)
   var hero := Rect2(room.player-Vector2(128,232)*room.actor.scale,Vector2(256,256)*room.actor.scale)
   if visual.intersects(hero): check((room.actor.z_index > node.z_index) == expected_front, step[0]+" player sorts against actual counter edge")
   var polygon:PackedVector2Array = room.room_polygons[prop.id]
   var middle := Vector2.ZERO
   for point in polygon: middle += point
   middle /= polygon.size()
   check(not room.can_stand(middle), step[0]+" counter footprint is solid")
  room.interact(); await settle()
  check(is_instance_valid(room.overlay),step[0]+" opens tutorial conversation")
  if step[1] == "tutorial_upgrade": room.overlay.service_requested.emit(step[1])
  else: room.overlay.action_requested.emit(step[1])
  await settle()
  check(room.overlay.notice_label.text.is_empty(), step[1]+" saves without an error")
  check(not room.joystick.input_enabled,step[1]+" remains modal after transaction")
  room._close_overlay(); room.open_menu(); await settle(); room.overlay.show_page("quest_log"); await settle()
  check(is_instance_valid(room.overlay.body), "Quest log opens with saved progress")
  room._close_overlay(); root.remove_child(room); room.free()
 check(state.tutorial.stage == "first_combat_pending", "Errands stop at unavailable combat boundary")
 check(state.bag.mana_potion == 5 and state.bag.keepsake_ring == 1, "Exact once-only quest gifts")
 var reload = Save.new(); reload.path = state.path
 var loaded:bool = reload.load_saved()
 check(loaded and reload.tutorial == JSON.parse_string(JSON.stringify(state.tutorial)), "Tutorial scene progress survives reload")
 print("Tutorial scene checks: %d; failures: %d" % [checks, failures])
 DirAccess.remove_absolute(state.path)
 quit(1 if failures else 0)
