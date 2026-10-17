extends Node2D
# Body and armor always switch as a validated pair. Missing outfits never expose underwear.
var body: Sprite2D
var armor: Sprite2D
var hair: Sprite2D
var outfit: Dictionary = {}
var artwork_ready := false
var suggested_speed := 60.0
var facing := 0
var elapsed := 0.0
var current_animation := ""
var texture_cache := {}
func _ready() -> void:
	for layer_name in ["Body", "Armor", "Hair"]:
		var sprite := Sprite2D.new()
		sprite.name = layer_name
		sprite.centered = false
		sprite.offset = Vector2(-128, -232)
		add_child(sprite)
	body = get_node("Body")
	armor = get_node("Armor")
	hair = get_node("Hair")
func configure(base: String, selected_class: String) -> bool:
	outfit = {}
	artwork_ready = false
	current_animation = ""
	var path := "res://assets/character-outfits/manifest.json"
	if not FileAccess.file_exists(path):
		visible = false
		return false
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
	if manifest is Dictionary:
		outfit = manifest.get("bases", {}).get(base, {}).get("classes", {}).get(selected_class, {})
		suggested_speed = clampf(float(outfit.get("movement_speed", manifest.get("movement_speed", 60))), 1, 230)
	artwork_ready = _valid_pair(outfit.get("idle", {}), 4)
	visible = artwork_ready
	if artwork_ready:
		advance(facing, false, 0)
	return artwork_ready
func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture = load(path)
	if not texture is Texture2D:
		return null
	texture_cache[path] = texture
	return texture
func _valid_pair(pair: Dictionary, frames: int) -> bool:
	for key in ["body", "armor"]:
		var texture := _texture(str(pair.get(key, "")))
		if texture == null or texture.get_size() != Vector2(256 * frames, 256):
			return false
	return true
func advance(direction: int, moving: bool, delta: float) -> void:
	facing = clampi(direction, 0, 3)
	if not artwork_ready:
		return
	var names := ["down", "left", "right", "up"]
	var pair: Dictionary = outfit.idle
	var frames := 4
	var frame := facing
	var animation := "idle"
	if moving:
		var walk: Dictionary = outfit.get("walk", {}).get(names[facing], {})
		var count := int(walk.get("frames", 4))
		if count > 0 and count <= 16 and _valid_pair(walk, count):
			pair = walk
			frames = count
			animation = "walk_" + names[facing]
	if animation != current_animation:
		elapsed = 0
		current_animation = animation
	elapsed += delta
	if animation != "idle":
		frame = int(elapsed * clampf(float(pair.get("fps", 8)), 1, 20)) % frames
	body.texture = _texture(pair.body)
	armor.texture = _texture(pair.armor)
	for sprite in [body, armor, hair]:
		sprite.hframes = frames
		sprite.frame = frame
	hair.texture = _texture(str(pair.get("hair", "")))
	hair.visible = hair.texture != null and hair.texture.get_size() == Vector2(256 * frames, 256)
