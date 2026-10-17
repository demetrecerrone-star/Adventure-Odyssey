extends Node2D
# Body and armor always switch as a validated pair. Missing outfits never expose underwear.
var hair_renderer = preload("res://src/character_hair.gd").new()
var weapon_back: Sprite2D
var weapon_front: Sprite2D
var weapon_outfit: Dictionary = {}
var equipped_weapon := ""
var character_class := ""
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
var appearance: Dictionary = {}
var painted_pilot: Dictionary = {}
var palette_material: ShaderMaterial
var palette_ready := false
const Catalog = preload("res://src/creator/catalog.gd")
const EYE_COLORS := {"Brown":"704127", "Hazel":"8b813e", "Green":"448653", "Blue":"3d83be", "Gray":"87939b", "Amber":"c78b2e", "Violet":"9564b9"}
func _ready() -> void:
	for layer_name in ["WeaponBack", "Body", "Armor", "WeaponFront", "Hair"]:
		var sprite := Sprite2D.new()
		sprite.name = layer_name
		sprite.centered = false
		sprite.offset = Vector2(-128, -232)
		add_child(sprite)
	weapon_back = get_node("WeaponBack")
	weapon_front = get_node("WeaponFront")
	body = get_node("Body")
	armor = get_node("Armor")
	hair = get_node("Hair")
	hair_renderer.attach(self, body, armor)
func configure(base: String, selected_class: String, selected_appearance: Dictionary = {}) -> bool:
	character_class = selected_class
	painted_pilot = {}
	var pilot_path := "res://assets/painted-walk-pilot/manifest.json"
	if base == "male" and selected_class == "Warrior" and FileAccess.file_exists(pilot_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(pilot_path))
		if data is Dictionary:
			painted_pilot = data
	weapon_outfit = {}
	var weapon_path := "res://assets/held-weapons/" + selected_class.to_lower() + ".json"
	if FileAccess.file_exists(weapon_path):
		var weapons = JSON.parse_string(FileAccess.get_file_as_string(weapon_path))
		if weapons is Dictionary:
			weapon_outfit = weapons.get("bases", {}).get(base, {})
	appearance = selected_appearance.duplicate()
	hair_renderer.configure(base, appearance)
	palette_material = ShaderMaterial.new()
	palette_material.shader = preload("res://src/appearance_palette.gdshader")
	var skin_id := str(appearance.get("skin", "warm"))
	for entry in Catalog.SKINS:
		if entry.id == skin_id:
			palette_material.set_shader_parameter("skin_color", Color(entry.color))
	palette_material.set_shader_parameter("eye_color", Color(EYE_COLORS.get(str(appearance.get("eyes", "Brown")), EYE_COLORS.Brown)))
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
	if _valid_painted_pilot():
		outfit.walk.left = painted_pilot.walk_left
	else:
		painted_pilot = {}
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
func _valid_painted_pilot() -> bool:
	var pair: Dictionary = painted_pilot.get("walk_left", {})
	if not _valid_pair(pair, 6):
		return false
	var mask := _texture(str(pair.get("appearance_mask", "")))
	return mask != null and mask.get_size() == Vector2(1536, 256) and painted_pilot.get("hair_offsets", []).size() == 6 and painted_pilot.get("weapon_offsets", []).size() == 6
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
	var mask_path: String = str(pair.get("appearance_mask", str(pair.body).replace("character-outfits/", "character-appearance/").replace("-body.png", "-mask.png")))
	var mask_texture := _texture(mask_path)
	palette_ready = palette_material != null and mask_path != str(pair.body) and mask_texture != null and mask_texture.get_size() == body.texture.get_size()
	if palette_ready:
		palette_material.set_shader_parameter("appearance_mask", mask_texture)
		body.material = palette_material
	else:
		# Missing or malformed masks never trigger whole-body/armor tinting.
		body.material = null
	armor.texture = _texture(pair.armor)
	for sprite in [body, armor, hair]:
		sprite.hframes = frames
		sprite.frame = frame
	hair.texture = _texture(str(pair.get("hair", "")))
	hair.visible = false
	for sprite in [hair_renderer.rear, hair_renderer.front]:
		sprite.position = Vector2.ZERO
	if uses_painted_pilot():
		hair_renderer.advance("idle", 4, 1)
		for sprite in [hair_renderer.rear, hair_renderer.front]:
			sprite.position = _pilot_offset("hair_offsets")
	else:
		hair_renderer.advance(current_animation, body.hframes, body.frame)
	_update_weapon()

func uses_painted_pilot() -> bool:
	return not painted_pilot.is_empty() and current_animation == "walk_left"
func cadence_speed(direction: int) -> float:
	return 135.0 if not painted_pilot.is_empty() and direction == 1 else suggested_speed
func _pilot_offset(key: String) -> Vector2:
	var offsets: Array = painted_pilot.get(key, [])
	if body.frame < offsets.size():
		return Vector2(offsets[body.frame][0], offsets[body.frame][1])
	return Vector2.ZERO

func set_equipped_weapon(item: String) -> void:
	equipped_weapon = item if preload("res://src/inventory_catalog.gd").can_equip(item, character_class) else ""
	_update_weapon()
func _update_weapon() -> void:
	for sprite in [weapon_back, weapon_front]:
		sprite.visible = false
		sprite.position = Vector2.ZERO
	if not preload("res://src/inventory_catalog.gd").can_equip(equipped_weapon, character_class) or not artwork_ready:
		return
	var key := current_animation.replace("walk_", "walk-")
	var entry: Dictionary = weapon_outfit.get("idle" if uses_painted_pilot() else key, {})
	var weapon_frames := 4 if uses_painted_pilot() else body.hframes
	if int(entry.get("frames", 0)) != weapon_frames:
		return
	for layer in ["back", "front"]:
		var sprite: Sprite2D = weapon_back if layer == "back" else weapon_front
		var texture := _texture(str(entry.get("layers", {}).get(layer, "")))
		if texture == null or texture.get_size() != Vector2(256 * weapon_frames, 256):
			continue
		sprite.texture = texture
		sprite.hframes = weapon_frames
		sprite.frame = 1 if uses_painted_pilot() else body.frame
		if uses_painted_pilot():
			sprite.position = _pilot_offset("weapon_offsets")
		sprite.visible = true
