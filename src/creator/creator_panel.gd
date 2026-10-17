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
var left_scroll: ScrollContainer
var right_scroll: ScrollContainer
var left_options: VBoxContainer
var right_options: VBoxContainer
var center: VBoxContainer
var columns: HBoxContainer
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
var keyboard_navigation := false
func _ready() -> void:
	rng.randomize()
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/body.ttf")
	theme.default_font_size = 16
	_apply_parchment_theme()
	var dim := ColorRect.new()
	dim.color = Color("f1e8d5")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5eedf")
	style.border_color = Color("b28b43")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label("CHANGE YOUR APPEARANCE" if mirror_mode else "CREATE YOUR CHARACTER")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("Back")
	close.pressed.connect(_dismiss)
	heading.add_child(close)
	columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	left_scroll = _side_column()
	left_options = left_scroll.get_child(0)
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 1.2
	var center_style := _surface(Color("e6d8bb"), Color("c6aa70"))
	center_style.set_content_margin_all(8)
	center_panel.add_theme_stylebox_override("panel", center_style)
	columns.add_child(center_panel)
	center = VBoxContainer.new()
	center_panel.add_child(center)
	right_scroll = _side_column()
	right_options = right_scroll.get_child(0)
	preview = Preview.new()
	preview.manifest = manifest
	preview.allow_starter_outfit = not development_mode
	preview.responsive = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(preview)
	base_option = _choice(left_options, "Body", ["Male", "Female"])
	base_option.item_selected.connect(func(index):
		draft.set_base(["male", "female"][index])
		_sync()
	)
	var skins: Array = []
	for entry in Catalog.SKINS:
		skins.append(entry.label)
	skin_option = _choice(left_options, "Skin palette", skins)
	skin_option.item_selected.connect(func(index): draft.skin = Catalog.SKINS[index].id; _refresh())
	class_option = _choice(left_options, "Class", Catalog.CLASSES)
	class_option.item_selected.connect(func(index): draft.character_class = Catalog.CLASSES[index]; _refresh())
	var random_button := _button("Random appearance")
	random_button.pressed.connect(func(): draft.randomize_appearance(rng); _sync())
	left_options.add_child(random_button)
	hair_option = _choice(right_options, "Hair style", [])
	hair_option.item_selected.connect(func(index): draft.hair = Catalog.hair_ids(draft.base)[index]; _refresh())
	color_option = _choice(right_options, "Hair color", Catalog.HAIR_COLORS)
	color_option.item_selected.connect(func(index): draft.hair_color = Catalog.HAIR_COLORS[index]; _refresh())
	eye_option = _choice(right_options, "Eyes", Catalog.EYES)
	eye_option.item_selected.connect(func(index): draft.eyes = Catalog.EYES[index]; _refresh())
	preview.status.reparent(right_options)
	preview.status.show()
	center.add_child(_label("Username (locked)" if mirror_mode else "Username"))
	name_field = LineEdit.new()
	name_field.custom_minimum_size.y = 40
	name_field.max_length = 20
	name_field.placeholder_text = "3–20 letters, numbers or _"
	name_field.text_changed.connect(func(value): draft.username = value; _refresh())
	name_field.text_submitted.connect(func(_value): _submit())
	center.add_child(name_field)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	notice = _label("")
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(notice)
	submit = _button("Save appearance" if mirror_mode else ("Begin adventure" if local_guest_mode else ("Validate draft" if development_mode else "Create character")))
	submit.pressed.connect(_submit)
	footer.add_child(submit)
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
	# Focus a fixed header control, never a scrolled option on opening.
	close.grab_focus()
func _surface(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	return style
func _apply_parchment_theme() -> void:
	var ink := Color("382f23")
	theme.set_color("font_color", "Label", ink)
	for kind in ["Button", "OptionButton", "LineEdit"]:
		theme.set_stylebox("normal", kind, _surface(Color("fff9eb"), Color("b28b43")))
		theme.set_stylebox("hover", kind, _surface(Color("f3dfb0"), Color("97732d")))
		theme.set_stylebox("pressed", kind, _surface(Color("e4c987"), Color("846022")))
		theme.set_stylebox("disabled", kind, _surface(Color("e6dfd0"), Color("b6a98c")))
		theme.set_stylebox("read_only", kind, _surface(Color("e6dfd0"), Color("b6a98c")))
		var focus := _surface(Color.TRANSPARENT, Color("8c601c"))
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", kind, focus)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_selected_color"]:
			theme.set_color(state, kind, ink)
		theme.set_color("font_disabled_color", kind, Color("726854"))
		theme.set_color("font_uneditable_color", kind, Color("726854"))
		theme.set_color("font_placeholder_color", kind, Color("81735d"))
		theme.set_color("caret_color", kind, ink)
	theme.set_stylebox("panel", "PopupMenu", _surface(Color("fff9eb"), Color("b28b43")))
	theme.set_stylebox("hover", "PopupMenu", _surface(Color("e4c987"), Color("b28b43")))
	theme.set_color("font_color", "PopupMenu", ink)
	theme.set_color("font_hover_color", "PopupMenu", ink)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(70, 40)
	return button
func _side_column() -> ScrollContainer:
	var side := ScrollContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.follow_focus = false
	columns.add_child(side)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 6)
	side.add_child(options)
	return side
func _choice(parent: VBoxContainer, label: String, items: Array) -> OptionButton:
	parent.add_child(_label(label))
	var control := OptionButton.new()
	control.custom_minimum_size.y = 40
	for item in items:
		control.add_item(str(item))
	control.clip_text = true
	parent.add_child(control)
	control.focus_entered.connect(func(): _reveal_keyboard_focus(control))
	return control
func _sync() -> void:
	base_option.select(0 if draft.base == "male" else 1)
	hair_option.clear()
	for i in range(15):
		hair_option.add_item("%s hair %02d" % [draft.base.capitalize(), i + 1])
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
	notice.text = draft.username_error() if not draft.username.is_empty() else ("Base, class and name are locked." if mirror_mode else "Local guest only. Choose a name to begin." if local_guest_mode else "Choose your appearance and username.")
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
	var available := Rect2(Vector2(8, 8), (size - Vector2(16, 16)).max(Vector2.ONE))
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
	panel.size = available.size.max(Vector2.ONE)
	# No per-frame focus recentering: touch drags must own their scroll position.
	# Username and actions live outside both independently scrollable side lists.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		keyboard_navigation = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventPanGesture:
		keyboard_navigation = false
func _reveal_keyboard_focus(control: Control) -> void:
	if not keyboard_navigation:
		return
	await get_tree().process_frame
	if is_instance_valid(control) and control.has_focus() and keyboard_navigation:
		var side := left_scroll if left_options.is_ancestor_of(control) else right_scroll
		side.ensure_control_visible(control)
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
