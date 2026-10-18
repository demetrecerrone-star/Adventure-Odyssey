extends Control
# Read-only presentation: the scene/controller calls Save, then refreshes this
# view after a successful transaction. Closing or asking about the keepsake never
# changes progress. No inventory, currency, upgrade, or persistence code lives here.
signal dismissed
signal action_requested(action_id: String)
signal service_requested(service_id: String)

const Progress = preload("res://src/tutorial_progress.gd")
const Ornate = preload("res://src/ui/ornate_panel.gd")
const INK := Color("35291d")
const MUTED := Color("76664e")
const TITLES := {"resident_north_yard":"Town resident", "resident_plaza_home":"Town resident", "resident_well":"Town resident", "guard_northeast_verge":"Town guard", "envelope":"Guild letter", "guild_receptionist":"Guild receptionist", "blacksmith":"Blacksmith", "apothecary":"Apothecary", "shopkeeper":"General store"}
var npc_id := "guild_receptionist"
var tutorial_state: Dictionary = Progress.initial_state()
var character_class := ""
var panel: Control
var title_label: Label
var body_label: Label
var objective_label: Label
var notice_label: Label
var close_button: Button
var scroll: ScrollContainer
var content: VBoxContainer
var choices: VBoxContainer
var _touch_buttons: Array[Button] = []
var pending := false
var _dismiss_pending := false
var _view: Dictionary = {}

func configure(id: String, value: Dictionary, selected_class: String = "") -> void:
	npc_id = id
	tutorial_state = value.duplicate(true)
	character_class = selected_class
	pending = false
	_dismiss_pending = false
	if is_node_ready():
		_render()

static func describe(id: String, value: Dictionary, _selected_class: String = "") -> Dictionary:
	var result := {"title":TITLES.get(id, "Conversation"), "body":"", "objective":Progress.objective(value), "choices":[]}
	if not Progress.validate_state(value):
		result.body = "Your tutorial progress could not be read. Close this conversation and try loading your save again."
		return result
	var stage: String = value.stage
	match id:
		"envelope":
			result.body = "Your application has been approved. Please visit the Adventurer Guild and introduce yourself to the receptionist."
			if stage == "awaiting_letter":
				result.choices.append(_choice("read_envelope", "Read the letter"))
		"guild_receptionist":
			match stage:
				"awaiting_letter":
					result.body = "If an envelope has arrived at your doorstep, read it before we begin."
				"visit_guild":
					result.body = "Welcome to the Adventurer Guild. Let's get you ready, one errand at a time. First, visit the blacksmith for a free upgrade lesson. Come back to me when you're done."
					result.choices.append(_choice("guild_assign_blacksmith", "Begin the blacksmith errand"))
				"visit_blacksmith", "upgrade_blacksmith":
					result.body = "The blacksmith is expecting you. Finish the weapon upgrade lesson, then come back here."
				"return_guild_blacksmith":
					result.body = "Your first upgrade is done. Next, visit the apothecary for some supplies, then return to me."
					result.choices.append(_choice("guild_after_blacksmith", "Begin the apothecary errand"))
				"visit_apothecary":
					result.body = "The apothecary has your first supply gift. Come back after you've collected it."
				"return_guild_apothecary":
					result.body = "Supplies collected. There's one more stop before your first assignment: visit the general store, then return here."
					result.choices.append(_choice("guild_after_apothecary", "Begin the general store errand"))
				"visit_general_store":
					result.body = "Visit the general store for your last errand. I'll be here when you return."
				"return_guild_general_store":
					result.body = "You've finished your errands. Your first combat assignment is next. Combat isn't available yet, so your training remains in progress."
					result.choices.append(_choice("guild_after_general_store", "Ask about the first assignment"))
				"first_combat_pending":
					result.body = "Your first combat assignment is pending. Combat isn't available yet, and your tutorial is still in progress."
		"blacksmith":
			if stage == "visit_blacksmith":
				result.body = "The guild sent you? Bring the class weapon from your starter chest. I'll supply what you need for its first +1 upgrade. Accept the lesson supplies, then open the upgrade service and perform the upgrade yourself."
				result.choices.append(_choice("blacksmith_claim_starter", "Receive free lesson supplies"))
			elif stage == "upgrade_blacksmith":
				result.body = "Your lesson supplies are ready. Open the upgrade service, select your tutorial weapon, and confirm its +1 upgrade. Then report back to the guild."
				result.choices.append(_choice("tutorial_upgrade", "Open upgrade service", "service"))
			elif value.event_receipts.has("blacksmith_upgrade_applied"):
				result.body = "Your first upgrade is complete. Take good care of that weapon."
			else:
				result.body = "Welcome. Speak to the guild receptionist when you're ready to begin your training."
			result.choices.append(_choice("blacksmith_shop", "Browse blacksmith services", "service"))
		"apothecary":
			if stage == "visit_apothecary":
				result.body = "The guild sent word. Your first gift is five mana potions. Collect them, then return to the receptionist."
				result.choices.append(_choice("apothecary_claim_gift", "Receive five mana potions"))
			elif value.action_receipts.has("apothecary_claim_gift"):
				result.body = "You already have your first supply gift. Travel safely."
			else:
				result.body = "Welcome to the apothecary. The guild will send you here when it's time for your supply errand."
			result.choices.append(_choice("apothecary_shop", "Browse apothecary supplies", "service"))
		"shopkeeper":
			if stage == "visit_general_store":
				result.body = "I've been holding this until you were ready. It's a keepsake ring, and it's yours now."
				result.choices.append(_choice("general_store_claim_keepsake", "Receive the keepsake ring"))
				result.choices.append(_choice("keepsake_origin", "Who left it?", "local"))
			elif value.action_receipts.has("general_store_claim_keepsake"):
				result.body = "Keep that ring close. I've been holding it until you were ready."
				result.choices.append(_choice("keepsake_origin", "Who left it?", "local"))
			else:
				result.body = "Welcome. Have a look around, and speak to the guild receptionist about your training."
			result.choices.append(_choice("general_store_shop", "Browse general store goods", "service"))
		"resident_north_yard":
			result.body = "The Adventurer Guild is just west of these homes, beside the plaza. You'll recognize its blue roofs."
		"resident_plaza_home":
			result.body = "The general store is on the southwest side of the plaza. The apothecary is the shop with the green roof."
		"resident_well":
			result.body = "This little green is a quiet place to rest beside the well. The main paths run around it."
		"guard_northeast_verge":
			result.body = "The northeast gate leads toward the rocky foothills. Keep to the paths through the town gates."
		_:
			result.body = "There is no conversation available here."
	return result

