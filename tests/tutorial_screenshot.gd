extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var stamp := str(Time.get_ticks_usec())
func _initialize()->void: call_deferred("run")
func snap(filename:String)->void:
 for tick in 3: await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://screenshots/"+filename)==OK)
func run()->void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 var state = Save.new(); state.path = "user://tutorial_capture_"+stamp+".json"
 var draft = Draft.new(); draft.set_base("female"); draft.character_class = "Warrior"; draft.username = "Aeloria"
 assert(state.create(draft.payload()))
 assert(state.transfer("warrior_01_weapon",false) and state.equip("warrior_01_weapon"))
 root.size = Vector2i(1280,720)
 var world = load("res://src/starter_world.gd").new(); world.state = state
 assert(state.set_location("starter_region",Vector2(1708,1340)))
 root.add_child(world); world.set_process(false)
 await snap("tutorial_envelope_world.png")
 world.interact(); await snap("tutorial_envelope_dialogue.png")
 world.overlay.action_requested.emit("read_envelope")
 world._close_overlay(); world.free(); await process_frame
 var steps := [["guild_interior","guild_assign_blacksmith"],["blacksmith_interior","blacksmith_claim_starter"],["blacksmith_interior","tutorial_upgrade"],["guild_interior","guild_after_blacksmith"],["apothecary_interior","apothecary_claim_gift"],["guild_interior","guild_after_apothecary"],["general_store_interior","general_store_claim_keepsake"],["guild_interior","guild_after_general_store"]]
 for index in steps.size():
  var step:Array = steps[index]
  var room = load("res://src/town_interior.gd").new(); room.room_id = step[0]; room.state = state
  root.add_child(room); room.set_process(false)
  var npc:Dictionary = room.room_data.npcs[0]
  room.player = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1]); room._update_actor()
  root.size = Vector2i(1280,720)
  await snap("tutorial_%02d_%s_room.png" % [index,step[0]])
  room.interact(); await snap("tutorial_%02d_dialogue.png" % index)
  root.size = Vector2i(844,390); await snap("tutorial_%02d_phone.png" % index)
  if step[1] == "tutorial_upgrade": room.overlay.service_requested.emit(step[1])
  else: room.overlay.action_requested.emit(step[1])
  await snap("tutorial_%02d_after.png" % index)
  room._close_overlay()
  if index == steps.size()-1:
   room.open_menu(); room.overlay.show_page("quest_log"); await snap("tutorial_final_quest_log.png")
   room.overlay.show_page("inventory"); await snap("tutorial_final_inventory.png")
   room._close_overlay()
  room.free(); await process_frame
 assert(state.tutorial.stage == "first_combat_pending")
 DirAccess.remove_absolute(state.path)
 print("TUTORIAL SCREENSHOTS: native quest and sideways shop views saved")
 quit()
