extends RefCounted
# Hair-only overlays. This module never mutates or recolors body/armor textures.
const COLORS := {"Black":"302c35", "Brown":"73503b", "Auburn":"a45338", "Blonde":"d7b775", "Silver":"aeb4c4", "White":"e3dfe2"}
const SHADER = preload("res://src/hair_palette.gdshader")
var rear: Sprite2D
var front: Sprite2D
var entry: Dictionary = {}
var cache: Dictionary = {}
var ready := false
var style_name := ""
func attach(owner: Node2D, before_body: Node, after_armor: Node) -> void:
	rear = Sprite2D.new()
	rear.name = "HairRear"
	front = Sprite2D.new()
	front.name = "HairFront"
	for sprite in [rear, front]:
		sprite.centered = false
		sprite.offset = Vector2(-128, -232)
		sprite.visible = false
		owner.add_child(sprite)
	owner.move_child(rear, before_body.get_index())
	owner.move_child(front, after_armor.get_index() + 1)
func configure(base: String, appearance: Dictionary) -> bool:
	# Keep only the active style; cycling 30 choices must not retain every atlas.
	cache.clear()
	entry = {}
	ready = false
	style_name = ""
	var path := "res://assets/character-hair/manifest.json"
	if FileAccess.file_exists(path):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
		if manifest is Dictionary:
			entry = manifest.get("bases", {}).get(base, {}).get(str(appearance.get("hair", "")), {})
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("hair_color", Color(COLORS.get(str(appearance.get("hair_color", "Brown")), COLORS.Brown)))
	for sprite in [rear, front]:
		if sprite != null:
			sprite.material = material
			sprite.visible = false
	style_name = str(entry.get("name", ""))
	return not entry.is_empty()
func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if cache.has(path):
		return cache[path]
	if not ResourceLoader.exists(path):
		return null
	var value = load(path)
	if not value is Texture2D:
		return null
	cache[path] = value
	return value
func advance(animation: String, frames: int, frame: int) -> bool:
	ready = false
	if rear == null or front == null:
		return false
	for sprite in [rear, front]:
		sprite.visible = false
	var pair: Dictionary = entry.get(animation, {})
	if int(pair.get("frames", 0)) != frames or frame < 0 or frame >= frames:
		return false
	var rear_texture := _texture(str(pair.get("rear", "")))
	var front_texture := _texture(str(pair.get("front", "")))
	if rear_texture == null or front_texture == null:
		return false
	if rear_texture.get_size() != Vector2(256 * frames, 256) or front_texture.get_size() != Vector2(256 * frames, 256):
		return false
	rear.texture = rear_texture
	front.texture = front_texture
	for sprite in [rear, front]:
		sprite.hframes = frames
		sprite.frame = frame
		sprite.visible = true
	ready = true
	return true
