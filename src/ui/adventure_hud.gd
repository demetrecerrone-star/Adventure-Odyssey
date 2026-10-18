extends Control
# Reusable screen-space HUD. Nothing here owns the world, inventory or progression.
signal menu_requested
signal quest_requested
const OrnatePanel = preload("res://src/ui/ornate_panel.gd")
const Avatar = preload("res://src/layered_avatar.gd")
const BODY_FONT = preload("res://assets/fonts/body.ttf")
const TITLE_FONT = preload("res://assets/fonts/title.ttf")
const INK := Color("362c21")
const MUTED := Color("746349")
var interact_button: Button
var message: Label
var status: Label
var menu_button: Button
var portrait: Control
var portrait_avatar: Node2D
var identity_panel: Control
var map_panel: Control
var quest_panel: Control
var quest_label: Label
var _quest_objective := "Read the envelope at your doorstep."
var vitals_panel: Control
var action_cluster: Control
var interaction_panel: Control
var username_label: Label
var class_label: Label
var progression_label: Label
var location_label: Label
var coordinates_label: Label
var hp_label: Label
var mp_label: Label
var attack_button: Button
var skill_buttons: Array[Button] = []
var potion_button: Button
var layout_safe_rect := Rect2()
var left_handed := false
var _character: Dictionary = {}
var _scene := "Bedroom"
var _world_position := Vector2.ZERO
var _modal_active := false
var _before_modal_interact := false
var _built := false
var _rendered_scene := ""
var _rendered_coordinates := Vector2i(-2147483648, -2147483648)

class Medallion:
	extends Button
	var emblem := "skill"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_theme_color_override("font_color", Color("f4e5ba"))
		add_theme_color_override("font_disabled_color", Color("bdb296"))
		add_theme_font_size_override("font_size", 14)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(center + Vector2(0, 2), radius + 2, Color(0.10, 0.07, 0.03, 0.40))
		draw_circle(center, radius, Color("56564c") if disabled else Color("3a4a40"))
		draw_arc(center, radius, 0, TAU, 64, Color("67491f"), 5, true)
		draw_arc(center, radius - 0.8, 0, TAU, 64, Color("bc9650"), 2.8, true)
		draw_arc(center, radius - 3.5, 0, TAU, 64, Color("e6d49e"), 1, true)
		draw_arc(center, radius - 6, PI * 1.10, TAU * 0.96, 36, Color(1, 0.92, 0.70, 0.18), 1, true)
		if emblem == "potion":
			var ink := Color("c0bda5")
			var bottle := PackedVector2Array([center + Vector2(-4, -12), center + Vector2(4, -12), center + Vector2(4, -6), center + Vector2(9, 0), center + Vector2(8, 10), center + Vector2(-8, 10), center + Vector2(-9, 0), center + Vector2(-4, -6), center + Vector2(-4, -12)])
			draw_colored_polygon(bottle, Color("7d8c7d"))
			draw_polyline(bottle, ink, 1.5, true)
			draw_line(center + Vector2(-5, -13), center + Vector2(5, -13), Color("d3bd8a"), 3, true)
			draw_line(center + Vector2(-6, 3), center + Vector2(6, 3), ink, 1, true)
		elif emblem == "attack":
			var top := center + Vector2(0, -12)
			draw_line(top + Vector2(-8, 8), top + Vector2(9, -9), Color("d2c69e"), 3, true)
			draw_line(top + Vector2(-8, -1), top + Vector2(1, 8), Color("d2c69e"), 2.5, true)
			draw_line(top + Vector2(-12, 12), top + Vector2(-7, 7), Color("c3a05a"), 4, true)
		elif emblem == "menu":
			for y in [-8, 0, 8]:
				draw_line(center + Vector2(-10, y), center + Vector2(10, y), Color("f0dba6"), 3, true)
		# Button draws its native text before this custom face. Repaint captions
		# above the medallion so disabled skills remain identifiable on screen.
		if emblem in ["attack", "skill"]:
			var font := get_theme_font("font")
			var font_size := 14 if emblem == "attack" else 16
			var baseline := center.y + 17.0 if emblem == "attack" else center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
			draw_string(font, Vector2(3, baseline), text.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, font_size, Color("e0d6b9"))

