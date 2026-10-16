extends Node2D
# Combat readability for the existing green-slime actor; no gameplay changes.
# Coordinates are local to the actor, so the bar tracks moving sprites.
var health: int = 35
var max_health: int = 35
var targeted: bool = false
var attack_warning: bool = false

func update_health(value: int, maximum: int) -> void:
	health = maxi(0, value)
	max_health = maxi(1, maximum)
	queue_redraw()

func update_indicator(selected: bool, warning: bool) -> void:
	if targeted == selected and attack_warning == warning:
		return
	targeted = selected
	attack_warning = warning
	queue_redraw()

func _draw() -> void:
	if targeted:
		draw_arc(Vector2(0, -14), 72.0, 0.0, TAU, 48, Color("#f5d58f"), 5.0)
	if attack_warning:
		draw_arc(Vector2(0, -14), 84.0, 0.0, TAU, 48, Color("#ff746c"), 7.0)
	# Neutral outline and saturated fill are readable against forest foliage.
	var frame := Rect2(-70, -174, 140, 22)
	draw_rect(frame, Color(0.05, 0.09, 0.12, 0.85))
	draw_rect(Rect2(-66, -170, 132, 14), Color("#442d35"))
	var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
	var fill_color := Color("#81d796") if ratio > 0.5 else (Color("#e4b45b") if ratio > 0.2 else Color("#dc6969"))
	if ratio > 0.0:
		draw_rect(Rect2(-66, -170, 132.0 * ratio, 14), fill_color)
