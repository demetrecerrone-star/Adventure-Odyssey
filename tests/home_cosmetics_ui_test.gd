extends SceneTree
class Fixture extends RefCounted:
 var wallet_sigils := 10
 var cosmetics := preload("res://src/cosmetic_catalog.gd").initial()
 var character: Dictionary
 var equipped_weapon := ""
 var error := "Simulated write failure"
 var fail := false
 var purchases := 0
 func purchase_cosmetic(id: String) -> bool:
  purchases += 1
  if fail: return false
  if id not in cosmetics.owned:
   wallet_sigils -= preload("res://src/cosmetic_catalog.gd").ITEMS[id].price
   cosmetics.owned.append(id)
  return true
 func equip_cosmetic(id: String) -> bool:
  if fail: return false
  cosmetics.equipped[preload("res://src/cosmetic_catalog.gd").ITEMS[id].slot] = id
  return true
var checks := 0
var failures := 0
func check(value: bool, note: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(note)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(844,390)
 var panel = preload("res://src/ui/home_cosmetics.gd").new()
 panel.state = Fixture.new()
 var draft = preload("res://src/creator/character_draft.gd").new()
 draft.username = "CosmeticUI"
 panel.state.character = draft.payload()
 root.add_child(panel)
 await process_frame
 check(panel.theme.get_font("font","Label") != null,"Uses game body font")
 check(panel.theme.get_color("font_color","Label")==preload("res://src/ui/ornate_panel.gd").INK,"Parchment ink contrast")
 check(panel.theme.get_stylebox("normal","Button") is StyleBoxFlat,"Uses ornate button styles")
 var original: Dictionary = panel.state.cosmetics.duplicate(true)
 panel._purchase()
 check(panel.confirmed and panel.state.purchases==0,"First purchase press only asks confirmation")
 check(panel.state.cosmetics==original and panel.state.wallet_sigils==10,"Preview spends/equips nothing")
 panel.state.fail=true
 panel._purchase()
 check(panel.state.wallet_sigils==10 and panel.state.cosmetics==original,"Failure preserves UI's saved wallet/looks")
 check(panel.notice==panel.state.error,"Failure remains visible")
 panel.state.fail=false
 panel._purchase()
 panel._purchase()
 check(panel.state.wallet_sigils==7,"One confirmed purchase")
 check(panel.state.cosmetics.equipped.armor_dye=="armor_original","Buying does not equip")
 panel.state.fail=true
 panel._equip()
 check(panel.state.cosmetics.equipped.armor_dye=="armor_original","Failed equip leaves current look")
 panel.state.fail=false
 panel._equip()
 check(panel.state.cosmetics.equipped.armor_dye=="armor_moonweave","Explicit equip succeeds")
 panel.selected="armor_original"
 panel._equip()
 check(panel.state.wallet_sigils==7 and panel.state.cosmetics.equipped.armor_dye=="armor_original","Default is free")
 panel.selected="bed_riverside"
 panel._render()
 await process_frame
 var action: Button
 for child in panel.body.get_children():
  if child is Button and child.text.begins_with("Buy"): action=child
 var down := InputEventScreenTouch.new()
 down.index=2
 down.pressed=true
 down.position=Vector2(20,20)
 action.gui_input.emit(down)
 var up := InputEventScreenTouch.new()
 up.index=2
 up.position=Vector2(20,20)
 up.canceled=true
 action.gui_input.emit(up)
 check(not panel.confirmed,"Canceled second-finger touch cannot purchase")
 action.gui_input.emit(down)
 panel._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 up.canceled=false
 action.gui_input.emit(up)
 check(not panel.confirmed,"Focus loss clears touch owner")
 action.gui_input.emit(down)
 var drag := InputEventScreenDrag.new()
 drag.index=2
 drag.position=Vector2(-50,-50)
 action.gui_input.emit(drag)
 action.gui_input.emit(up)
 check(not panel.confirmed,"Dragging away cancels")
 action.gui_input.emit(down)
 action.gui_input.emit(up)
 check(panel.confirmed,"Valid secondary finger opens confirmation only")
 check(panel.state.wallet_sigils==7,"Confirmation never itself debits")
 print("Home cosmetics UI: %d checks; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