class MapPlaceholder:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var box := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		draw_rect(box, Color("e5dbc0"))
		draw_rect(box, Color("c1ad7b"), false, 1)
		for index in [1, 2, 3]:
			var portion := float(index) / 4.0
			draw_line(Vector2(size.x * portion, 2), Vector2(size.x * portion, size.y - 2), Color(0.50, 0.42, 0.25, 0.12), 1)
			draw_line(Vector2(2, size.y * portion), Vector2(size.x - 2, size.y * portion), Color(0.50, 0.42, 0.25, 0.12), 1)
		var center := size * 0.5
		draw_polyline(PackedVector2Array([center + Vector2(0, -9), center + Vector2(5, 0), center + Vector2(0, 9), center + Vector2(-5, 0), center + Vector2(0, -9)]), Color("9d9279"), 1.4, true)
		draw_line(center + Vector2(-13, 13), center + Vector2(13, -13), Color("9d9279"), 1.4, true)

func _ready() -> void:
	name = "AdventureHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2000
	theme = Theme.new()
	theme.default_font = BODY_FONT
	theme.default_font_size = 15
	_build()
	_built = true
	resized.connect(_layout)
	set_character(_character)
	set_world_position(_scene, _world_position)
	_layout()
	var requested_modal := _modal_active
	_modal_active = false
	set_modal_active(requested_modal)

func _panel(node_name: String, compact: bool = true) -> Control:
	var result = OrnatePanel.new()
	result.name = node_name
	result.compact = compact
	add_child(result)
	return result

