extends "res://tests/equipment_popup_test.gd"
const Dialogue = preload("res://src/tutorial_dialogue.gd")
func capture(name: String) -> void:
 if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 var path=OS.get_environment("AO_CAPTURE_DIR")
 if not path.is_empty():
  DirAccess.make_dir_recursive_absolute(path)
  check(root.get_texture().get_image().save_png(path.path_join(name+".png"))==OK,"native usability capture")
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 for left in [false,true]:
  root.size=Vector2i(844,390)
  var state=fixture("Warrior","female" if left else "male")
  var weapon=Save.Inventory.starter_weapon("Warrior")
  check(state.transfer(weapon,false) and state.equip(weapon),"starter equipped")
  check(state.set_location("starter_region",Save.Relic.point(state.hidden_relic)) and state.claim_hidden_stick(state.hidden_relic.tree_id),"legitimate relic claimed")
  var room=preload("res://src/bedroom.gd").new(); room.state=state
  room.control_preferences.path="user://usability_prefs_%d.json"%Time.get_ticks_usec(); paths.append(room.control_preferences.path)
  check(room.control_preferences.apply("fixed",left),"handedness saved")
  root.add_child(room); room.set_process(false); await settle()
  room.open_menu(); var menu=room.overlay; menu.show_page("inventory"); await settle()
  await click(menu.find_child("Inspect_hidden_old_stick",true,false))
  var before=snap(state); var bytes=FileAccess.get_file_as_bytes(state.path)
  DirAccess.make_dir_absolute(state.path+".tmp")
  await click(menu.find_child("Equip_hidden_old_stick",true,false))
  check(snap(state)==before and FileAccess.get_file_as_bytes(state.path)==bytes,"failed swap preserves live and disk state")
  check(is_instance_valid(menu.item_popup),"failed swap keeps item details and retry action open")
  if is_instance_valid(menu.item_popup):
   var notice=menu.item_popup.find_child("ItemActionNotice",true,false)
   check(notice!=null and not notice.text.is_empty(),"save error appears inside active item popup")
   check(menu.item_popup.find_child("ItemDetailScroll",true,false).get_global_rect().encloses(notice.get_global_rect()),"popup error immediately visible without scrolling")
   await capture("inventory_save_failure_%s"%("left" if left else "right"))
  DirAccess.remove_absolute(state.path+".tmp")
  if not is_instance_valid(menu.item_popup): menu._open_item_popup("hidden_old_stick","bag")
  await settle()
  await click(menu.find_child("Equip_hidden_old_stick",true,false))
  check(state.equipped_weapon=="hidden_old_stick" and state.bag[weapon]==1,"retry swaps once and retains original weapon")
  var loaded=Save.new(); loaded.path=state.path
  check(loaded.load_saved() and snap(loaded)==snap(state),"retry reload matches all authoritative state")
  root.size=Vector2i(1280,720); await settle()
  menu._open_item_popup("hidden_old_stick","equipped_weapon"); await settle()
  root.size=Vector2i(844,390); await settle()
  var frame=menu.item_popup.find_child("ItemPopupFrame",true,false)
  check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(frame.get_global_rect()),"open item popup remains inside resized phone viewport")
  check(menu.item_popup.z_index > menu.avatar.relic_sprite.z_index,"held relic cannot render over popup text")
  await capture("inventory_resize_%s"%("left" if left else "right"))
  room.queue_free(); await settle()
 var dialogue=Dialogue.new()
 dialogue.configure("guild_receptionist",state_for_stage("visit_guild"))
 root.add_child(dialogue); await settle()
 for repeat in range(50): dialogue.configure("guild_receptionist",state_for_stage("visit_guild"))
 check(dialogue._touch_buttons.size()==dialogue.choices.get_child_count()+1,"repeated conversation rebuilds do not accumulate stale touch controls")
 dialogue.set_pending(true)
 dialogue.show_error("Could not save your errand. Nothing changed. Please try again.")
 await settle()
 check(not dialogue.pending,"dialogue failure re-enables choices")
 check(dialogue.scroll.get_global_rect().encloses(dialogue.notice_label.get_global_rect()),"failed quest action error is immediately visible on phone")
 await capture("dialogue_save_failure_phone")
 dialogue.queue_free(); await settle()
 for path in paths: DirAccess.remove_absolute(path)
 print("GAMEPLAY USABILITY: %d checks; failures: %d"%[checks,failures])
 quit(1 if failures else 0)
func state_for_stage(_stage: String) -> Dictionary:
 return Dialogue.Progress.plan_action(Dialogue.Progress.initial_state(),"read_envelope","usability.read_envelope").next_state
