extends Control
# Original, code-native ornament. The approved concept is a visual reference only.
# Place ordinary controls above this background; it supplies no content margins.
const PARCHMENT := Color("f1e6cd")
const INK := Color("35291d")
const GOLD := Color("bb8b39")
const TURQUOISE := Color("238b98")
var compact := false:
	set(value):
		compact = value
		queue_redraw()
var ornamented := true:
	set(value):
		ornamented = value
		queue_redraw()
var dark := false:
	set(value):
		dark = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

static func make_button_style(active: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead7a8") if active else Color("f0e3c8")
	style.border_color = Color("b08c4e") if disabled else Color("b88832")
	if disabled:
		style.bg_color = Color("d8cfba")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.15, 0.1, 0.04, 0.20)
	style.shadow_size = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _outline(rect: Rect2, bevel: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([Vector2(a.x + bevel, a.y), Vector2(b.x - bevel, a.y), Vector2(b.x, a.y + bevel), Vector2(b.x, b.y - bevel), Vector2(b.x - bevel, b.y), Vector2(a.x + bevel, b.y), Vector2(a.x, b.y - bevel), Vector2(a.x, a.y + bevel), Vector2(a.x + bevel, a.y)])

func _draw() -> void:
	if size.x < 20 or size.y < 20:
		return
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var bevel := 10.0 if compact else 15.0
	var edge := _outline(rect, bevel)
	var shadow := _outline(Rect2(rect.position + Vector2(0, 3), rect.size), bevel)
	draw_colored_polygon(shadow, Color(0.10, 0.065, 0.025, 0.42))
	draw_colored_polygon(edge, Color("283735") if dark else PARCHMENT)
	# Very restrained parchment fibers and small damask-like motifs.
	for y in range(15, int(size.y) - 12, 5):
		draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color(0.38, 0.27, 0.09, 0.025), 1)
	if not compact:
		for y in range(40, int(size.y) - 25, 48):
			for x in range(32, int(size.x) - 20, 56):
				var p := Vector2(x + (12 if y % 96 == 40 else 0), y)
				draw_polyline(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(0, -7), p + Vector2(4, 0), p + Vector2(0, 7), p + Vector2(-4, 0)]), Color(0.50, 0.36, 0.14, 0.065), 1, true)
	# Layered dark bevel, warm gold, and narrow high edge create a raised rim.
	draw_polyline(edge, Color("62401b"), 7, true)
	draw_polyline(edge, Color("bc8935"), 4.5, true)
	draw_polyline(_outline(rect.grow(-1.6), maxf(4, bevel - 1)), Color("fff0b2"), 1.3, true)
	draw_polyline(_outline(rect.grow(-5), maxf(3, bevel - 3)), Color("b69252"), 1, true)
	draw_line(Vector2(20, 10), Vector2(size.x - 20, 10), Color(1, 0.98, 0.85, 0.54), 1, true)
	if ornamented:
		var extent := 19.0 if compact else 30.0
		_corner(Vector2(5, 5), Vector2(1, 1), extent)
		_corner(Vector2(size.x - 5, 5), Vector2(-1, 1), extent)
		_corner(Vector2(5, size.y - 5), Vector2(1, -1), extent)
		_corner(Vector2(size.x - 5, size.y - 5), Vector2(-1, -1), extent)
		if size.x > 140:
			_gem(Vector2(size.x * 0.5, 4), 6.0 if compact else 8.0)
			if not compact:
				_gem(Vector2(size.x * 0.5, size.y - 4), 6)

func _corner(origin: Vector2, direction: Vector2, extent: float) -> void:
	var points := PackedVector2Array()
	for point in [Vector2(0, 19), Vector2(6, 13), Vector2(4, 5), Vector2(13, 6), Vector2(19, 0), Vector2(16, 10), Vector2(25, 16), Vector2(14, 15), Vector2(15, 25), Vector2(10, 16), Vector2(0, 19)]:
		points.append(origin + point * direction * (extent / 25.0))
	draw_colored_polygon(points, Color("c39b4d"))
	draw_polyline(points, Color("715024"), 1.5, true)
	var highlight := PackedVector2Array()
	for point in [Vector2(5, 17), Vector2(9, 12), Vector2(7, 7), Vector2(12, 9), Vector2(17, 5)]:
		highlight.append(origin + point * direction * (extent / 25.0))
	draw_polyline(highlight, Color("ffecaa"), 1.5, true)

func _gem(center: Vector2, radius: float) -> void:
	var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
	draw_colored_polygon(diamond, Color("16707e"))
	draw_polyline(diamond, Color("6d481a"), 4, true)
	draw_polyline(diamond, Color("f2d47d"), 1.7, true)
	draw_polyline(PackedVector2Array([center + Vector2(-radius * 0.5, 0), center + Vector2(0, -radius * 0.5), center + Vector2(radius * 0.5, 0)]), Color("9be0d8"), 1.5, true)
