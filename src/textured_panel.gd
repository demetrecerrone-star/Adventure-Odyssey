extends Panel
func _draw() -> void:
	# Deterministic, subtle woven stone texture; UI remains separate from scenery.
	for y in range(6, int(size.y) - 6, 5):
		draw_line(Vector2(5, y), Vector2(size.x - 5, y), Color(0.9, 0.8, 0.6, 0.025), 1)
	for x in range(8, int(size.x) - 8, 17):
		draw_line(Vector2(x, 5), Vector2(x, size.y - 5), Color(0, 0, 0, 0.04), 1)
