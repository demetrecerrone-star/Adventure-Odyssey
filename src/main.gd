extends Control

const AccountClient = preload("res://src/accounts/firebase_auth.gd")
const AccountDocuments = preload("res://src/accounts/account_documents.gd")
const AccountConfig = preload("res://src/accounts/account_config.gd")
var accounts: Node
var account_submit: Button

const PREVIEW_DOCUMENTS = preload("res://src/preview_documents.gd")
const BODY = preload("res://assets/fonts/body.ttf")
const TITLE = preload("res://assets/fonts/title.ttf")
const TEXTURED_PANEL = preload("res://src/textured_panel.gd")
const RUN_TEXTURES = [preload("res://assets/title/skeleton-run-smooth.png"), preload("res://assets/title/goblin-run-smooth.png")]
const RUN_FRAME_COUNT := 24
const RUN_ATLAS_COLUMNS := 6
const RUN_FRAME_SIZE := 512
const RUN_FPS := 30.0
const BRASS = Color("b99860")
const INK = Color("181e29")
var bedroom: Control
var background: TextureRect
var menu: Control
var brand: TextureRect
var modal: Control
var modal_panel: Panel
var modal_box: VBoxContainer
var notice: Label
var modal_scroll: ScrollContainer
var password_toggles: Array[Button] = []
var legal_controls: Array[Button] = []
var modal_close: Button
var fields: Array[LineEdit] = []
var buttons: Array[Button] = []
var previous_focus: Control
var modal_kind := ""
var legal_return_kind := "create"
var elapsed := 0.0
var runners: Array[AnimatedSprite2D] = []

func _ready() -> void:
	accounts = AccountClient.new()
	accounts.api_key = AccountConfig.WEB_API_KEY if AccountConfig.ENABLED else ""
	add_child(accounts)
	accounts.completed.connect(_account_completed)
	accounts.session_changed.connect(_account_session_changed)
	get_tree().auto_accept_quit = false
	theme = Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 18
	background = TextureRect.new()
	background.texture = preload("res://assets/title/dusk-kingdom-background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var wordmark := TextureRect.new()
	wordmark.texture = preload("res://assets/title/adventure-odyssey-wordmark.png")
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wordmark.position = Vector2(-25, -12)
	wordmark.size = Vector2(400, 171)
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(wordmark)
	var subtitle := _label("YOUR ADVENTURE AWAITS", 13, Color("e2ceac"))
	subtitle.position = Vector2(29, 170)
	menu.add_child(subtitle)
	var names := ["Sign in with Google", "Play as Guest", "Create Account", "Sign In"]
	var actions := ["google", "guest", "create", "signin"]
	for i in range(names.size()):
		var button := _button(names[i])
		button.position = Vector2(0, 214 + i * 64)
		button.size = Vector2(324, 52)
		button.pressed.connect(open_modal.bind(actions[i]))
		menu.add_child(button)
		var texture_overlay := Panel.new()
		texture_overlay.set_script(TEXTURED_PANEL)
		texture_overlay.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		texture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(texture_overlay)
		buttons.append(button)
	var preview := _label("BEDROOM PREVIEW  •  0.7", 12, Color("e2d5bc"))
	preview.position = Vector2(77, 476)
	menu.add_child(preview)
	brand = TextureRect.new()
	brand.texture = preload("res://assets/branding/by-dabsky.png")
	brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brand)
	_setup_runners()
	resized.connect(_layout)
	_layout()
	buttons[0].grab_focus()

