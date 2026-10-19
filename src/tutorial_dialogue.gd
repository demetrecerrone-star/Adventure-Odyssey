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
			result.body = "The envelope bears the guild seal, but someone has added a line by hand: ‘You don't have to know every road before taking the first step.’ Your application is approved. The receptionist is expecting you."
			if stage == "awaiting_letter":
				result.choices.append(_choice("read_envelope", "Read the letter"))
		"guild_receptionist":
			match stage:
				"awaiting_letter":
					result.body = "Your first assignment unlocks after the training errands. Start by reading the envelope outside your home, then return here."
				"visit_guild":
					result.body = "You came. I kept your application on top of the pile. Before I send you beyond the gates, let's make sure you can come home again. The blacksmith owes us a free upgrade lesson. Will you visit him, then come back?"
					result.choices.append(_choice("guild_assign_blacksmith", "Begin the blacksmith errand"))
				"visit_blacksmith", "upgrade_blacksmith":
					result.body = "Before I can offer the slime assignment, finish the blacksmith's free +1 lesson. Bring your class weapon from the home chest, collect the lesson supplies, then select and confirm its upgrade. Return here afterward."
				"return_guild_blacksmith":
					result.body = "That edge looks better already. The smith doesn't praise people easily, but he sent word you listened. Next, the apothecary has supplies for you. Take them, then come back here."
					result.choices.append(_choice("guild_after_blacksmith", "Begin the apothecary errand"))
				"visit_apothecary":
					result.body = "The apothecary has your first supply gift. Come back after you've collected it."
				"return_guild_apothecary":
					result.body = "Good. Keep those supplies where you can reach them. There's one last stop: the general store. The keeper asked for you specifically. I think you should hear it from them. Come back afterward."
					result.choices.append(_choice("guild_after_apothecary", "Begin the general store errand"))
				"visit_general_store":
					result.body = "Visit the general store for your last errand. I'll be here when you return."
				"return_guild_general_store":
					result.body = "You're quieter than when you first came in. Whatever the storekeeper gave you, keep it safe. When you're ready, there's a small job in the South Meadow. We can talk it through before you decide."
					result.choices.append(_choice("guild_after_general_store", "Ask about the first assignment"))
				"first_combat_pending":
					result.body = "The herb gatherers need the South Meadow back. Will you clear three slimes for 25 gold? Equip your weapon, then follow gold marks across the west bridge, past home, down the south branch. We can talk about supplies before you go."
					result.choices.append(_choice("guild_assign_first_combat", "Accept: clear the South Meadow"))
					result.choices.append(_choice("field_advice", "What should I know before I leave?", "local"))
				"first_combat_active":
					result.body = "Follow the gold road marks across the west bridge, past home, and down the south branch. They lead to the three South Meadow slimes east of the trail. Equip your weapon from your inventory before fighting, then use Attack when a slime is close. Your class skills and carried potions can help. Only kills after accepting count for this job. Defeat three, then return."
				"return_guild_first_combat":
					result.body = "You made it back. That's the part I was waiting for. You bought the herb gatherers some breathing room. Your first assignment is complete; you've earned these 25 gold."
					result.choices.append(_choice("guild_complete_first_combat", "Complete training • Collect 25 gold"))
				"tutorial_complete":
					result.body = "There's another road that needs you, if you're ready. Two wolves have trapped travelers on the Western Forest trail. Cross the west bridge, take the northern branch, then look east of the wooded bend. Clear both for 40 gold. Bring healing supplies."
					result.choices.append(_choice("guild_assign_forest_patrol", "Accept: Western Forest patrol"))
				"forest_patrol_active":
					result.body = "The Western Forest patrol is still open. Cross the west bridge, follow the northern branch, and look east of the first wooded bend. Defeat two wolves for this assignment, then report back. Step away from their amber attack rings, and use your class skills when you have enough mana. Used potions stay consumed, even if you retry."
				"return_guild_forest":
					result.body = "A traveler came through before you. Said someone finally opened the forest road. I had a feeling it was you. Your 40 gold is ready. Sit a moment before you take on the whole world."
					result.choices.append(_choice("guild_complete_forest_patrol", "Finish patrol • Collect 40 gold"))
				"forest_patrol_complete":
					result.body = "Both guild assignments are complete. Slimes and wolves still roam outside town; they return after a short while. Your 40 gold patrol reward has been paid. Your earned Sigils can buy dyes and blankets at home. Visit your bed to preview them; combat stats stay the same."
		"blacksmith":
			if stage == "visit_blacksmith":
				result.body = "Let me see your hands. New to this, then. Good; you haven't learned bad habits yet. Bring your class weapon from the home chest. I'll provide a free +1 lesson. Take the supplies, then select and confirm the upgrade yourself. A weapon deserves a patient hand."
				result.choices.append(_choice("blacksmith_claim_starter", "Receive free lesson supplies"))
			elif stage == "upgrade_blacksmith":
				result.body = "Your lesson supplies are ready. Open the upgrade service, select your tutorial weapon, and confirm its +1 upgrade. Then report back to the guild."
				result.choices.append(_choice("tutorial_upgrade", "Open upgrade service", "service"))
			elif value.event_receipts.has("blacksmith_upgrade_applied"):
				result.body = "There. Your first upgrade, done by your own hand. Remember the feel of it. A fine weapon won't make every choice for you, but caring for it is a good place to start."
			else:
				result.body = "Welcome. Speak to the guild receptionist when you're ready to begin your training."
			result.choices.append(_choice("blacksmith_shop", "Browse blacksmith services", "service"))
		"apothecary":
			if stage == "visit_apothecary":
				result.body = "The guild sent word. You look as though you forgot to breathe on the way here. Here are five mana potions, on us. Take them, then check back with the receptionist. You don't have to prove anything by going without help."
				result.choices.append(_choice("apothecary_claim_gift", "Receive five mana potions"))
			elif value.action_receipts.has("apothecary_claim_gift"):
				result.body = "You've already collected your first supply gift. I can't give it twice, but I'm glad you came back in one piece. If you need more, we can look through the shelves together."
			else:
				result.body = "Welcome to the apothecary. The guild will send you here when it's time for your supply errand."
			result.choices.append(_choice("apothecary_shop", "Browse apothecary supplies", "service"))
		"shopkeeper":
			if stage == "visit_general_store":
				result.body = "I've been holding this until you were ready. The keeper opens a small cloth bundle, then hesitates. It's a keepsake ring. Not merchandise. It's yours now, if you'd like to take it."
				result.choices.append(_choice("general_store_claim_keepsake", "Receive the keepsake ring"))
				result.choices.append(_choice("keepsake_origin", "Who left it?", "local"))
			elif value.action_receipts.has("general_store_claim_keepsake"):
				result.body = "Keep that ring close. I know an object can't answer all your questions. Still, someone wanted you to have it. That much I can tell you."
				result.choices.append(_choice("keepsake_origin", "Who left it?", "local"))
			else:
				result.body = "Welcome. Have a look around, and speak to the guild receptionist about your training."
			result.choices.append(_choice("general_store_shop", "Browse general store goods", "service"))
		"resident_north_yard":
			result.body = "Off to the guild? I used to take the long way when I was nervous, too. It's just west of these homes, beside the plaza. Look for the blue roofs. They'll be glad you came."
		"resident_plaza_home":
			result.body = "The storekeeper has been watching the door all morning. If you're looking for them, the general store is southwest of the plaza. The green roof belongs to the apothecary. Easy to mix them up on your first day."
		"resident_well":
			result.body = "When the town gets too loud, I come here and listen to the well. You can stay a moment. The roads will still be there when you stand up."
		"guard_northeast_verge":
			result.body = "The northeast gate faces the rocky foothills. No guild work out that way yet. If this is your first day, stay with the marked paths. I'd rather wave you home than go looking for you."
		_:
			result.body = "There is no conversation available here."
	if id in ["guild_receptionist", "blacksmith", "apothecary", "shopkeeper"]:
		result.choices.append(_choice("personal_question", {"guild_receptionist":"What if I'm not ready?", "blacksmith":"Why teach me for free?", "apothecary":"Do you worry about everyone?", "shopkeeper":"Does this ring mean something?"}[id], "local"))
		result.choices.append(_choice("not_now", "Not right now. I'll come back.", "dismiss"))
	return result

