extends SceneTree
const Save=preload("res://src/bedroom_save.gd")
const Draft=preload("res://src/creator/character_draft.gd")
const Icon=preload("res://src/ui/inventory_item_icon.gd")
var validate_only:=OS.get_cmdline_user_args().has("--validate-only")
var captured:=0
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in 6:await process_frame
func snap(name:String)->void:
 await settle()
 if not validate_only:
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png((OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")+"/"+name)==OK)
 captured+=1
func click(button:Button)->void:
 assert(not button.disabled)
 var point:=button.get_global_rect().get_center()
 assert(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point))
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed
  Input.parse_input_event(event);await process_frame
 await settle()
func run()->void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 for dimensions in [Vector2i(844,390),Vector2i(1280,720)]:
  root.size=dimensions
  for left in [false,true]:
   var prefix:="inventory_%dx%d_%s"%[dimensions.x,dimensions.y,"left" if left else "right"]
   var state=Save.new();state.path="user://"+prefix+"_"+str(Time.get_ticks_usec())+".json"
   var draft=Draft.new();draft.username="Aeloria";draft.set_base("female" if left else "male");draft.character_class="Ranger" if left else "Warrior";draft.skin="blue" if left else "warm"
   assert(state.create(draft.payload()))
   assert(state.transfer("healing_potion",false))
   var weapon:String=Save.Inventory.starter_weapon(draft.character_class)
   assert(state.transfer(weapon,false))
   var room=load("res://src/bedroom.gd").new();room.state=state;room.control_preferences.path="user://inventory_capture_prefs_"+str(Time.get_ticks_usec())+".json"
   assert(room.control_preferences.apply("fixed",left))
   root.add_child(room);room.set_process(false);await settle();room.open_menu();room.overlay.show_page("inventory")
   await snap(prefix+"_bag.png")
   await click(room.overlay.find_child("Inspect_"+weapon,true,false))
   assert(state.equipped_weapon.is_empty())
   await snap(prefix+"_details.png")
   var equip:Button=room.overlay.find_child("Equip_"+weapon,true,false)
   await click(equip);assert(state.equipped_weapon==weapon)
   room.overlay.inventory_scroll.scroll_vertical=0
   await snap(prefix+"_equipped.png")
   var pref:String=room.control_preferences.path;room.free();await settle();DirAccess.remove_absolute(state.path);DirAccess.remove_absolute(pref)
 root.size=Vector2i(1000,600)
 var canvas:=ColorRect.new();canvas.color=Color("f5ecd9");canvas.size=Vector2(1000,600);root.add_child(canvas)
 var ids:Array=Save.Inventory.LABELS.keys()
 for c in Save.Inventory.WEAPONS.values():
  if c.class_id != "All": ids.append(Save.Inventory.starter_armor(c.class_id))
 for index in ids.size():
  var icon=Icon.new();canvas.add_child(icon);icon.configure(ids[index]);icon.position=Vector2(30+(index%5)*195,20+int(index/5)*190);icon.size=Vector2(110,110)
  var label:=Label.new();label.text=Save.Inventory.LABELS.get(ids[index],str(ids[index]).replace("_01_armor"," armor").capitalize());label.add_theme_color_override("font_color",Color("362c21"));label.add_theme_font_size_override("font_size",15);label.position=icon.position+Vector2(-10,116);label.size=Vector2(180,50);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;canvas.add_child(label)
 await snap("inventory_item_icons.png");canvas.free()
 print("INVENTORY SCREENSHOTS: %d states validated"%captured);quit()
