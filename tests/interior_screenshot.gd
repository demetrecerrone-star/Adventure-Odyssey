extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(path:String) -> void:
 for tick in range(3): await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://screenshots/"+path)==OK)
func run() -> void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 var index := 0
 for id in preload("res://src/town_interior.gd").ROOMS:
  var room = preload("res://src/town_interior.gd").new()
  room.room_id = id
  var draft = preload("res://src/creator/character_draft.gd").new()
  draft.set_base("female" if index % 2 else "male")
  draft.character_class = ["Warrior","Paladin","Mage","Ranger"][index]
  draft.username = "InteriorPreview"
  draft.skin = "warm"
  room.state.path = "user://interior_capture_"+id+".json"
  DirAccess.remove_absolute(room.state.path)
  assert(room.state.create(draft.payload()))
  var weapon:String = draft.character_class.to_lower()+"_01_weapon"
  assert(room.state.transfer(weapon,false) and room.state.equip(weapon))
  assert(room.state.set_location(id,room.entry_point(id)))
  root.add_child(room)
  room.set_process(false)
  await process_frame
  assert(room.can_stand(room.player) and room.actor.artwork_ready)
  await snap(id+"_entry.png")
  root.size = Vector2i(844,390)
  await snap(id+"_phone_entry.png")
  root.size = Vector2i(1280,720)
  var npc:Dictionary = room.room_data.npcs[0]
  room.player = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1])
  assert(room.can_stand(room.player))
  room._update_actor()
  await snap(id+"_attendant.png")
  # Show real layering from the side of the counter, with feet still on clear floor.
  var candidate := Vector2(npc.position[0]-100,npc.position[1])
  if room.can_stand(candidate):
   room.player = candidate
   room._update_actor()
   await snap(id+"_counter_depth.png")
  room.player = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1])
  room._update_actor()
  room.interact()
  assert(is_instance_valid(room.overlay))
  root.size = Vector2i(844,390)
  await snap(id+"_phone_dialogue.png")
  room.cancel_overlay()
  root.size = Vector2i(1280,720)
  room.player = room.anchors.door
  room.interact()
  assert(room.state.location.scene == "starter_region")
  var world = preload("res://src/starter_world.gd").new()
  world.state = room.state
  root.remove_child(room)
  room.queue_free()
  root.add_child(world)
  world.set_process(false)
  assert(world.can_stand(world.player))
  await snap(id+"_world_return.png")
  root.remove_child(world)
  world.queue_free()
  index += 1
 quit()
