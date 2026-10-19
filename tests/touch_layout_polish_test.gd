extends "res://tests/tutorial_save_test.gd"
const Dialogue = preload("res://src/tutorial_dialogue.gd")
func settle() -> void:
 for i in 5: await process_frame
func capture(name: String) -> void:
 if not OS.get_cmdline_user_args().has("--capture"): return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OS.get_environment("AO_CAPTURE_DIR")+"/"+name+".png")==OK,"Capture "+name)
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 if not OS.get_environment("AO_CAPTURE_DIR").is_empty(): DirAccess.make_dir_recursive_absolute(OS.get_environment("AO_CAPTURE_DIR"))
 for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
  var state=fixture(selected_class)
  var weapon: String=Save.Inventory.starter_weapon(selected_class)
  check(state.transfer(weapon,false) and state.equip(weapon),"Equip fixture")
  check(state.set_location("starter_region",Vector2(1110,2280)),"Enter meadow")
  var world=load("res://src/starter_world.gd").new(); world.state=state
  root.add_child(world);world.set_process(false)
  for resolution in [Vector2i(844,390),Vector2i(960,540)]:
   root.size=resolution;await settle()
   for left in [false,true]:
    world.control_preferences.left_handed=left;world._apply_control_layout();world._update_actor();world._update_combat_hud();await settle()
    var hud=world.hud
    check(hud.identity_panel.size.y==110,"Identity panel ten percent taller")
    check(hud.menu_button.size==Vector2(64,64) and hud.potion_button.size==Vector2(64,64),"Menu and potions enlarged")
    check(hud.attack_button.size==Vector2(112,112),"Attack enlarged")
    var centers: Array[Vector2]=[]
    for button in hud.skill_buttons:
     centers.append(button.get_global_rect().get_center())
     check(button.size==Vector2(76,76),"Skill target enlarged")
     check(button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x<=button.size.x-6,"Class caption fits")
     check(button.get_global_rect().end.y+8<=hud.attack_button.get_global_rect().position.y,"Skill separated from attack row")
    check(is_equal_approx(centers[0].distance_to(centers[1]),centers[1].distance_to(centers[2])),"Three skills evenly spaced")
    check(centers[0].distance_to(centers[1])==90,"Skills have fourteen-pixel edge gap")
    await capture("touch_%s_%d_%s"%[selected_class.to_lower(),resolution.x,"left" if left else "right"])
  world.queue_free();await settle()
 root.size=Vector2i(844,390)
 var state=fixture("Necromancer")
 var room=load("res://src/bedroom.gd").new();room.state=state;root.add_child(room);room.set_process(false);await settle();room.open_menu();room.overlay.show_page("inventory");await settle()
 var menu=room.overlay
 var slots: Array[Control]=[]
 for id in ["equipped_weapon","equipped_armor","equipped_ring"]: slots.append(menu.find_child("EquipmentSlot_"+id,true,false))
 for slot in slots:
  check(slot.size==Vector2(58,58),"Equipment touch target preserved")
  check(slot.position.y==menu.portrait_stage.size.y-74,"Slots inset sixteen pixels above bottom")
 check(slots[1].position.x-slots[0].position.x==64 and slots[2].position.x-slots[1].position.x==64,"Equipment row six-pixel gaps")
 check(is_equal_approx(slots[0].position.x,menu.portrait_stage.size.x-slots[2].get_rect().end.x),"Equipment row centered away from walls")
 check(menu.avatar.position.y+24*menu.avatar.scale.y<slots[0].position.y,"Avatar feet clear equipment row")
 room.queue_free();await settle()
 for resolution in [Vector2i(844,390),Vector2i(1280,720)]:
  root.size=resolution
  var dialogue=Dialogue.new();root.add_child(dialogue);await settle()
  dialogue.configure("guild_receptionist",state.tutorial,"Necromancer");await settle()
  var expected=Vector2(minf(858,resolution.x-20),minf(649,resolution.y-20))
  check(dialogue.panel.size==expected,"Dialogue ten percent larger within screen edges")
  check(dialogue.panel.get_global_rect().encloses(dialogue.close_button.get_global_rect()),"Defer button remains in panel")
  await capture("dialogue_larger_%d"%resolution.x)
  dialogue.queue_free();await settle()
 for path in paths:DirAccess.remove_absolute(path)
 print("TOUCH LAYOUT POLISH: %d checks; failures: %d"%[checks,failures]);quit(1 if failures else 0)
