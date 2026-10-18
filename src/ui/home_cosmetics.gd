extends Control
signal closed
signal changed
const Ornate = preload("res://src/ui/ornate_panel.gd")
const Catalog = preload("res://src/cosmetic_catalog.gd")
var state
var selected := "armor_moonweave"
var confirmed := false
var notice := "Preview freely. Purchases use earned Adventure Odyssey Sigils."
var actor: Node2D
var bed: Sprite2D
var preview: Control
var body: VBoxContainer
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 z_index = 2200
 _setup_theme()
 var shade := Ornate.new()
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
 add_child(margin)
 var split := HBoxContainer.new()
 split.add_theme_constant_override("separation",18)
 margin.add_child(split)
 preview = Control.new()
 preview.custom_minimum_size = Vector2(190,250)
 preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 split.add_child(preview)
 actor = preload("res://src/layered_avatar.gd").new()
 preview.add_child(actor)
 actor.configure(state.character.base,state.character["class"],state.character)
 actor.set_equipped_weapon(state.equipped_weapon)
 actor.scale = Vector2.ONE * 1.1
 bed = Sprite2D.new()
 var cropped := AtlasTexture.new()
 cropped.atlas = preload("res://assets/bedroom/bed.png")
 cropped.region = Rect2(180,285,310,410)
 bed.texture = cropped
 bed.scale = Vector2.ONE * 0.58
 preview.add_child(bed)
 var scroll := ScrollContainer.new()
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 split.add_child(scroll)
 body = VBoxContainer.new()
 body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",10)
 scroll.add_child(body)
 preview.resized.connect(_position_preview)
 _render()
func _position_preview() -> void:
 actor.position = Vector2(preview.size.x*0.5,preview.size.y*0.73)
 bed.position = preview.size*0.5
func _label(text: String, font_size: int = 18) -> Label:
 var node := Label.new()
 node.text = text
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size",font_size)
 if font_size >= 22: node.add_theme_font_override("font",preload("res://assets/fonts/title.ttf"))
 body.add_child(node)
 return node
func _button(text: String, callback: Callable) -> Button:
 var node := Button.new()
 node.text = text
 node.custom_minimum_size.y = 48
 node.pressed.connect(callback)
 node.gui_input.connect(func(event: InputEvent):
  if event is InputEventScreenTouch and event.index > 0:
   if event.pressed and not event.canceled and not node.disabled:
    node.set_meta("touch_owner",event.index)
   elif node.get_meta("touch_owner",-1)==event.index:
    node.remove_meta("touch_owner")
    if not event.canceled and not node.disabled and Rect2(Vector2.ZERO,node.size).has_point(event.position): node.pressed.emit()
   node.accept_event()
  elif event is InputEventScreenDrag and node.get_meta("touch_owner",-1)==event.index:
   if not Rect2(Vector2.ZERO,node.size).has_point(event.position): node.remove_meta("touch_owner")
 )
 body.add_child(node)
 return node
func _render() -> void:
 for node in body.get_children():
  body.remove_child(node)
  node.queue_free()
 var item: Dictionary = Catalog.ITEMS[selected]
 _label("HOME • DYES & DECOR",22)
 _label("Adventure Odyssey Sigils: %d" % state.wallet_sigils)
 var picker := OptionButton.new()
 picker.custom_minimum_size.y = 48
 picker.name = "CosmeticPicker"
 for id in Catalog.ITEMS:
  picker.add_item(Catalog.ITEMS[id].label)
  picker.set_item_metadata(picker.item_count-1,id)
  if id == selected: picker.select(picker.item_count-1)
 picker.item_selected.connect(func(index):
  selected = str(picker.get_item_metadata(index))
  confirmed = false
  notice = "Preview only. Your saved look has not changed."
  _render()
 )
 body.add_child(picker)
 _label(item.description)
 var owned: bool = selected in state.cosmetics.owned
 var equipped: bool = str(state.cosmetics.equipped.get(item.slot,"")) == selected
 if owned:
  var equip := _button("Equipped" if equipped else "Equip owned cosmetic",_equip)
  equip.disabled = equipped
 else:
  _button(("Confirm purchase • %d Sigils" if confirmed else "Buy • %d Sigils") % item.price,_purchase)
 _label(notice,16)
 _button("Close • keep saved look",func(): closed.emit())
 actor.visible = item.slot == "armor_dye"
 bed.visible = item.slot == "bed"
 actor.set_cosmetic_dye(selected if item.slot == "armor_dye" else "armor_original")
 # Bed shader uses full registered UVs; AtlasTexture region remaps those UVs.
 bed.material = Catalog.material(selected) if item.slot == "bed" else null
 _position_preview()
func _purchase() -> void:
 if not confirmed:
  confirmed = true
  notice = "Buy this look for %d earned Sigils? Purchase does not equip it." % Catalog.ITEMS[selected].price
  _render()
  return
 confirmed = false
 if state.purchase_cosmetic(selected):
  notice = "Purchased and saved. Equip whenever you like."
  changed.emit()
 else: notice = state.error
 _render()
func _equip() -> void:
 if state.equip_cosmetic(selected):
  notice = "Look equipped and saved. Combat stats are unchanged."
  changed.emit()
 else: notice = state.error
 _render()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  if is_instance_valid(body):
   for node in body.get_children():
    if node.has_meta("touch_owner"): node.remove_meta("touch_owner")

func _setup_theme() -> void:
 theme = Theme.new()
 theme.default_font = preload("res://assets/fonts/body.ttf")
 theme.default_font_size = 18
 for type in ["Label","Button","OptionButton","PopupMenu"]:
  theme.set_color("font_color",type,Ornate.INK)
  for key in ["font_hover_color","font_pressed_color","font_focus_color"]:
   theme.set_color(key,type,Ornate.INK)
 for type in ["Button","OptionButton"]:
  theme.set_color("font_disabled_color",type,Color("76664e"))
  theme.set_stylebox("normal",type,Ornate.make_button_style())
  theme.set_stylebox("hover",type,Ornate.make_button_style(true))
  theme.set_stylebox("pressed",type,Ornate.make_button_style(true))
  theme.set_stylebox("disabled",type,Ornate.make_button_style(false,true))
  var focus := StyleBoxFlat.new()
  focus.bg_color = Color.TRANSPARENT
  focus.border_color = Ornate.TURQUOISE
  focus.set_border_width_all(3)
  focus.set_corner_radius_all(8)
  theme.set_stylebox("focus",type,focus)
 theme.set_stylebox("panel","PopupMenu",Ornate.make_button_style())
 theme.set_stylebox("hover","PopupMenu",Ornate.make_button_style(true))