func _label(text_value: String, parent: Node, font_size: int = 14, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text_value
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(result)
	return result

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _build() -> void:
	identity_panel = _panel("CharacterIdentity")
	var portrait_frame = OrnatePanel.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.compact = true
	portrait_frame.ornamented = false
	portrait_frame.dark = true
	identity_panel.add_child(portrait_frame)
	_place(portrait_frame, Rect2(9, 9, 74, 82))
	portrait = Control.new()
	portrait.name = "ActualCharacterPortrait"
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	_place(portrait, Rect2(8, 8, 58, 66))
	portrait_avatar = Avatar.new()
	portrait_avatar.name = "SavedAppearance"
	portrait.add_child(portrait_avatar)
	# Original atlas is foot-pivoted at (128, 232); crop to the actual head and shoulders.
	portrait_avatar.scale = Vector2.ONE * 0.90
	portrait_avatar.position = Vector2(29, 174)
	username_label = _label("Guest", identity_panel, 19)
	username_label.add_theme_font_override("font", TITLE_FONT)
	class_label = _label("Class unavailable", identity_panel, 14)
	progression_label = _label("Level / XP unavailable", identity_panel, 12, MUTED)
	status = _label("Local adventure", identity_panel, 11, MUTED)
	status.name = "Status"
	menu_button = Medallion.new()
	menu_button.name = "MenuButton"
	menu_button.emblem = "menu"
	menu_button.tooltip_text = "Open adventure menu"
	menu_button.accessibility_name = "Adventure menu"
	add_child(menu_button)
	menu_button.pressed.connect(func():
		if not _modal_active:
			menu_requested.emit()
	)
	_bind_extra_touch(menu_button)
	map_panel = _panel("WorldLocation")
	location_label = _label("Bedroom", map_panel, 14)
	location_label.add_theme_font_override("font", TITLE_FONT)
	var map_notice := _label("Map unavailable", map_panel, 12, MUTED)
	_place(map_notice, Rect2(26, 36, 125, 19))
	coordinates_label = _label("X 0  ·  Y 0", map_panel, 12, MUTED)
	_place(coordinates_label, Rect2(26, 57, 125, 18))
	var placeholder := MapPlaceholder.new()
	placeholder.name = "MinimapUnavailable"
	map_panel.add_child(placeholder)
	_place(placeholder, Rect2(153, 30, 40, 40))
	quest_panel = _panel("QuestTracker")
	quest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_panel.gui_input.connect(func(event: InputEvent):
		if _modal_active: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			quest_panel.accept_event()
			quest_requested.emit()
	)
	quest_label = _label(_quest_objective, quest_panel, 12, MUTED)
	quest_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_label.tooltip_text = _quest_objective
	quest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(quest_label, Rect2(26, 8, 158, 23))
	quest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vitals_panel = _panel("VitalsUnavailable")
	hp_label = _label("HP unavailable", vitals_panel, 13, MUTED)
	mp_label = _label("MP unavailable", vitals_panel, 13, MUTED)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_cluster = Control.new()
	action_cluster.name = "ActionMedallions"
	action_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(action_cluster)
	# Contextual actions have a dedicated center lane, away from combat targets.
	interaction_panel = Control.new()
	interaction_panel.name = "ContextualInteraction"
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(interaction_panel)
	interact_button = Button.new()
	interact_button.name = "InteractButton"
	interact_button.text = "Interact [E]"
	interact_button.custom_minimum_size = Vector2(160, 52)
	interact_button.clip_text = true
	interact_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	interact_button.mouse_filter = Control.MOUSE_FILTER_STOP
	interact_button.focus_mode = Control.FOCUS_NONE
	interact_button.add_theme_font_size_override("font_size", 16)
	interact_button.add_theme_color_override("font_color", INK)
	interact_button.add_theme_color_override("font_hover_color", INK)
	interact_button.add_theme_color_override("font_pressed_color", INK)
	interact_button.add_theme_color_override("font_disabled_color", MUTED)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		interact_button.add_theme_stylebox_override(state, OrnatePanel.make_button_style(state in ["hover", "pressed"], state == "disabled"))
	interaction_panel.add_child(interact_button)
	_bind_extra_touch(interact_button)
	attack_button = _medallion("\nAttack", "AttackButton", "attack", Rect2(160, 68, 96, 96))
	attack_button.add_theme_constant_override("outline_size", 0)
	for index in range(3):
		var positions := [Vector2(168, 0), Vector2(88, 30), Vector2(78, 98)]
		var skill := _medallion(["I", "II", "III"][index], "Skill%d" % (index + 1), "skill", Rect2(positions[index], Vector2(64, 64)))
		skill.tooltip_text = "Skill %d unavailable. No skill system yet." % (index + 1)
		skill_buttons.append(skill)
	potion_button = _medallion("", "PotionUnavailable", "potion", Rect2(14, 114, 48, 48))
	potion_button.tooltip_text = "Potion use unavailable. No combat system yet."
	var unavailable := _label("Combat unavailable", action_cluster, 12, Color("f0e4c9"))
	unavailable.add_theme_color_override("font_shadow_color", Color("201b13"))
	unavailable.add_theme_constant_override("shadow_offset_y", 1)
	unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(unavailable, Rect2(54, 166, 202, 18))
	message = _label("", self, 14, Color("fff3d7"))
	message.name = "AdventureMessage"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	message.add_theme_color_override("font_shadow_color", Color("171811"))
	message.add_theme_color_override("font_outline_color", Color("292b20"))
	message.add_theme_constant_override("outline_size", 3)
	message.add_theme_constant_override("shadow_offset_y", 1)

func _medallion(text_value: String, node_name: String, emblem: String, rect: Rect2) -> Button:
	var result := Medallion.new()
	result.name = node_name
	result.text = text_value
	result.emblem = emblem
	result.disabled = true
	result.custom_minimum_size = Vector2(44, 44)
	result.tooltip_text = "Attack unavailable. No combat system yet."
	action_cluster.add_child(result)
	_place(result, rect)
	return result

func _bind_extra_touch(button: Button) -> void:
	# Primary-pointer emulation is Godot's normal Button path. Additional fingers
	# can use the HUD while the joystick owns pointer zero; release activates once.
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.index > 0:
			if event.pressed and not event.canceled and not button.disabled and not _modal_active:
				if not button.has_meta("touch_owner"):
					button.set_meta("touch_owner", event.index)
			elif button.get_meta("touch_owner", -1) == event.index:
				button.remove_meta("touch_owner")
				if not event.canceled and not button.disabled and not _modal_active and Rect2(Vector2.ZERO, button.size).has_point(event.position):
					button.pressed.emit()
			button.accept_event()
	)

func set_character(character: Dictionary) -> void:
	_character = character.duplicate(true)
	if not _built:
		return
	username_label.text = str(character.get("username", "Guest"))
	class_label.text = str(character.get("class", "Class unavailable"))
	# The local save has no progression model; never invent a level or XP value.
	progression_label.text = "Level / XP unavailable"
	if character.is_empty():
		portrait_avatar.hide()
	else:
		portrait_avatar.configure(str(character.get("base", "")), str(character.get("class", "")), character)

func configure(character: Dictionary) -> void:
	set_character(character)

func set_world_position(scene: String, world_position: Vector2) -> void:
	_scene = scene
	_world_position = world_position
	if not _built:
		return
	var current_coordinates := Vector2i(roundi(world_position.x), roundi(world_position.y))
	if scene != _rendered_scene:
		_rendered_scene = scene
		var names := {"bedroom":"Bedroom", "starter_region":"Starter region", "guild":"Adventurer Guild", "guild_interior":"Adventurer Guild", "shop_southwest":"General store", "general_store_interior":"General store", "shop_south_plaza":"Apothecary", "apothecary_interior":"Apothecary", "blacksmith_workyard":"Blacksmith", "blacksmith_interior":"Blacksmith"}
		location_label.text = str(names.get(scene, scene.replace("_", " ").capitalize()))
	if current_coordinates != _rendered_coordinates:
		_rendered_coordinates = current_coordinates
		coordinates_label.text = "X %d  ·  Y %d" % [current_coordinates.x, current_coordinates.y]