static func _choice(id: String, label: String, kind: String = "action") -> Dictionary:
	return {"id":id, "label":label, "kind":kind}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.12, 0.10, 0.64)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = Ornate.new()
	panel.name = "TutorialDialoguePanel"
	add_child(panel)
	title_label = _label(panel, 25)
	title_label.name = "DialogueSpeaker"
	close_button = _button("Leave", panel)
	close_button.name = "CloseDialogue"
	close_button.pressed.connect(_dismiss)
	close_button.minimum_size_changed.connect(_layout)
	title_label.minimum_size_changed.connect(_layout)
	scroll = ScrollContainer.new()
	scroll.name = "DialogueScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	body_label = _label(content, 19)
	body_label.name = "DialogueText"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label = _label(content, 16)
	objective_label.name = "TutorialObjective"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_color", MUTED)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	content.add_child(choices)
	notice_label = _label(content, 16)
	notice_label.name = "TutorialNotice"
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout)
	_layout()
	_render()
	close_button.grab_focus()

func _setup_theme() -> void:
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/body.ttf")
	theme.default_font_size = 18
	for type in ["Label", "Button"]:
		theme.set_color("font_color", type, INK)
	for key in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(key, "Button", INK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", Ornate.make_button_style())
	theme.set_stylebox("hover", "Button", Ornate.make_button_style(true))
	theme.set_stylebox("pressed", "Button", Ornate.make_button_style(true))
	theme.set_stylebox("disabled", "Button", Ornate.make_button_style(false, true))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("267e88")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	theme.set_stylebox("focus", "Button", focus)

func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	_bind_extra_touch(button)
	return button

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var panel_size := Vector2(minf(780, maxf(0, size.x - 32)), minf(590, maxf(0, size.y - 32)))
	panel.position = (size - panel_size) * 0.5
	panel.size = panel_size
	# Font metrics may increase button minimums; measure them instead of letting
	# Godot silently grow the close control beyond its requested right edge.
	var close_size := Vector2(96, 52).max(close_button.get_combined_minimum_size())
	close_button.position = Vector2(maxf(14, panel_size.x - close_size.x - 24), 20)
	close_button.size = close_size
	title_label.position = Vector2(26, 25)
	title_label.size = Vector2(maxf(0, close_button.position.x - 40), maxf(44, title_label.get_combined_minimum_size().y))
	title_label.clip_text = true
	var body_top := maxf(close_button.position.y + close_button.size.y, title_label.position.y + title_label.size.y) + 16
	scroll.position = Vector2(26, body_top)
	scroll.size = Vector2(maxf(0, panel_size.x - 52), maxf(0, panel_size.y - body_top - 26))

func _render() -> void:
	_view = describe(npc_id, tutorial_state, character_class)
	title_label.text = _view.title
	body_label.text = _view.body
	objective_label.text = "Current errand: " + _view.objective
	notice_label.text = ""
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for choice in _view.choices:
		var button := _button(choice.label, choices)
		button.name = "Choice_" + choice.id
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_choose.bind(choice.duplicate(true)))
		button.disabled = pending
	scroll.scroll_vertical = 0

