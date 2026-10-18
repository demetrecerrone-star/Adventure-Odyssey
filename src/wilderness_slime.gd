extends Node2D
# Source pixels are untouched. Squash / stretch also carry the readable lunge cue.
var sprite: Sprite2D
var frames: Array[Texture2D] = []
var data: Dictionary = {}
func _ready() -> void:
	for direction in ["down","left","right","up"]:
		for frame in 3: frames.append(load("res://assets/monsters/green_slime_bounce/%s_%02d.png" % [direction,frame]))
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2(-64,-81)*0.65
	sprite.scale = Vector2.ONE*0.65
	add_child(sprite)
func sync(enemy: Dictionary) -> void:
	data = enemy
	position = enemy.position
	z_index = int(position.y*0.4)
	visible = enemy.hp > 0
	var frame := 0
	if enemy.mode in ["chase","return"]: frame = int(enemy.phase)%3
	elif enemy.mode == "windup": frame = 1
	elif enemy.mode == "recover": frame = 2 if enemy.timer > 0.2 else 0
	sprite.texture = frames[int(enemy.facing)*3+frame]
	sprite.modulate = Color(1.7,1.2,1.1) if enemy.hit_flash > 0 else Color.WHITE
	# Brief actual visual lunge only, collision remains at measured foot anchor.
	var lunge: Vector2 = (Vector2(enemy.aim)-position).normalized()*10 if enemy.mode == "recover" and enemy.timer > 0.2 else Vector2.ZERO
	sprite.position = Vector2(-64,-81)*0.65+lunge
	queue_redraw()
func _draw() -> void:
	if data.is_empty() or data.hp <= 0: return
	draw_set_transform(Vector2(0,-3),0,Vector2(1,0.38))
	draw_circle(Vector2.ZERO,31,Color(0.06,0.12,0.05,0.25))
	if data.mode == "windup":
		draw_arc(Vector2.ZERO,40,0,TAU,40,Color("ffb45c"),4,true)
	draw_set_transform(Vector2.ZERO)
	if data.hp < 36 or data.mode in ["chase","windup","recover"]:
		draw_rect(Rect2(-27,-67,54,6),Color("30241f"))
		draw_rect(Rect2(-26,-66,52*float(data.hp)/36,4),Color("9fce62"))
