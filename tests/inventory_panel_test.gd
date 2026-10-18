extends SceneTree
const Menu=preload("res://src/ui/adventure_menu.gd")
const Icon=preload("res://src/ui/inventory_item_icon.gd")
const Save=preload("res://src/bedroom_save.gd")
const Draft=preload("res://src/creator/character_draft.gd")
const Prefs=preload("res://src/control_preferences.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in 8:await process_frame
func run()->void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 for base in ["male","female"]:
  var ids:Array=Save.Inventory.LABELS.keys()
  for selected_class in Save.Inventory.WEAPONS.values():ids.append(Save.Inventory.starter_armor(selected_class.class_id))
  for id in ids:
   var icon=Icon.new();root.add_child(icon);icon.configure(id,base)
   check(icon.artwork_ready,base+" actual item icon "+id)
   if Save.Inventory.WEAPONS.has(id):
    check(icon.textures.size()==1 and icon.textures[0].get_width()==128,"Dedicated unoccluded inventory illustration")
   check(icon.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Icon never steals inspection touch")
   icon.free()
 var state=Save.new();state.path="user://inventory_panel_"+str(Time.get_ticks_usec())+".json"
 var draft=Draft.new();draft.username="InventoryQA";draft.set_base("female");draft.skin="blue"
 check(state.create(draft.payload()),"Create saved character")
 check(state.transfer("warrior_01_weapon",false) and state.transfer("healing_potion",false),"Collect existing items")
 check(state.receive_item("mana_potion",2,"world_drop","inventory-mana"),"Add actual catalog fixture")
 check(state.receive_item("mage_01_weapon",1,"world_drop","inventory-staff"),"Add class restriction fixture")
 for dimensions in [Vector2i(844,390),Vector2i(1280,720)]:
  root.size=dimensions
  for left in [false,true]:
   var before:=JSON.stringify(state.snapshot())
   var menu=Menu.new();menu.state=state;menu.preferences=Prefs.new();menu.preferences.left_handed=left;menu.initial_page="inventory"
   root.add_child(menu);await settle()
   check(is_instance_valid(menu.avatar) and menu.avatar.artwork_ready,"Actual saved layered avatar")
   check(menu.avatar.appearance==state.character,"Actual appearance preserved")
   check(menu.avatar.equipped_weapon==state.equipped_weapon,"Actual equipped weapon preserved")
   check(menu.portrait_stage.get_global_rect().end.x<=menu.inventory_scroll.get_global_rect().position.x,"Character alongside list without overlap")
   check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(menu.inventory_row.get_global_rect()),"Split stays inside viewport")
   var first:Button=menu.find_child("Inspect_healing_potion",true,false)
   check(first!=null and first.size.y>=64,"Owned item touch row")
   check(menu.inventory_scroll.get_global_rect().encloses(first.get_global_rect()),"Owned item visible on opening")
   check(first.text.contains("× 1") and first.get_theme_stylebox("normal").content_margin_left>=62,"Actual count with reserved icon space")
   var portrait_rect:Rect2=menu.portrait_stage.get_global_rect()
   menu.inventory_scroll.scroll_vertical=100000;await settle()
   check(menu.portrait_stage.get_global_rect()==portrait_rect,"Scrolling owned list leaves character fixed")
   var inspect:Button=menu.find_child("Inspect_mage_01_weapon",true,false);inspect.pressed.emit();await settle()
   check(menu.selected_item=="mage_01_weapon" and JSON.stringify(state.snapshot())==before,"Tap details is read-only")
   check(menu.find_child("Equip_mage_01_weapon",true,false).disabled,"Wrong class cannot equip")
   check(menu.inventory_details.get_parent().get_global_rect().position.y>=menu.inventory_scroll.get_global_rect().position.y-2,"Tap reveals detail heading")
   menu.find_child("BackToBag",true,false).pressed.emit();await settle()
   check(menu.inventory_scroll.scroll_vertical==0,"Back to bag restores top")
   menu.free();await settle()
 DirAccess.remove_absolute(state.path)
 print("INVENTORY PANEL CHECKS: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
