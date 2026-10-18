extends SceneTree
const Save=preload("res://src/bedroom_save.gd")
const Draft=preload("res://src/creator/character_draft.gd")
func _initialize()->void:call_deferred("run")
func snap(name:String)->void:
 for tick in 3:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://screenshots/"+name)==OK)
func run()->void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 for id in ["apothecary_interior","general_store_interior"]:
  var state=Save.new();state.path="user://shop_capture_"+str(Time.get_ticks_usec())+".json"
  var draft=Draft.new();draft.username="Aeloria"
  assert(state.create(draft.payload()) and state.claim_chest_gold())
  var room=load("res://src/town_interior.gd").new();room.room_id=id;room.state=state
  root.size=Vector2i(1280,720);root.add_child(room);room.set_process(false)
  var npc:Dictionary=room.room_data.npcs[0]
  room.player=Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1]);room._update_actor()
  room.interact()
  room.overlay.service_requested.emit("apothecary_shop" if id=="apothecary_interior" else "general_store_shop")
  await snap("shop_"+id+"_desktop.png")
  root.size=Vector2i(844,390);await snap("shop_"+id+"_phone.png")
  room.overlay.select_item("healing_potion");room.overlay.set_quantity(2)
  await snap("shop_"+id+"_selected.png")
  room.overlay.review_purchase()
  await snap("shop_"+id+"_confirmation.png")
  room.overlay.confirm_purchase();await snap("shop_"+id+"_purchased.png")
  assert(state.wallet_gold==80 and state.bag.healing_potion==2)
  room.free();await process_frame;DirAccess.remove_absolute(state.path)
 print("SHOP SCREENSHOTS: 10 native purchase views saved")
 quit()
