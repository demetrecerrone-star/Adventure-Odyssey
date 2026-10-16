extends Node2D
# Adventure Odyssey: walkable starter cottage common rooms.
# Original painted room files can be placed at the paths below without
# changing this scene or replacing the bedroom's independent furniture.
const ROOM_IMAGES = {
    "foyer": "res://assets/home/foyer.png",
    "living": "res://assets/home/living_room_kitchen.png"
}
var room_kind: String = "foyer"
var background: Sprite2D

func configure(kind: String) -> void:
    room_kind = kind

func _ready() -> void:
    var path: String = ROOM_IMAGES.get(room_kind, "")
    if ResourceLoader.exists(path):
        var texture: Texture2D = load(path)
        if texture != null:
            background = Sprite2D.new()
            background.name = "HouseInteriorImage"
            background.texture = texture
            background.centered = false
            background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            background.scale = Vector2(2048.0 / texture.get_width(), 1280.0 / texture.get_height())
            add_child(background)
            return
    # Until the exact approved painting is imported, display a navigable
    # illustrated fallback rather than an empty or broken room.
    queue_redraw()

func _rect(x: float, y: float, w: float, h: float, color: String) -> void:
    draw_rect(Rect2(x, y, w, h), Color(color))

func _frame(x: float, y: float, w: float, h: float, border: String, center: String, inset: float = 13.0) -> void:
    _rect(x, y, w, h, border)
    _rect(x + inset, y + inset, w - inset * 2, h - inset * 2, center)

func _rug(x: float, y: float, w: float, h: float) -> void:
    _frame(x, y, w, h, "#402c29", "#a57846", 10)
    _frame(x + 22, y + 22, w - 44, h - 44, "#dab066", "#315a41", 10)
    _frame(x + 46, y + 46, w - 92, h - 92, "#9d7441", "#406849", 9)
    for row in range(4):
        for col in range(5):
            var cx: float = x + 90 + col * max(15.0, (w - 180) / 4.0)
            var cy: float = y + 75 + row * max(15.0, (h - 150) / 3.0)
            draw_circle(Vector2(cx, cy), 7, Color("#bf9655"))

func _plant(x: float, y: float) -> void:
    _frame(x - 32, y - 10, 64, 56, "#382c29", "#90613b", 7)
    for p in [Vector2(-29, -24), Vector2(24, -23), Vector2(-11, -49), Vector2(13, -43), Vector2(0, -19)]:
        draw_circle(Vector2(x, y) + p, 28, Color("#315941"))
    draw_circle(Vector2(x - 8, y - 22), 14, Color("#4e7e4b"))

func _floor() -> void:
    _rect(0, 0, 2048, 1280, "#151b20")
    _frame(250, 112, 1548, 1080, "#302427", "#865739", 44)
    for row in range(34):
        var py: float = 190 + row * 29
        _rect(304, py, 1444, 3, "#68472f")
        for col in range(8):
            var px: float = 326 + col * 185 + (92 if row % 2 else 0)
            if px < 1740:
                _rect(px, py + 5, 3, 21, "#70472e")
    _rect(266, 134, 1516, 108, "#56413b")
    _rect(288, 154, 1472, 43, "#bc9064")
    _rect(266, 1100, 1516, 62, "#51372c")
    for px in [290, 625, 1015, 1455, 1720]:
        _frame(px, 116, 48, 1046, "#44322c", "#89603c", 10)
    # Small brass lamps on the upper timber beam.
    for px in [486, 1595]:
        draw_circle(Vector2(px, 205), 38, Color("#e5a84d"))
        draw_circle(Vector2(px, 205), 19, Color("#ffe0a3"))

func _door(x: float, y: float, w: float, h: float, heading: String = "up") -> void:
    _frame(x, y, w, h, "#3d2923", "#a4774a", 14)
    _frame(x + 23, y + 16, w - 46, h - 32, "#b8864f", "#493631", 9)
    draw_circle(Vector2(x + w - 42, y + h / 2.0), 8, Color("#f4d28d"))

func _draw() -> void:
    if background != null:
        return
    _floor()
    if room_kind == "foyer":
        _door(923, 119, 207, 156)
        _door(916, 1070, 220, 111)
        _door(1635, 603, 149, 215)
        _rug(613, 435, 818, 536)
        _frame(395, 349, 162, 151, "#44332d", "#ad794e")
        _rect(428, 368, 99, 101, "#d3bd8e")
        _rect(456, 378, 45, 75, "#5c875f")
        _frame(1493, 329, 136, 173, "#473329", "#a7774b")
        _frame(356, 708, 175, 193, "#352723", "#905e3b")
        _plant(533, 315)
        _plant(1528, 911)
        _plant(427, 961)
        _plant(1550, 324)
        _frame(771, 250, 495, 94, "#503b2d", "#c5a26d")
        for col in range(5):
            _rect(811 + col * 95, 268, 50, 59, "#6e5140")
    else:
        _door(259, 611, 157, 221)
        _rug(674, 529, 716, 474)
        # Hearth and mantel left side; green sofas around a warm living room.
        _frame(444, 286, 300, 213, "#4a3d37", "#9f8573", 17)
        _frame(498, 341, 193, 130, "#48342d", "#d67031", 14)
        draw_circle(Vector2(597, 395), 57, Color("#ffb14a"))
        _frame(482, 553, 165, 222, "#332e28", "#426149")
        _frame(458, 804, 208, 177, "#332e28", "#416449")
        _frame(876, 660, 285, 212, "#5b3c2d", "#a5794f")
        _rect(907, 686, 223, 33, "#436846")
        _plant(699, 304)
        # Kitchen wall units, sink, stove, hanging utensils and worktop.
        _frame(1251, 276, 436, 158, "#4c342a", "#b18b5a")
        _frame(1263, 448, 421, 194, "#4b342a", "#896246")
        _frame(1320, 465, 147, 120, "#4b5f60", "#aebcb6")
        _rect(1374, 480, 25, 29, "#607f89")
        _frame(1507, 478, 147, 129, "#4b342a", "#484447")
        for col in range(4):
            draw_circle(Vector2(1542 + col * 30, 530), 12, Color("#282c32"))
        _frame(1490, 692, 180, 191, "#4f342a", "#94704c")
        _plant(1541, 978)
        _plant(502, 1012)