func _choose(choice: Dictionary) -> void:
	if pending or _dismiss_pending or choice not in _view.choices:
		return
	match choice.kind:
		"local":
			if choice.id == "keepsake_origin":
				body_label.text = "I'll let them tell you that."
		"service":
			set_pending(true)
			service_requested.emit(choice.id)
		"action":
			set_pending(true)
			action_requested.emit(choice.id)

func set_pending(value: bool) -> void:
	pending = value
	if not is_node_ready():
		return
	for button in choices.get_children():
		button.disabled = pending
	# Leave/Back remain usable while an owner-side transaction is resolving.

func show_error(message: String) -> void:
	set_pending(false)
	if is_instance_valid(notice_label):
		notice_label.text = message

func _dismiss() -> void:
	if _dismiss_pending:
		return
	_dismiss_pending = true
	_release_touch_owners()
	dismissed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_PAUSED]: _release_touch_owners()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_dismiss()

func _bind_extra_touch(button: Button) -> void:
	_touch_buttons.append(button)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.index > 0:
			if event.pressed and not event.canceled and not button.disabled and not _dismiss_pending:
				if not button.has_meta("touch_owner"):
					button.set_meta("touch_owner", event.index)
					button.set_meta("touch_start", button.get_global_transform_with_canvas() * event.position)
					button.set_meta("touch_dragged", false)
			elif button.get_meta("touch_owner", -1) == event.index:
				var dragged := bool(button.get_meta("touch_dragged", false))
				_clear_touch_owner(button)
				if not dragged and not event.canceled and not button.disabled and not _dismiss_pending and Rect2(Vector2.ZERO, button.size).has_point(event.position):
					button.pressed.emit()
			button.accept_event()
	)

func _clear_touch_owner(button: Button) -> void:
	for key in ["touch_owner", "touch_start", "touch_dragged"]:
		if button.has_meta(key): button.remove_meta(key)

func _release_touch_owners() -> void:
	for button in _touch_buttons:
		if is_instance_valid(button): _clear_touch_owner(button)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _dismiss_pending: return
	if event is InputEventScreenDrag and event.index > 0:
		for button in _touch_buttons:
			if is_instance_valid(button) and button.get_meta("touch_owner", -1) == event.index:
				if Vector2(button.get_meta("touch_start", event.position)).distance_to(event.position) > 12:
					button.set_meta("touch_dragged", true)
	if event is InputEventScreenTouch and event.index > 0 and not event.pressed:
		for button in _touch_buttons.duplicate():
			if is_instance_valid(button) and button.get_meta("touch_owner", -1) == event.index:
				var dragged := bool(button.get_meta("touch_dragged", false))
				_clear_touch_owner(button)
				var point: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * event.position
				if not dragged and not event.canceled and not button.disabled and button.is_visible_in_tree() and Rect2(Vector2.ZERO, button.size).has_point(point):
					button.pressed.emit()
				get_viewport().set_input_as_handled()
				return
