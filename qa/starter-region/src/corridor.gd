extends Node2D
const SPEED := 155.0
const FOOT_RADIUS := 16.0 # QA assumption; bedroom used 16 px obstacle inflation.
var layout: Dictionary
var origin := Vector2.ZERO
var chunks := {}
var camera: Camera2D
var player: CharacterBody2D
var joystick: Control
var touch_direction := Vector2.ZERO
var interactive := true
var peak_bytes := 0
var peak_count := 0
var load_events := 0
var unload_events := 0
var actor: Sprite2D
func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://layout.json"))
	origin = vec(layout.world_origin)
	for block in layout.blocked_polygons:
		var body := StaticBody2D.new()
		body.name = block.id
		body.position = origin
		var collision := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		for p in block.polygon: points.append(vec(p))
		collision.polygon = points
		body.add_child(collision)
		add_child(body)
	player = CharacterBody2D.new()
	player.position = origin + vec(layout.routes[0].points[0])
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = FOOT_RADIUS
	collision.shape = shape
	player.add_child(collision)
	add_child(player)
	actor = Sprite2D.new()
	actor.texture = ImageTexture.create_from_image(Image.load_from_file("res://actor-native.png"))
	actor.scale = Vector2.ONE * (96.0 / actor.texture.get_height())
	actor.position.y = -48
	actor.z_index = 1
	player.add_child(actor)
	camera = Camera2D.new()
	camera.position = clamped_camera(player.position)
	camera.position_smoothing_enabled = false
	add_child(camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	joystick = load("res://src/touch_joystick.gd").new()
	joystick.position = Vector2(24, 536)
	joystick.size = Vector2(164,164)
	hud.add_child(joystick)
	joystick.direction_changed.connect(func(v: Vector2): touch_direction = v)
	update_chunks()
func vec(p: Array) -> Vector2: return Vector2(p[0],p[1])
func clamped_camera(target: Vector2) -> Vector2:
	var half := get_viewport_rect().size / camera.zoom / 2.0 if camera != null else Vector2(640,360)
	return Vector2(clampf(target.x,ceilf(half.x),floorf(4608-half.x)),clampf(target.y,ceilf(half.y),floorf(3072-half.y)))
func update_chunks() -> void:
	camera.position = clamped_camera(camera.position)
	var view_size := get_viewport_rect().size / camera.zoom
	# 128 px prefetch margin; no hidden unbounded texture cache.
	var needed := Rect2(camera.position - view_size/2,view_size).grow(128)
	var bytes := 0
	for i in range(layout.chunks.size()):
		var data: Dictionary = layout.chunks[i]
		var r: Array = data.world_rect
		var rect := Rect2(r[0],r[1],r[2],r[3])
		if needed.intersects(rect):
			bytes += int((r[2]+4)*(r[3]+4)*4)
			if not chunks.has(i):
				var image := Image.load_from_file("res://"+data.file)
				var sprite := Sprite2D.new()
				sprite.texture = ImageTexture.create_from_image(image)
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				sprite.centered = false
				sprite.region_enabled = true
				sprite.region_rect = Rect2(2,2,r[2],r[3])
				# Clamp-to-region would bypass copied neighbor gutters; keep disabled.
				sprite.region_filter_clip_enabled = false
				sprite.position = rect.position
				add_child(sprite)
				chunks[i] = sprite
				load_events += 1
		elif chunks.has(i):
			chunks[i].free()
			chunks.erase(i)
			unload_events += 1
	peak_bytes = maxi(peak_bytes,bytes)
	peak_count = maxi(peak_count,chunks.size())
func _physics_process(delta: float) -> void:
	if not interactive: return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))) + touch_direction
	player.move_and_collide(direction.limit_length() * SPEED * minf(delta,0.05))
	camera.position = clamped_camera(player.position)
	update_chunks()
