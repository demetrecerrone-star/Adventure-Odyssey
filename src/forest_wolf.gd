extends Node2D
# Archived, approved wolf sheet: actual walking and jaw-strike poses, unchanged pixels.
var sprite: Sprite2D
var data: Dictionary = {}
const SHEET = preload("res://assets/monsters/wolf/wolf.png")
func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = 4
	sprite.vframes = 6
	sprite.centered = false
	sprite.position = Vector2(-64,-120)*0.72
	sprite.scale = Vector2.ONE*0.72
	add_child(sprite)
func sync(enemy: Dictionary) -> void:
	data = enemy
	position = enemy.position
	z_index = int(position.y*0.4)
	visible = enemy.hp > 0
	var row := 0 if int(enemy.facing) == 0 else (2 if int(enemy.facing) == 3 else 1)
	var frame := 0
	if enemy.mode in ["chase","return","wander"]: frame = int(enemy.phase)%4
	elif enemy.mode == "windup":
		row += 3
		frame = 1
	elif enemy.mode == "recover":
		row += 3
		frame = 2 if enemy.timer > 0.2 else 3
	sprite.flip_h = int(enemy.facing) == 1
	sprite.frame_coords = Vector2i(frame,row)
	sprite.modulate = Color(1.7,1.15,1.1) if enemy.hit_flash > 0 else Color.WHITE
	queue_redraw()
func _draw() -> void:
	if data.is_empty() or data.hp <= 0: return
	draw_set_transform(Vector2(0,-3),0,Vector2(1,0.38))
	draw_circle(Vector2.ZERO,32,Color(0.06,0.10,0.05,0.25))
	if data.mode == "windup": draw_arc(Vector2.ZERO,43,0,TAU,40,Color("ffb45c"),4,true)
	draw_set_transform(Vector2.ZERO)
	if data.hp < data.get("max_hp",48) or data.mode in ["chase","windup","recover"]:
		draw_rect(Rect2(-29,-94,58,6),Color("30241f"))
		draw_rect(Rect2(-28,-93,56*float(data.hp)/float(data.get("max_hp",48)),4),Color("d9ad66"))
