extends "res://tests/tutorial_save_test.gd"
func settle() -> void:
 for i in 6: await process_frame
func click(button: Button) -> void:
 check(button != null and not button.disabled,"Enabled action exists")
 if button == null or button.disabled: return
 var point := button.get_global_rect().get_center()
 check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point),"Action in phone bounds")
 for pressed in [true,false]:
  var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=pressed
  Input.parse_input_event(event); await process_frame
 await settle()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 for left in [false,true]:
  root.size=Vector2i(844,390)
  var state=fixture("Warrior","female" if left else "male")
  var weapon: String=Save.Inventory.starter_weapon("Warrior")
  check(state.transfer(weapon,false) and state.equip(weapon),"Starter initially occupies slot")
  check(state.transfer("healing_potion",false),"Carry health potion")
  check(state.set_location("starter_region",Save.Relic.point(state.hidden_relic)) and state.claim_hidden_stick(state.hidden_relic.tree_id),"Find stick normally")
  var room=load("res://src/bedroom.gd").new(); room.state=state
  room.control_preferences.path="user://popup_prefs_%d.json" % Time.get_ticks_usec(); paths.append(room.control_preferences.path)
  check(room.control_preferences.apply("fixed",left),"Persist handedness")
  root.add_child(room); room.set_process(false); await settle(); room.open_menu(); room.overlay.show_page("inventory"); await settle()
  var menu=room.overlay
  await click(menu.find_child("Inspect_hidden_old_stick",true,false))
  check(menu.item_popup.is_ancestor_of(menu.get_viewport().gui_get_focus_owner()),"Popup owns keyboard focus")
  check(menu._weapon_damage("hidden_old_stick","bag")-menu._weapon_damage(weapon,"equipped_weapon")==988,"Real green improvement")
  if OS.get_cmdline_user_args().has("--capture"):
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png((OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")+"/stick_popup_%s.png" % ("left" if left else "right"))
  var before=snap(state)
  DirAccess.make_dir_absolute(state.path+".tmp")
  await click(menu.find_child("Equip_hidden_old_stick",true,false))
  check(snap(state)==before,"Actual Equip save failure rolls back both slots")
  DirAccess.remove_absolute(state.path+".tmp")
  await click(menu.find_child("Inspect_hidden_old_stick",true,false))
  await click(menu.find_child("Equip_hidden_old_stick",true,false))
  check(state.equipped_weapon=="hidden_old_stick" and state.bag[weapon]==1,"Actual UI swaps occupied slot")
  check(menu.avatar.equipped_weapon=="hidden_old_stick" and room.actor.equipped_weapon=="hidden_old_stick","Both real avatars refresh")
  await click(menu.find_child("EquipmentSlot_equipped_weapon",true,false))
  check(menu.item_container=="equipped_weapon","Tappable equipped icon opens details")
  await click(menu.find_child("CloseItemPopup",true,false))
  await click(menu.find_child("Inspect_"+weapon,true,false))
  check(menu._weapon_damage(weapon,"bag")-menu._weapon_damage("hidden_old_stick","equipped_weapon")==-988,"Real red downgrade")
  await click(menu.find_child("Equip_"+weapon,true,false))
  check(state.equipped_weapon==weapon and state.bag.hidden_old_stick==1,"Swap back retains relic")
  var resources: Dictionary=state.combat.duplicate(true); resources.hp-=40
  check(state.commit_combat_resources(resources),"Create real missing HP")
  await click(menu.find_child("Inspect_healing_potion",true,false))
  await click(menu.find_child("Use_healing_potion",true,false))
  check(state.bag.healing_potion==0 and state.combat.hp==resources.hp+40,"Item Use consumes once and heals")
  var loaded=Save.new(); loaded.path=state.path
  check(loaded.load_saved() and snap(loaded)==snap(state),"Swap and consumption survive reload")
  if OS.get_cmdline_user_args().has("--capture"):
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png((OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")+"/equipment_bag_%s.png" % ("left" if left else "right"))
  room.queue_free(); await settle()
 for path in paths: DirAccess.remove_absolute(path)
 print("EQUIPMENT POPUP CHECKS: %d; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
