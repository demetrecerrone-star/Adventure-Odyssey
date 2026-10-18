extends Control
# Only a press inside this control can claim it. Other fingers remain free for UI.
# Fixed: size is the pad rectangle (the original 164px default).
# Floating: size is the bounded activation zone; its placement belongs to the HUD.
# Call set_input_enabled(false) before opening a modal, true when it closes.
# Both configure() and reset() release pointers and emit an immediate zero vector.
signal direction_changed(value: Vector2)
const RADIUS := 62.0
const DEADZONE := 0.16
const FIXED_SIZE := Vector2(164, 164)
const PAD_MARGIN := 88.0
var owner_index := -1
var mouse_owned := false
var direction := Vector2.ZERO
var knob := Vector2.ZERO
var mode := "fixed"
var input_enabled := true
var _floating_origin := Vector2.ZERO
var _press_origin := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(PAD_MARGIN * 2, PAD_MARGIN * 2) if mode == "floating" else FIXED_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP if input_enabled else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	item_rect_changed.connect(_on_control_rect_changed)
	set_notify_local_transform(true)
	queue_redraw()

func configure(next_mode: String) -> bool:
	if next_mode not in ["fixed", "floating"]:
		return false
	mode = next_mode
	custom_minimum_size = Vector2(PAD_MARGIN * 2, PAD_MARGIN * 2) if mode == "floating" else FIXED_SIZE
	reset()
	return true

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	reset()

func get_origin() -> Vector2:
	if mode == "floating" and (owner_index != -1 or mouse_owned):
		return _floating_origin
	return size * 0.5

func _draw() -> void:
	var center := get_origin()
	# Ivory and aged gold echo the HUD without turning the movement pad into
	# an opaque panel. All decoration stays inside the existing pad geometry.
	draw_circle(center, RADIUS + 13, Color(0.25, 0.18, 0.09, 0.40))
	draw_circle(center, RADIUS + 11, Color(0.95, 0.88, 0.70, 0.24))
	draw_arc(center, RADIUS + 12, 0, TAU, 64, Color(0.74, 0.52, 0.20, 0.90), 2, true)
	draw_arc(center, RADIUS + 9, 0, TAU, 64, Color(1.0, 0.95, 0.79, 0.70), 1, true)
	draw_arc(center, RADIUS, 0, TAU, 64, Color(0.91, 0.79, 0.52, 0.48), 1, true)
	draw_arc(center, RADIUS * 0.63, 0, TAU, 64, Color(0.96, 0.86, 0.64, 0.18), 1, true)
	for step in range(8):
		var axis := Vector2.from_angle(-PI * 0.5 + step * PI * 0.25)
		var cardinal := step % 2 == 0
		draw_line(center + axis * (54 if cardinal else 64), center + axis * 69, Color(0.98, 0.90, 0.68, 0.55 if cardinal else 0.32), 1.4 if cardinal else 1, true)
		if cardinal:
			draw_line(center + axis * 14, center + axis * 48, Color(0.96, 0.86, 0.64, 0.16), 1, true)
	# A small turquoise inset is the only cool-colored accent.
	var inset := center + Vector2(0, -69)
	draw_colored_polygon(PackedVector2Array([inset + Vector2(0, -3), inset + Vector2(2, 0), inset + Vector2(0, 3), inset + Vector2(-2, 0)]), Color(0.13, 0.68, 0.68, 0.85))
	draw_circle(center, RADIUS * DEADZONE, Color(0.96, 0.86, 0.64, 0.10))
	draw_circle(center + knob, 25, Color(0.94, 0.87, 0.70, 0.94))
	draw_arc(center + knob, 25, 0, TAU, 40, Color(0.67, 0.44, 0.15, 0.94), 2, true)
	draw_arc(center + knob, 22, 0, TAU, 40, Color(1.0, 0.96, 0.84, 0.80), 1, true)

func set_position_input(point: Vector2) -> void:
	if not input_enabled:
		return
	if not point.is_finite():
		reset()
		return
	var center := _press_origin if mode == "floating" and (owner_index != -1 or mouse_owned) else size * 0.5
	knob = (point - center).limit_length(RADIUS)
	var strength := knob.length() / RADIUS
	direction = Vector2.ZERO if strength <= DEADZONE else knob.normalized() * ((strength - DEADZONE) / (1.0 - DEADZONE))
	direction_changed.emit(direction)
	queue_redraw()

func reset() -> void:
	owner_index = -1
	mouse_owned = false
	knob = Vector2.ZERO
	direction = Vector2.ZERO
	_floating_origin = size * 0.5
	_press_origin = size * 0.5
	direction_changed.emit(direction)
	queue_redraw()

func _begin_pointer(point: Vector2) -> void:
	if mode == "floating":
		# Keep the complete pad readable even when a press lands on the edge.
		# Measure motion from the actual press, not this clamped visual center,
		# so edge presses start at zero and cannot jump on the first tiny drag.
		var margin := Vector2(minf(PAD_MARGIN, size.x * 0.5), minf(PAD_MARGIN, size.y * 0.5))
		_floating_origin = point.clamp(margin, size - margin)
		_press_origin = point
	set_position_input(point)

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.canceled and event.index == owner_index:
			reset()
			accept_event()
		elif event.pressed and not event.canceled and event.index >= 0 and Rect2(Vector2.ZERO, size).has_point(event.position):
			if owner_index == -1 and not mouse_owned:
				owner_index = event.index
				_begin_pointer(event.position)
				accept_event()
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if owner_index == -1 and not mouse_owned and Rect2(Vector2.ZERO, size).has_point(event.position):
			mouse_owned = true
			_begin_pointer(event.position)
			accept_event()

func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	# Track only the owning pointer globally so leaving the pad cannot stick movement.
	if owner_index != -1 and event is InputEventScreenTouch and event.index == owner_index:
		if not event.pressed or event.canceled:
			reset()
			get_viewport().set_input_as_handled()
	elif owner_index != -1 and event is InputEventScreenDrag and event.index == owner_index:
		set_position_input(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif mouse_owned and event.device != -1 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		reset()
		get_viewport().set_input_as_handled()
	elif mouse_owned and event.device != -1 and event is InputEventMouseMotion:
		set_position_input(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _on_control_rect_changed() -> void:
	# Handedness can move a same-size pad without a resize notification.
	if owner_index != -1 or mouse_owned or direction != Vector2.ZERO:
		reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED or what == NOTIFICATION_DISABLED or what == NOTIFICATION_EXIT_TREE:
		reset()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		reset()
	elif what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_on_control_rect_changed()
	elif what == NOTIFICATION_RESIZED:
		# A layout/handedness change must not keep an old pointer origin alive.
		reset()