func update_location(scene: String, world_position: Vector2) -> void:
	set_world_position(scene, world_position)

func set_left_handed(value: bool) -> void:
	left_handed = value
	if _built:
		_layout()

func set_safe_rect(value: Rect2) -> void:
	layout_safe_rect = value
	if _built:
		_layout()

func set_modal_active(value: bool) -> void:
	if value == _modal_active:
		return
	_modal_active = value
	if not _built:
		return
	menu_button.disabled = value
	if value:
		_before_modal_interact = interact_button.disabled
		interact_button.disabled = true
	else:
		interact_button.disabled = _before_modal_interact
	_release_touch_owners()

func _input(event: InputEvent) -> void:
	# Release is tracked globally: dragging off a button must not retain a
	# secondary finger owner or activate it later when the pointer returns.
	if event is InputEventScreenTouch and event.index > 0 and not event.pressed:
		for button in [menu_button, interact_button]:
			if is_instance_valid(button) and button.get_meta("touch_owner", -1) == event.index:
				button.remove_meta("touch_owner")
				var point: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * event.position
				if not event.canceled and not button.disabled and not _modal_active and Rect2(Vector2.ZERO, button.size).has_point(point):
					button.pressed.emit()
				get_viewport().set_input_as_handled()

func _release_touch_owners() -> void:
	for button in [menu_button, interact_button]:
		if is_instance_valid(button) and button.has_meta("touch_owner"):
			button.remove_meta("touch_owner")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_release_touch_owners()

func _layout() -> void:
	if not _built:
		return
	var available := Rect2(Vector2.ZERO, size)
	if layout_safe_rect.has_area():
		available = available.intersection(layout_safe_rect)
	var margin := 12.0
	var compact := available.size.x < 1000
	var identity_width := 276.0 if compact else 302.0
	_place(identity_panel, Rect2(available.position + Vector2(margin, margin), Vector2(identity_width, 100)))
	_place(username_label, Rect2(92, 12, identity_width - 108, 25))
	_place(class_label, Rect2(92, 37, identity_width - 108, 20))
	_place(progression_label, Rect2(92, 57, identity_width - 108, 18))
	_place(status, Rect2(92, 76, identity_width - 108, 16))
	_place(menu_button, Rect2(available.position + Vector2(margin + 8, 118), Vector2(52, 52)))
	_place(map_panel, Rect2(available.position + Vector2(available.size.x - margin - 210, margin), Vector2(210, 87)))
	_place(location_label, Rect2(26, 11, 158, 23))
	_place(quest_panel, Rect2(available.position + Vector2(available.size.x - margin - 210, 105), Vector2(210, 40)))
	var action_size := Vector2(256, 184)
	var action_x := margin if left_handed else available.size.x - margin - action_size.x
	_place(action_cluster, Rect2(available.position + Vector2(action_x, available.size.y - margin - action_size.y), action_size))
	# Both control corners stay reserved, including the 244 px floating joystick.
	# Only combat moves with handedness; context actions stay in the center lane.
	var center_width := clampf(available.size.x - 2.0 * (action_size.x + margin + 12), 140, 340)
	var center_x := available.position.x + (available.size.x - center_width) * 0.5
	_place(vitals_panel, Rect2(center_x, available.end.y - margin - 42, center_width, 42))
	_place(hp_label, Rect2(9, 10, (center_width - 18) * 0.5, 22))
	_place(mp_label, Rect2(center_width * 0.5, 10, (center_width - 18) * 0.5, 22))
	var interaction_width := minf(200, center_width)
	_place(interaction_panel, Rect2(available.position.x + (available.size.x - interaction_width) * 0.5, available.end.y - margin - 106, interaction_width, 52))
	_place(interact_button, Rect2(Vector2.ZERO, interaction_panel.size))
	var message_width := maxf(160, available.size.x - 2.0 * (action_size.x + margin + 12))
	_place(message, Rect2(available.position.x + (available.size.x - message_width) * 0.5, available.end.y - margin - 174, message_width, 58))

func set_tutorial_objective(value: String) -> void:
	_quest_objective = value
	if is_instance_valid(quest_label):
		quest_label.text = value
		quest_label.tooltip_text = value
