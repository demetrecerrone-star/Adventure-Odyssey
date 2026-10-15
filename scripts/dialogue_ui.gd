extends Control
## Shared dialogue presentation. The tutorial and NPC conversation modes have
## deliberately different layouts but use one consistent, phone-friendly API.
signal finished

var mode: String = "tutorial"
var chapter: String = ""
var pages: Array[String] = []
var page_index: int = 0
var npc_name: String = ""
var npc_role: String = ""
var npc_portrait_path: String = ""
var npc_advice: String = ""
var showing_advice: bool = false
var reveal_clock: float = 0.0
var body_label: Label
var title_label: Label
var primary_button: Button
var secondary_button: Button

func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func configure_tutorial(section: String, slides: Array[String]) -> void:
	mode = "tutorial"
	chapter = section
	pages = slides.duplicate()
	page_index = 0
	showing_advice = false
	_render()

func configure_npc(who: String, role: String, portrait_path: String, opening: String, advice: String) -> void:
	mode = "npc"
	npc_name = who
	npc_role = role
	npc_portrait_path = portrait_path
	npc_advice = advice
	pages = [opening]
	page_index = 0
	showing_advice = false
	_render()

func _label(text_value: String, rect: Rect2, font_size: int, color: Color, centered: bool = false) -> Label:
	var item = Label.new()
	item.text = text_value
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	return item

func _button(text_value: String, rect: Rect2, handler: Callable, subtle: bool = false) -> Button:
	var item = Button.new()
	item.text = text_value
	item.position = rect.position
	item.size = rect.size
	item.focus_mode = Control.FOCUS_ALL
	item.add_theme_font_size_override("font_size", 21)
	item.add_theme_color_override("font_color", Color("#f7e5c0"))
	item.add_theme_color_override("font_hover_color", Color("#ffffff"))
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#314352") if subtle else (Color("#266a74") if mode == "tutorial" else Color("#76563d"))
	normal.border_color = Color("#69838d") if subtle else Color("#c7aa77")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(9)
	var hovered = normal.duplicate()
	hovered.bg_color = Color("#4b7c86") if mode == "tutorial" else Color("#98734e")
	var pressed = normal.duplicate()
	pressed.bg_color = Color("#243943")
	item.add_theme_stylebox_override("normal", normal)
	item.add_theme_stylebox_override("hover", hovered)
	item.add_theme_stylebox_override("pressed", pressed)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item.pressed.connect(handler)
	add_child(item)
	return item

func _render() -> void:
	for child in get_children():
		child.queue_free()
	reveal_clock = 0.0
	if mode == "tutorial":
		_render_tutorial()
	else:
		_render_npc()
	queue_redraw()

func _render_tutorial() -> void:
	title_label = _label("ADVENTURER'S JOURNAL", Rect2(188, 428, 540, 46), 31, Color("#f2d399"))
	_label(chapter.to_upper(), Rect2(583, 437, 499, 30), 16, Color("#b4dedb"), true)
	_label("GUIDE", Rect2(174, 519, 130, 29), 18, Color("#d8b979"), true)
	_label("%02d" % (page_index + 1), Rect2(184, 551, 111, 69), 54, Color("#f2dfb3"), true)
	_label("%02d / %02d" % [page_index + 1, pages.size()], Rect2(716, 651, 123, 35), 18, Color("#a6c8c8"), true)
	body_label = _label(pages[page_index] if not pages.is_empty() else "", Rect2(350, 500, 765, 104), 25, Color("#fff1d7"))
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.visible_characters = 0
	_label("Tap NEXT to reveal or advance the story.", Rect2(349, 609, 545, 27), 16, Color("#a9bdb9"))
	secondary_button = _button("SKIP", Rect2(846, 639, 122, 49), _on_secondary, true)
	primary_button = _button("LET'S GO" if page_index == pages.size() - 1 else "NEXT  >", Rect2(980, 634, 156, 56), _on_primary)