func _label(text: String, font_size: int, color: Color, font: Font = BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.025, 0.05, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(color: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	return style

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.add_theme_color_override("font_color", Color("f4ead8"))
	button.add_theme_stylebox_override("normal", _style(INK, BRASS))
	button.add_theme_stylebox_override("hover", _style(Color("303a48"), Color("edcd8c")))
	button.add_theme_stylebox_override("pressed", _style(Color("101721"), Color("fff0b8")))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe7a9")
	focus.set_border_width_all(3)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
	return button

func _safe_rect() -> Rect2:
	var result := Rect2(Vector2(30, 24), size - Vector2(60, 48))
	if OS.has_feature("android"):
		var pixels := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		if pixels.size.x > 0 and pixels.size.y > 0 and screen.x > 0 and screen.y > 0:
			var factor := size / screen
			result = result.intersection(Rect2(Vector2(pixels.position) * factor, Vector2(pixels.size) * factor))
	return result

func _layout() -> void:
	if not is_instance_valid(background):
		return
	background.size = size
	var safe := _safe_rect()
	menu.position = Vector2(safe.position.x + 34, maxf(safe.position.y + 20, size.y * 0.1))
	brand.size = Vector2(180, 60)
	brand.position = Vector2(safe.end.x - brand.size.x, safe.position.y)
	if is_instance_valid(modal):
		modal.size = size
		_layout_modal(_keyboard_safe_rect(safe))

func _keyboard_safe_rect(safe: Rect2) -> Rect2:
	if OS.has_feature("android"):
		var screen := Vector2(DisplayServer.screen_get_size())
		var keyboard_height := DisplayServer.virtual_keyboard_get_height()
		if screen.y > 0 and keyboard_height > 0:
			safe = safe.intersection(Rect2(Vector2.ZERO, Vector2(size.x, size.y - keyboard_height * size.y / screen.y)))
	return safe

func _layout_modal(safe: Rect2) -> void:
	var target_height := 600 if modal_kind == "create" else (620 if modal_kind == "signin" else (650 if modal_kind in ["privacy", "terms"] else 560))
	var target_size := Vector2(minf(510, safe.size.x), minf(target_height, safe.size.y))
	var changed := modal_panel.size != target_size
	modal_panel.size = target_size
	modal_panel.position = safe.get_center() - modal_panel.size * 0.5
	if changed:
		_keep_focused_field_visible()

func _keep_focused_field_visible() -> void:
	# Wait for nested containers to finish reflowing after keyboard changes.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(modal):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and modal_scroll.is_ancestor_of(focused):
		# Work in content-local coordinates. Godot's generic follow-focus
		# offset can overshoot in a stretched, nested canvas.
		var local_top := (modal_box.get_global_transform().affine_inverse() * focused.get_global_transform()).origin.y
		var visible_height := modal_scroll.size.y
		modal_scroll.scroll_vertical = int(maxf(0, local_top - (visible_height - focused.size.y) * 0.5))

func open_modal(kind: String) -> void:
	if kind == "signin" and accounts.signed_in(): kind = "account"
	if is_instance_valid(modal):
		return
	previous_focus = get_viewport().gui_get_focus_owner()
	modal_kind = kind
	for button in buttons:
		button.disabled = true
	modal = Control.new()
	modal.name = "ModalOverlay"
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.065, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	modal_panel = Panel.new()
	modal_panel.set_script(TEXTURED_PANEL)
	modal_panel.add_theme_stylebox_override("panel", _style(INK, BRASS))
	modal.add_child(modal_panel)
	var headings := {"signin": "Sign In", "create": "Create Account", "google": "Sign in with Google", "guest": "Title Preview", "privacy": "Privacy Policy", "terms": "Terms of Use", "account": "Your Account", "reset": "Reset Password"}
	var heading := _label(headings[kind], 27, Color("ffe1a5"), TITLE)
	heading.position = Vector2(24, 22)
	modal_panel.add_child(heading)
	modal_close = _button("×")
	modal_close.tooltip_text = ("Back to Sign In" if legal_return_kind == "signin" else "Back to Create Account") if kind in ["privacy", "terms"] else "Close and return to title"
	modal_close.custom_minimum_size = Vector2(48, 48)
	modal_close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	modal_close.offset_left = -66
	modal_close.offset_right = -18
	modal_close.offset_top = 14
	modal_close.offset_bottom = 62
	modal_close.pressed.connect(_back_from_modal)
	modal_panel.add_child(modal_close)
	modal_scroll = ScrollContainer.new()
	modal_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_scroll.offset_left = 24
	modal_scroll.offset_top = 78
	modal_scroll.offset_right = -24
	modal_scroll.offset_bottom = -20
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.follow_focus = false
	modal_panel.add_child(modal_scroll)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 10)
	modal_scroll.add_child(modal_box)
	notice = _label("", 15, Color("e6decd"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(notice)
	if kind == "signin" or kind == "create":
		notice.text = "Email and password are sent securely to Google Firebase for your Odyssey account. Progress stays on this device; cloud saves are not available." if accounts.configured() else "Preview only • Use dummy details. Account services are not connected."
		_add_field("Email", false)
		_add_field("Password", true)
		if kind == "create":
			_add_field("Confirm password", true)
			_add_legal_preview()
			var sign_in_link := _button("Already registered? Sign In")
			sign_in_link.add_theme_font_size_override("font_size", 15)
			sign_in_link.pressed.connect(_switch_account_modal.bind("signin"))
			modal_box.add_child(sign_in_link)
		else:
			var recovery := _label("Password reset is unavailable in this preview.", 13, Color("cfbb98"))
			recovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			modal_box.add_child(recovery)
			if accounts.configured():
				recovery.text = "Forgot your password?"
				var reset := _button("Request password reset")
				reset.pressed.connect(func(): close_modal(); open_modal("reset"))
				modal_box.add_child(reset)
			var create_link := _button("New here? Create Account")
			create_link.add_theme_font_size_override("font_size", 15)
			create_link.pressed.connect(_switch_account_modal.bind("create"))
			modal_box.add_child(create_link)
			_add_legal_preview()
	elif kind == "reset":
		notice.text = "Firebase will send a password-reset link if an account exists. Your saved adventure will not change."
		_add_field("Email", false)
	elif kind == "account":
		notice.text = "Signed in as " + accounts.email + "\n" + ("Email verified." if accounts.email_verified else "Email not verified yet.") + "\nYour character and progress remain on this device. No cloud backup or account ownership transfer has occurred."
		var play := _button("Continue local adventure")
		play.pressed.connect(_open_bedroom)
		modal_box.add_child(play)
		if not accounts.email_verified:
			var verify := _button("Send verification email")
			verify.pressed.connect(func(): accounts.send_verification())
			modal_box.add_child(verify)
			var recheck := _button("I verified my email • Check again")
			recheck.pressed.connect(func(): accounts.check_account())
			modal_box.add_child(recheck)
		var logout := _button("Sign out • Keep local progress")
		logout.pressed.connect(func(): accounts.sign_out(); close_modal())
		modal_box.add_child(logout)
	elif kind in ["privacy", "terms"]:
		notice.text = "Account feature notice • Draft for review." if accounts.configured() else "Title preview information • No account or agreement is created."
		var document_text: String = (AccountDocuments.PRIVACY if kind == "privacy" else AccountDocuments.TERMS) if accounts.configured() else (PREVIEW_DOCUMENTS.PRIVACY if kind == "privacy" else PREVIEW_DOCUMENTS.TERMS)
		var document := _label(document_text, 15, Color("f4ead8"))
		document.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_box.add_child(document)
	elif kind == "google":
		notice.text = "Google sign-in isn't connected yet. This title-screen preview doesn't open an account or send any data."
	else:
		notice.text = "Start a local guest adventure or continue the bedroom saved on this device. This does not create an online account."
		var begin := _button("Enter local adventure")
		begin.pressed.connect(_open_bedroom)
		modal_box.add_child(begin)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	modal_box.add_child(actions)
	var close := _button(("Back to Sign In" if legal_return_kind == "signin" else "Back to Create Account") if kind in ["privacy", "terms"] else "Back")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_back_from_modal)
	actions.add_child(close)
	if kind in ["signin", "create", "reset"]:
		var submit := _button("Request reset link" if kind == "reset" else "Create Account" if kind == "create" else "Sign In")
		account_submit = submit
		submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		submit.pressed.connect(_submit_preview)
		actions.add_child(submit)
	_layout()
	if fields.size() > 0:
		fields[0].grab_focus()
	elif kind in ["privacy", "terms", "account"]:
		modal_close.grab_focus()
		_reset_modal_scroll.call_deferred()
	else:
		close.grab_focus()

func _add_field(caption: String, secret: bool) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	modal_box.add_child(group)
	group.add_child(_label(caption, 15, Color("cfbb98")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	group.add_child(row)
	var field := LineEdit.new()
	field.placeholder_text = caption
	field.tooltip_text = caption
	field.secret = secret
	field.custom_minimum_size = Vector2(0, 48)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.max_length = 254
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	field.add_theme_color_override("font_color", Color("f4ead8"))
	field.add_theme_stylebox_override("normal", _style(Color("0e1520"), Color("695b47"), 1))
	field.add_theme_stylebox_override("focus", _style(Color("121b2a"), BRASS))
	var index := fields.size()
	field.focus_entered.connect(_keep_focused_field_visible)
	field.text_submitted.connect(func(_text):
		if index + 1 < fields.size():
			fields[index + 1].grab_focus()
		else:
			_submit_preview()
	)
	row.add_child(field)
	fields.append(field)
	if secret:
		var toggle := _button("Show")
		toggle.custom_minimum_size = Vector2(80, 48)
		toggle.add_theme_font_size_override("font_size", 15)
		toggle.toggle_mode = true
		toggle.tooltip_text = "Show " + caption.to_lower()
		toggle.toggled.connect(func(visible_password: bool):
			field.secret = not visible_password
			toggle.text = "Hide" if visible_password else "Show"
			toggle.tooltip_text = ("Hide " if visible_password else "Show ") + caption.to_lower()
		)
		row.add_child(toggle)
		password_toggles.append(toggle)

func _add_legal_preview() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	modal_box.add_child(row)
	for caption in ["Privacy Policy", "Terms of Use"]:
		var link := _button(caption)
		link.custom_minimum_size.y = 48
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.add_theme_font_size_override("font_size", 14)
		link.add_theme_stylebox_override("disabled", _style(Color("161d28"), Color("695b47"), 1))
		link.add_theme_color_override("font_disabled_color", Color("b6ac98"))
		link.tooltip_text = "Read preview " + caption.to_lower()
		link.pressed.connect(_open_legal_document.bind("privacy" if caption == "Privacy Policy" else "terms"))
		row.add_child(link)
		legal_controls.append(link)
	var explanation := _label("Read how optional accounts use Firebase. Progress remains local." if accounts.configured() else "Read about this preview. No account or agreement is created.", 13, Color("cfbb98"))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(explanation)

func _switch_account_modal(kind: String) -> void:
	var email := fields[0].text.strip_edges() if not fields.is_empty() else ""
	close_modal()
	open_modal(kind)
	fields[0].text = email
	if not email.is_empty():
		fields[1].grab_focus()

func _open_legal_document(kind: String) -> void:
	# Never retain draft credentials while viewing a document.
	legal_return_kind = modal_kind if modal_kind in ["signin", "create"] else "create"
	close_modal()
	open_modal(kind)

func _back_from_modal() -> void:
	var was_document := modal_kind in ["privacy", "terms"]
	close_modal()
	if was_document:
		open_modal(legal_return_kind)

func _validation_error(message: String, index: int) -> void:
	notice.text = message
	notice.add_theme_color_override("font_color", Color("ffcbac"))
	fields[index].grab_focus()
	modal_scroll.scroll_vertical = 0

func _submit_preview() -> void:
	if accounts.configured():
		_submit_account()
		return
	# UI validation only. No network calls, account creation, logging or persistence.
	var email := fields[0].text.strip_edges()
	var email_pattern := RegEx.new()
	email_pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	if email_pattern.search(email) == null:
		_validation_error("Enter a valid email address, such as hero@example.com.", 0)
		return
	if fields[1].text.is_empty():
		_validation_error("Enter a dummy password to check this preview form.", 1)
		return
	if modal_kind == "create" and fields[1].text.length() < 8:
		_validation_error("Use at least 8 characters for this preview password.", 1)
		return
	if modal_kind == "create" and fields[1].text != fields[2].text:
		_validation_error("Your passwords don't match. Try again.", 2)
		return
	notice.add_theme_color_override("font_color", Color("e6decd"))
	notice.text = "Fields checked. Account services aren't available yet. No account was created and no details were sent or saved."
	for field in fields:
		field.clear()
	for toggle in password_toggles:
		toggle.button_pressed = false
	fields[0].grab_focus()
	modal_scroll.scroll_vertical = 0

func _on_registration_succeeded(registered_email: String) -> void:
	# Reserved for a real backend success callback. Local preview validation
	# must never call this or simulate successful registration.
	if modal_kind != "create" or not is_instance_valid(modal):
		return
	close_modal()
	open_modal("signin")
	fields[0].text = registered_email.strip_edges()
	fields[1].grab_focus()

func close_modal() -> void:
	if is_instance_valid(accounts): accounts.cancel()
	if not is_instance_valid(modal):
		return
	for field in fields:
		field.clear()
	fields.clear()
	password_toggles.clear()
	legal_controls.clear()
	DisplayServer.virtual_keyboard_hide()
	remove_child(modal)
	modal.queue_free()
	modal = null
	modal_kind = ""
	for button in buttons:
		button.disabled = false
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()
	else:
		buttons[0].grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(modal):
		_back_from_modal()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal):
			_back_from_modal()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _setup_runners() -> void:
	# Texture-preserving articulated cycles: contact, compression, passing, swing.
	# 24 unique poses in a 6 x 4 atlas; 0.8 seconds per complete two-step cycle.
	for index in range(2):
		var texture: Texture2D = RUN_TEXTURES[index]
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", RUN_FPS)
		for i in range(RUN_FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2((i % RUN_ATLAS_COLUMNS) * RUN_FRAME_SIZE, (i / RUN_ATLAS_COLUMNS) * RUN_FRAME_SIZE, RUN_FRAME_SIZE, RUN_FRAME_SIZE)
			frames.add_frame("default", frame)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * (0.27 if index == 0 else 0.23)
		sprite.centered = false
		sprite.offset = Vector2(-256, -430)
		sprite.play()
		sprite.frame = index * 6 # Goblin and pursuer have independent stride phases.
		add_child(sprite)
		move_child(sprite, 1)
		runners.append(sprite)

func _process(delta: float) -> void:
	if is_instance_valid(modal) and OS.has_feature("android"):
		_layout()
	elapsed += delta
	for i in range(runners.size()):
		var x := fmod(elapsed * 112 + size.x * 0.55, size.x + 420) - 200 + i * 150
		var image_size := background.texture.get_size()
		var image_scale := maxf(size.x / image_size.x, size.y / image_size.y)
		var painted_size := image_size * image_scale
		var painted_origin := (size - painted_size) * 0.5
		var u := clampf((x - painted_origin.x) / painted_size.x, 0.0, 1.0)
		var road_y := painted_origin.y + painted_size.y * (0.805 + 0.04 * sin(u * PI))
		runners[i].position = Vector2(x, road_y)

func _open_bedroom() -> void:
	if is_instance_valid(bedroom): return
	close_modal()
	for button in buttons: button.disabled = true
	_install_adventure(preload("res://src/bedroom.gd").new())
	if bedroom.state.location.scene == "starter_region" and not bedroom.state.character.is_empty():
		_open_world.call_deferred()
	elif bedroom.state.location.scene.ends_with("_interior") and not bedroom.state.character.is_empty():
		_open_interior.call_deferred(bedroom.state.location.scene)

func _install_adventure(next: Control) -> void:
	if is_instance_valid(bedroom):
		remove_child(bedroom)
		bedroom.queue_free()
	bedroom = next
	bedroom.exited.connect(func():
		if not is_instance_valid(bedroom): return
		remove_child(bedroom)
		bedroom.queue_free()
		bedroom = null
		for button in buttons: button.disabled = false
		buttons[1].grab_focus()
	)
	bedroom.world_requested.connect(_open_world)
	add_child(bedroom)
	bedroom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _open_world() -> void:
	if not is_instance_valid(bedroom): return
	var world = preload("res://src/starter_world.gd").new()
	world.state = bedroom.state
	world.returned.connect(_return_bedroom)
	world.interior_requested.connect(_open_interior)
	_install_adventure(world)

func _return_bedroom() -> void:
	var room = preload("res://src/bedroom.gd").new()
	room.state = bedroom.state
	_install_adventure(room)
	room.player = Vector2(780,440)
	room._update_actor()

func _open_interior(scene_id:String) -> void:
	if not is_instance_valid(bedroom): return
	var room = preload("res://src/town_interior.gd").new()
	if not room.available(scene_id):
		room.free()
		return
	room.room_id = scene_id
	room.state = bedroom.state
	_install_adventure(room)

func _submit_account() -> void:
	if accounts.busy or fields.is_empty(): return
	var address := fields[0].text.strip_edges()
	if modal_kind == "create" and fields[1].text != fields[2].text:
		_validation_error("Your passwords don't match. Try again.", 2)
		return
	var started := false
	if modal_kind == "reset":
		started = accounts.reset_password(address)
	else:
		var password := fields[1].text
		started = accounts.create_account(address, password) if modal_kind == "create" else accounts.sign_in(address, password)
		for index in range(1, fields.size()): fields[index].clear()
		for toggle in password_toggles: toggle.button_pressed = false
	if started:
		notice.text = "Connecting securely… You can cancel with Back."
		account_submit.disabled = true

func _account_completed(op: String, ok: bool, message: String) -> void:
	if not is_instance_valid(modal): return
	if is_instance_valid(account_submit): account_submit.disabled = false
	if ok and op in ["signin", "create", "verify", "lookup"]:
		close_modal()
		open_modal("account")
		notice.text += "\n" + message
		return
	notice.text = message

func _account_session_changed() -> void:
	if is_instance_valid(modal) and modal_kind == "account" and not accounts.signed_in():
		close_modal()
		open_modal("signin")
		notice.text = "Your session ended. Sign in again, or continue your local adventure as Guest."
	if buttons.size() >= 4:
		buttons[3].text = "Your Account" if accounts.signed_in() else "Sign In"

func _reset_modal_scroll() -> void:
	await get_tree().process_frame
	if is_instance_valid(modal_scroll) and modal_kind in ["account", "privacy", "terms"]:
		modal_scroll.scroll_vertical = 0
