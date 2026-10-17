extends Control
signal dismissed
signal character_submitted(payload: Dictionary)
const Catalog = preload("res://src/creator/catalog.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const Preview = preload("res://src/creator/asset_preview.gd")
const TexturePanel = preload("res://src/textured_panel.gd")
var draft = Draft.new()
var manifest := Catalog.empty_manifest()
var development_mode := false
var local_guest_mode := false
var mirror_mode := false
var rng := RandomNumberGenerator.new()
var panel: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var preview
var notice: Label
var name_field: LineEdit
var hair_option: OptionButton
var base_option: OptionButton
var class_option: OptionButton
var skin_option: OptionButton
var eye_option: OptionButton
var color_option: OptionButton
var submit: Button
var safe_override := Rect2()
var keyboard_height_override := 0.0
func _ready() -> void:
	rng.randomize()
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/body.ttf")
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("f4ead8"))
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.055, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("181e29")
	style.border_color = Color("b99860")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var title := _label("CHANGE YOUR APPEARANCE" if mirror_mode else "CREATE YOUR CHARACTER")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("Back")
	close.pressed.connect(_dismiss)
	heading.add_child(close)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	if development_mode:
		content.add_child(_label("DEVELOPMENT TEST • No sign-in, account or saved character"))
	preview = Preview.new()
	preview.manifest = manifest
	preview.allow_starter_outfit = not development_mode
	content.add_child(preview)
	base_option = _choice("Body", ["Male", "Female"])
	base_option.item_selected.connect(func(index):
		draft.set_base(["male", "female"][index])
		_sync()
	)
	hair_option = _choice("Hair style (15 separate styles per body; artwork pending)", [])
	hair_option.item_selected.connect(func(index): draft.hair = Catalog.hair_ids(draft.base)[index]; _refresh())
	color_option = _choice("Hair color", Catalog.HAIR_COLORS)
	color_option.item_selected.connect(func(index): draft.hair_color = Catalog.HAIR_COLORS[index]; _refresh())
	eye_option = _choice("Eyes", Catalog.EYES)
	eye_option.item_selected.connect(func(index): draft.eyes = Catalog.EYES[index]; _refresh())
	var skins: Array = []
	for entry in Catalog.SKINS:
		skins.append(entry.label)
	skin_option = _choice("Skin palette", skins)
	skin_option.item_selected.connect(func(index): draft.skin = Catalog.SKINS[index].id; _refresh())
	class_option = _choice("Class", Catalog.CLASSES)
	class_option.item_selected.connect(func(index): draft.character_class = Catalog.CLASSES[index]; _refresh())
	content.add_child(_label("Equipment is restricted to your selected class. Gear artwork is pending."))
	var random_button := _button("Random appearance")
	random_button.pressed.connect(func(): draft.randomize_appearance(rng); _sync())
	content.add_child(random_button)
	content.add_child(_label("Username"))
	name_field = LineEdit.new()
	name_field.custom_minimum_size.y = 48
	name_field.max_length = 20
	name_field.placeholder_text = "3–20 letters, numbers or underscores"
	name_field.text_changed.connect(func(value): draft.username = value; _refresh())
	name_field.text_submitted.connect(func(_value): _submit())
	name_field.focus_entered.connect(_keep_focus_visible)
	content.add_child(name_field)
	content.add_child(_label("Local guest save only. This does not reserve an online username." if local_guest_mode else "Name availability must be checked by the server when saving."))
	notice = _label("")
	content.add_child(notice)
	submit = _button("Save appearance" if mirror_mode else ("Begin local adventure" if local_guest_mode else ("Validate development draft" if development_mode else "Create character")))
	submit.pressed.connect(_submit)
	content.add_child(submit)
	var texture := Panel.new()
	texture.set_script(TexturePanel)
	texture.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(texture)
	resized.connect(_layout)
	_sync()
	_layout()
	if mirror_mode:
		base_option.disabled = true
		class_option.disabled = true
		name_field.editable = false
		name_field.text = draft.username
		content.add_child(_label("Your selected base, class and username are locked."))
		hair_option.grab_focus()
	else:
		base_option.grab_focus()
func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(70, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("26303d")
	style.border_color = Color("b99860")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("f4ead8"))
	return button
func _choice(label: String, items: Array) -> OptionButton:
	content.add_child(_label(label))
	var control := OptionButton.new()
	control.custom_minimum_size.y = 48
	for item in items:
		control.add_item(str(item))
	content.add_child(control)
	control.focus_entered.connect(_keep_focus_visible)
	return control
func _sync() -> void:
	base_option.select(0 if draft.base == "male" else 1)
	hair_option.clear()
	for i in range(15):
		hair_option.add_item("%s hair %02d • artwork pending" % [draft.base.capitalize(), i + 1])
	hair_option.select(Catalog.hair_ids(draft.base).find(draft.hair))
	color_option.select(Catalog.HAIR_COLORS.find(draft.hair_color))
	eye_option.select(Catalog.EYES.find(draft.eyes))
	for i in range(Catalog.SKINS.size()):
		if Catalog.SKINS[i].id == draft.skin:
			skin_option.select(i)
	class_option.select(Catalog.CLASSES.find(draft.character_class))
	_refresh()
func _refresh() -> void:
	preview.update_preview(draft)
	notice.text = draft.username_error() if not draft.username.is_empty() else "Choose your appearance and enter a username."
func _submit() -> void:
	var error: String = draft.validate()
	if not error.is_empty():
		notice.text = error
		name_field.grab_focus()
		return
	if development_mode:
		notice.text = "Development draft validated locally. Nothing was saved; name availability is unverified."
		return
	if not character_submitted.has_connections():
		notice.text = "Character saving is unavailable until the authentication and character backend is connected."
		return
	character_submitted.emit(draft.payload())
func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var previous_size := panel.size
	var available := Rect2(Vector2(16, 16), (size - Vector2(32, 32)).max(Vector2.ONE))
	if safe_override.has_area():
		available = available.intersection(safe_override)
	elif OS.has_feature("android"):
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and safe.has_area():
			available = available.intersection(Rect2(Vector2(safe.position) * size / screen, Vector2(safe.size) * size / screen))
	var keyboard := keyboard_height_override
	if keyboard == 0 and OS.has_feature("android"):
		keyboard = DisplayServer.virtual_keyboard_get_height() * size.y / maxf(1, DisplayServer.screen_get_size().y)
	available.end.y = minf(available.end.y, size.y - keyboard - 12)
	panel.position = available.position
	panel.size = Vector2(minf(780, available.size.x), maxf(1, available.size.y))
	panel.position.x += maxf(0, (available.size.x - panel.size.x) / 2)
	if panel.size != previous_size:
		_keep_focus_visible.call_deferred()
func _keep_focus_visible() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and content.is_ancestor_of(focused):
		var local_top := (content.get_global_transform().affine_inverse() * focused.get_global_transform()).origin.y
		scroll.scroll_vertical = int(maxf(0, local_top - (scroll.size.y - focused.size.y) * 0.5))
func _process(_delta: float) -> void:
	_layout()
func _dismiss() -> void:
	name_field.release_focus()
	dismissed.emit()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(name_field):
		_dismiss()