func _render_npc() -> void:
	title_label = _label(npc_name, Rect2(301, 443, 533, 51), 30, Color("#f5dcae"))
	_label(npc_role.to_upper(), Rect2(828, 453, 314, 30), 18, Color("#acd5d8"), true)
	_label("CONVERSATION", Rect2(124, 453, 139, 29), 14, Color("#e7c68d"), true)
	var portrait = TextureRect.new()
	portrait.position = Vector2(119, 498)
	portrait.size = Vector2(138, 146)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(npc_portrait_path):
		portrait.texture = load(npc_portrait_path)
	add_child(portrait)
	var words = npc_advice if showing_advice else pages[0]
	body_label = _label(words, Rect2(307, 520, 827, 99), 23, Color("#f8eddb"))
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.visible_characters = 0
	_label("ELMWATCH  /  LOCAL CHAT", Rect2(295, 641, 293, 30), 15, Color("#94b2b7"))
	secondary_button = _button("GOODBYE", Rect2(785, 637, 166, 55), _on_secondary, true)
	primary_button = _button("BACK" if showing_advice else "ASK FOR ADVICE", Rect2(966, 637, 206, 55), _on_primary)

func _draw() -> void:
	# Transparent vignette retains the player's sense of place.
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.025, 0.045, 0.26))
	if mode == "tutorial":
		draw_rect(Rect2(121, 431, 1041, 270), Color(0.0, 0.0, 0.0, 0.44))
		draw_rect(Rect2(115, 423, 1041, 267), Color("#101e29"))
		draw_rect(Rect2(118, 426, 1035, 261), Color("#38474c"))
		draw_rect(Rect2(122, 430, 1027, 253), Color("#152a32"))
		draw_rect(Rect2(131, 434, 9, 243), Color("#cfab70"))
		draw_rect(Rect2(145, 481, 987, 2), Color("#6b817c"))
		draw_rect(Rect2(323, 494, 2, 139), Color("#54747a"))
		draw_circle(Vector2(240, 568), 57, Color("#344653"))
		draw_arc(Vector2(240, 568), 53, 0.0, TAU, 42, Color("#b9a06c"), 3.0)
		draw_line(Vector2(240, 525), Vector2(240, 610), Color("#d2b881"), 3.0)
		draw_line(Vector2(196, 568), Vector2(284, 568), Color("#d2b881"), 3.0)
		draw_circle(Vector2(240, 568), 9, Color("#d9c18a"))
		draw_rect(Rect2(349, 601, 765, 2), Color("#3a555a"))
	else:
		draw_rect(Rect2(80, 428, 1131, 273), Color(0.0, 0.0, 0.0, 0.47))
		draw_rect(Rect2(72, 421, 1136, 275), Color("#18232d"))
		draw_rect(Rect2(76, 425, 1128, 267), Color("#936f48"))
		draw_rect(Rect2(81, 430, 1118, 257), Color("#162b39"))
		draw_rect(Rect2(87, 436, 1107, 6), Color("#c7a976"))
		draw_rect(Rect2(106, 489, 163, 166), Color("#c6a976"))
		draw_rect(Rect2(111, 494, 153, 156), Color("#263e4c"))
		draw_rect(Rect2(291, 505, 875, 128), Color("#0e202b"))
		draw_rect(Rect2(297, 511, 863, 117), Color("#283c46"))
		draw_colored_polygon(PackedVector2Array([Vector2(294, 552), Vector2(278, 561), Vector2(294, 573)]), Color("#283c46"))
		draw_rect(Rect2(284, 490, 886, 2), Color("#65878d"))

func _process(delta: float) -> void:
	if body_label == null or not is_instance_valid(body_label):
		return
	if body_label.visible_characters < 0:
		return
	reveal_clock += delta
	var count = int(reveal_clock * 53.0)
	if count >= body_label.text.length():
		body_label.visible_characters = -1
	else:
		body_label.visible_characters = count

func _reveal_remaining() -> bool:
	if body_label != null and is_instance_valid(body_label) and body_label.visible_characters >= 0 and body_label.visible_characters < body_label.text.length():
		body_label.visible_characters = -1
		return true
	return false

func _on_primary() -> void:
	if _reveal_remaining():
		return
	if mode == "tutorial":
		if page_index < pages.size() - 1:
			page_index += 1
			_render()
		else:
			finished.emit()
	else:
		showing_advice = not showing_advice
		_render()

func _on_secondary() -> void:
	finished.emit()
