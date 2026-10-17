extends Control
# Only a press inside this control can claim it. Other fingers remain free for UI.
signal direction_changed(value: Vector2)
const RADIUS := 62.0
const DEADZONE := 0.16
var owner_index := -1
var mouse_owned := false
var direction := Vector2.ZERO
var knob := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(164, 164)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS + 13, Color(0.05, 0.07, 0.09, 0.38))
	draw_arc(center, RADIUS, 0, TAU, 64, Color(0.92, 0.83, 0.64, 0.65), 2, true)
	draw_circle(center, RADIUS * DEADZONE, Color(0.92, 0.83, 0.64, 0.15))
	draw_circle(center + knob, 25, Color(0.87, 0.76, 0.55, 0.82))
	draw_arc(center + knob, 25, 0, TAU, 40, Color(1, 0.94, 0.80, 0.85), 2, true)

func set_position_input(point: Vector2) -> void:
	knob = (point - size * 0.5).limit_length(RADIUS)
	var strength := knob.length() / RADIUS
	direction = Vector2.ZERO if strength <= DEADZONE else knob.normalized() * ((strength - DEADZONE) / (1.0 - DEADZONE))
	direction_changed.emit(direction)
	queue_redraw()

func reset() -> void:
	owner_index = -1
	mouse_owned = false
	knob = Vector2.ZERO
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if owner_index == -1 and not mouse_owned:
			owner_index = event.index
			set_position_input(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if owner_index == -1 and not mouse_owned:
			mouse_owned = true
			set_position_input(event.position)
		accept_event()

func _input(event: InputEvent) -> void:
	# Track only the owning pointer globally so leaving the pad cannot stick movement.
	if event is InputEventScreenTouch and event.index == owner_index:
		if not event.pressed or event.canceled:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == owner_index:
		set_position_input(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif mouse_owned and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		reset()
		get_viewport().set_input_as_handled()
	elif mouse_owned and event is InputEventMouseMotion:
		set_position_input(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		reset()
