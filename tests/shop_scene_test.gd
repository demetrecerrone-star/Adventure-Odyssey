extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
func check(ok:bool,description:String)->void:
 checks += 1
 if not ok: failures += 1; push_error(description)
func _initialize()->void:call_deferred("run")
func settle()->void:
 for tick in 3:await process_frame
func run()->void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(844,390)
 for id in ["apothecary_interior","general_store_interior"]:
  var state=Save.new();state.path="user://shop_scene_"+id+str(Time.get_ticks_usec())+".json"
  var draft=Draft.new();draft.username="ShopTester"
  check(state.create(draft.payload()),"Create shop fixture")
  check(state.claim_chest_gold(),"Claim actual starter gold")
  var room=load("res://src/town_interior.gd").new();room.room_id=id;room.state=state
  root.add_child(room);room.set_process(false);await settle()
  var npc:Dictionary=room.room_data.npcs[0]
  room.player=Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1]);room._update_actor()
  room.interact();await settle()
  var before:String=JSON.stringify(state.snapshot())
  var service:String="apothecary_shop" if id=="apothecary_interior" else "general_store_shop"
  room.overlay.service_requested.emit(service);await settle()
  check(is_instance_valid(room.overlay) and room.overlay.has_method("confirm_purchase"),"Service opens actual shop")
  check(not room.joystick.input_enabled,"Shop blocks held movement")
  check(JSON.stringify(state.snapshot())==before,"Browsing does not mutate save")
  room.overlay._dismiss();await settle()
  check(JSON.stringify(state.snapshot())==before,"Back does not spend gold")
  room.overlay.service_requested.emit(service);await settle()
  room.overlay.select_item("healing_potion");room.overlay.set_quantity(2);room.overlay.review_purchase()
  var good_path:String=state.path
  state.path="user://missing_shop_scene_directory/save.json"
  room.overlay.confirm_purchase();await settle()
  check(state.wallet_gold==100 and int(state.bag.get("healing_potion",0))==0,"Failed purchase rolls back gold and bag")
  check(not room.overlay.notice_label.text.is_empty(),"Failure is visible")
  state.path=good_path
  room.overlay.confirm_purchase();await settle()
  check(state.wallet_gold==80 and int(state.bag.get("healing_potion",0))==2,"Confirmed retry pays and grants exactly once")
  check(not room.joystick.input_enabled,"Successful purchase stays modal")
  var reload=Save.new();reload.path=state.path
  check(reload.load_saved() and reload.wallet_gold==80 and int(reload.bag.get("healing_potion",0))==2,"Purchase survives reload")
  room._close_overlay();room.free();await settle()
  DirAccess.remove_absolute(state.path)
 print("Shop scene checks: %d; failures: %d"%[checks,failures])
 quit(1 if failures else 0)
