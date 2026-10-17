extends Control

const BODY = preload("res://assets/fonts/body.ttf")
const TITLE = preload("res://assets/fonts/title.ttf")
const TEXTURED_PANEL = preload("res://src/textured_panel.gd")
const RUN_TEXTURES = [preload("res://assets/title/skeleton-run.png"), preload("res://assets/title/goblin-run.png")]
const BRASS = Color("b99860")
const INK = Color("181e29")
var background: TextureRect
var menu: Control
var brand: TextureRect
var modal: Control
var modal_panel: Panel
var modal_box: VBoxContainer
var notice: Label
var fields: Array[LineEdit] = []
var buttons: Array[Button] = []
var previous_focus: Control
var modal_kind := ""
var elapsed := 0.0
var runners: Array[AnimatedSprite2D] = []

func _ready() -> void:
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
	var preview := _label("TITLE PREVIEW  •  0.4", 12, Color("e2d5bc"))
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
		modal_panel.size = Vector2(minf(530, safe.size.x), minf(620, safe.size.y))
		modal_panel.position = safe.get_center() - modal_panel.size * 0.5

func open_modal(kind: String) -> void:
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
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28
	scroll.offset_top = 24
	scroll.offset_right = -28
	scroll.offset_bottom = -24
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_panel.add_child(scroll)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 13)
	scroll.add_child(modal_box)
	var headings := {"signin": "Sign In", "create": "Create Account", "google": "Sign in with Google", "guest": "Title Preview"}
	modal_box.add_child(_label(headings[kind], 29, Color("ffe1a5"), TITLE))
	notice = _label("", 17, Color("e6decd"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(notice)
	if kind == "signin" or kind == "create":
		notice.text = "Account services aren't connected in this preview. These fields demonstrate the screen only. Please use dummy details."
		_add_field("Email", false)
		_add_field("Password", true)
		if kind == "create":
			_add_field("Confirm password", true)
		var submit := _button("Create Account" if kind == "create" else "Sign In")
		submit.pressed.connect(_submit_preview)
		modal_box.add_child(submit)
	elif kind == "google":
		notice.text = "Google sign-in isn't connected yet. This title-screen preview doesn't open an account or send any data."
	else:
		notice.text = "You're viewing the first title-screen milestone. The new adventure is still being built.\n\nEnjoy the kingdom view and the chase!"
	var close := _button("Back to Title")
	close.pressed.connect(close_modal)
	modal_box.add_child(close)
	_layout()
	if fields.size() > 0:
		fields[0].grab_focus()
	else:
		close.grab_focus()

func _add_field(caption: String, secret: bool) -> void:
	modal_box.add_child(_label(caption, 15, Color("cfbb98")))
	var field := LineEdit.new()
	field.placeholder_text = caption
	field.secret = secret
	field.custom_minimum_size.y = 46
	field.max_length = 254
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	field.add_theme_stylebox_override("normal", _style(Color("0e1520"), Color("695b47"), 1))
	field.add_theme_stylebox_override("focus", _style(Color("121b2a"), BRASS))
	field.text_submitted.connect(func(_text): _submit_preview())
	modal_box.add_child(field)
	fields.append(field)

func _submit_preview() -> void:
	# No network calls, account creation, authentication, password logging or persistence.
	notice.text = "Preview only: account services aren't available yet. No details have been sent or saved."
	for field in fields:
		field.clear()

func close_modal() -> void:
	if not is_instance_valid(modal):
		return
	for field in fields:
		field.clear()
	fields.clear()
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
		close_modal()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal):
			close_modal()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _setup_runners() -> void:
	# Frame atlases are separate from the painted background and UI.
	for index in range(2):
		var texture: Texture2D = RUN_TEXTURES[index]
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", 10)
		for i in range(4):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(i * texture.get_width() / 4.0, 0, texture.get_width() / 4.0, texture.get_height())
			frames.add_frame("default", frame)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * (0.27 if index == 0 else 0.23)
		sprite.centered = false
		sprite.offset = Vector2(-256, -430)
		sprite.play()
		add_child(sprite)
		move_child(sprite, 1)
		runners.append(sprite)

func _process(delta: float) -> void:
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