static func personal_reply(id: String) -> String:
	match id:
		"guild_receptionist": return "Then we wait. The guild needs people, not promises made out of fear. You can ask questions, prepare at home, or come back later. I'll keep your place. Take the next step when you're ready."
		"blacksmith": return "Someone showed me once. I was all hurry and no sense, and they let me try again. This is how a town keeps going: we teach the next pair of hands."
		"apothecary": return "Only the ones who walk through my door. That's quite enough work. Drink when you need to, step back when you must, and let coming home count as courage too."
		"shopkeeper": return "It meant enough for someone to ask me to keep it safe. I won't pretend I can give you the whole story. You don't have to decide what it means today."
	return ""

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
	# Keep the next action ahead of repeated objective text on short phones.
	content.move_child(choices, 1)
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
	var panel_size := Vector2(minf(858, maxf(0, size.x - 20)), minf(649, maxf(0, size.y - 20)))
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
	close_button.text = "Not right now" if _view.choices.any(func(entry): return entry.kind == "action") else "Leave"
	body_label.text = _view.body
	objective_label.text = ("Status: " if tutorial_state.get("stage") in ["tutorial_complete","forest_patrol_complete"] else "Current errand: ") + _view.objective
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
			elif choice.id == "field_advice":
				body_label.text = "Equip a weapon from your inventory, and use Attack when a creature is close. Skills cost mana; carried potions can help. If you're defeated, a free retry restores health and mana. Used potions stay consumed. Take your time. I'll be here when you return."
			elif choice.id == "personal_question":
				body_label.text = personal_reply(npc_id)
			elif choice.id == "resume_conversation":
				_render()
				return
			# Optional conversation never sends a transactional action. Keep an
			# explicit route back to the briefing without closing the speaker.
			if not _view.choices.any(func(entry): return entry.id == "resume_conversation"):
				var back := _choice("resume_conversation", "Back to what we were discussing", "local")
				_view.choices.append(back)
				var button := _button(back.label, choices)
				button.name = "Choice_resume_conversation"
				button.pressed.connect(_choose.bind(back))
				choices.move_child(button, 0)
			scroll.scroll_vertical = 0
		"dismiss":
			_dismiss()
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
