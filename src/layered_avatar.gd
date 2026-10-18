extends Node2D
# Body and armor always switch as a validated pair. Missing outfits never expose underwear.
var hair_renderer = preload("res://src/character_hair.gd").new()
var relic_sprite: Sprite2D
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
var painted_directions: Dictionary = {}
var palette_material: ShaderMaterial
var palette_ready := false
var cosmetic_dye := "armor_original"
# Authored feet/weapon poses remain untouched. The head moves by less than one
# extra source pixel, with a short neck transition instead of a whole-body bob.
var head_lift := 4.0
func head_offset() -> Vector2:
	return Vector2(0, -head_lift)
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
	relic_sprite = Sprite2D.new()
	relic_sprite.name = "HeldHiddenStick"
	relic_sprite.texture = preload("res://src/hidden_relic.gd").texture()
	relic_sprite.scale = Vector2.ONE * (100.0/relic_sprite.texture.get_height())
	relic_sprite.hide()
	add_child(relic_sprite)
func configure(base: String, selected_class: String, selected_appearance: Dictionary = {}) -> bool:
	character_class = selected_class
	painted_pilot = {}
	painted_directions = {}
	# Only reviewed catalog entries opt into painted walks. Unmigrated outfits
	# keep their current paired artwork instead of borrowing another identity.
	var pilot_path := _painted_manifest_path(base, selected_class)
	if not pilot_path.is_empty() and FileAccess.file_exists(pilot_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(pilot_path))
		if data is Dictionary and data.get("base", "") == base and data.get("class", "") == selected_class:
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
	for direction_name in painted_pilot.get("directions", {}):
		var candidate: Dictionary = painted_pilot.directions[direction_name]
		if _valid_painted_direction(candidate):
			painted_directions[direction_name] = candidate
			outfit.walk[direction_name] = candidate
	if painted_directions.is_empty():
		painted_pilot = {}
	artwork_ready = _valid_pair(outfit.get("idle", {}), 4)
	visible = artwork_ready
	if artwork_ready:
		set_cosmetic_dye(cosmetic_dye)
		advance(facing, false, 0)
	return artwork_ready
func set_cosmetic_dye(id: String) -> void:
	var catalog = preload("res://src/cosmetic_catalog.gd")
	if not catalog.ITEMS.has(id) or catalog.ITEMS[id].slot != "armor_dye":
		id = "armor_original"
	cosmetic_dye = id
	if is_instance_valid(armor):
		armor.material = catalog.material(id)
		if armor.material == null:
			var neutral := ShaderMaterial.new()
			neutral.shader = preload("res://src/cosmetic_palette.gdshader")
			neutral.set_shader_parameter("dye_strength", 0.0)
			armor.material = neutral
		armor.material.set_shader_parameter("dye_strength", 0.0 if id == "armor_original" else 1.0)
		armor.material.set_shader_parameter("head_lift", head_lift)
		armor.material.set_shader_parameter("sheet_frames", float(maxi(1,armor.hframes)))
func _painted_manifest_path(base: String, selected_class: String) -> String:
	var path := "res://assets/painted-walks/catalog.json"
	if not FileAccess.file_exists(path): return ""
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not catalog is Dictionary: return ""
	return str(catalog.get("bases", {}).get(base, {}).get(selected_class, ""))
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
func _valid_painted_direction(pair: Dictionary) -> bool:
	if not _valid_pair(pair, 6) or int(pair.get("frames", 0)) != 6 or float(pair.get("fps", 0)) != 9:
		return false
	var mask := _texture(str(pair.get("appearance_mask", "")))
	if mask == null or mask.get_size() != Vector2(1536, 256):
		return false
	if pair.has("hair_transforms"):
		if pair.hair_transforms.size() != 6: return false
		for layer in ["weapon_front", "weapon_back"]:
			var texture := _texture(str(pair.get(layer, "")))
			if texture == null or texture.get_size() != Vector2(1536, 256): return false
		return true
	return pair.get("hair_offsets", []).size() == 6 and pair.get("weapon_offsets", []).size() == 6
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
	var fps := clampf(float(pair.get("fps", 8)), 1, 20)
	if animation != current_animation:
		if animation.begins_with("walk_") and current_animation.begins_with("walk_"):
			# Steering changes the view of the current stride, not its timing.
			# Keep fractional progress too, so frequent turns cannot pin the feet
			# to the first pose. Mixed fallback cycles retain normalized phase.
			var previous: Dictionary = outfit.get("walk", {}).get(current_animation.trim_prefix("walk_"), {})
			var previous_fps := clampf(float(previous.get("fps", 8)), 1, 20)
			if body.hframes != frames or not is_equal_approx(previous_fps, fps):
				var phase := fposmod(elapsed * previous_fps / float(body.hframes), 1.0)
				elapsed = phase * float(frames) / fps
		else:
			elapsed = 0
		current_animation = animation
	elapsed += delta
	if animation != "idle":
		frame = int(elapsed * fps) % frames
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
	head_lift = 4.0
	if animation != "idle":
		head_lift += 0.8 * sin(elapsed * fps / float(frames) * TAU * 2.0)
	if not palette_ready:
		head_lift = 0.0 # Never separate paired layers when an appearance mask is unavailable.
	if palette_ready:
		palette_material.set_shader_parameter("head_lift", head_lift)
		palette_material.set_shader_parameter("sheet_frames", float(frames))
	if armor.material != null:
		armor.material.set_shader_parameter("head_lift", head_lift)
		armor.material.set_shader_parameter("sheet_frames", float(frames))
	armor.texture = _texture(pair.armor)
	for sprite in [body, armor, hair]:
		sprite.hframes = frames
		sprite.frame = frame
	hair.texture = _texture(str(pair.get("hair", "")))
	hair.visible = false
	for sprite in [hair_renderer.rear, hair_renderer.front]:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
	if uses_painted_pilot():
		var pilot := _active_pilot()
		hair_renderer.advance("idle", 4, int(pilot.source_idle_cell))
		for sprite in [hair_renderer.rear, hair_renderer.front]:
			if pilot.has("hair_transforms"):
				var transform: Dictionary = pilot.hair_transforms[body.frame]
				var factor := float(transform.scale)
				sprite.scale = Vector2.ONE * factor
				# Affine source-cell coordinates must account for the foot-pivot offset.
				sprite.position = Vector2(transform.translation[0], transform.translation[1]) + Vector2(128,232) * (factor - 1.0)
			else:
				sprite.position = _pilot_offset("hair_offsets")
	else:
		hair_renderer.advance(current_animation, body.hframes, body.frame)
	for sprite in [hair_renderer.rear, hair_renderer.front]:
		sprite.position += head_offset()
	_update_weapon()

func uses_painted_pilot() -> bool:
	return painted_directions.has(current_animation.replace("walk_", ""))
func _active_pilot() -> Dictionary:
	return painted_directions.get(current_animation.replace("walk_", ""), {})
func cadence_speed(direction: int) -> float:
	return 155.0 if painted_directions.has(["down","left","right","up"][clampi(direction,0,3)]) else suggested_speed * (155.0 / 135.0)
func _pilot_offset(key: String) -> Vector2:
	var offsets: Array = _active_pilot().get(key, [])
	if body.frame < offsets.size():
		return Vector2(offsets[body.frame][0], offsets[body.frame][1])
	return Vector2.ZERO

func set_equipped_weapon(item: String) -> void:
	equipped_weapon = item if preload("res://src/inventory_catalog.gd").can_equip(item, character_class) else ""
	_update_weapon()
func _update_weapon() -> void:
	if is_instance_valid(relic_sprite): relic_sprite.hide()
	for sprite in [weapon_back, weapon_front]:
		sprite.visible = false
		sprite.position = Vector2.ZERO
	if not preload("res://src/inventory_catalog.gd").can_equip(equipped_weapon, character_class) or not artwork_ready:
		return
	if equipped_weapon == "hidden_old_stick":
		relic_sprite.visible = true
		relic_sprite.z_index = -1 if facing == 3 else 1
		var side := -1.0 if facing == 1 or facing == 3 else 1.0
		relic_sprite.position = Vector2(36*side,-85) + (_pilot_offset("weapon_offsets") if uses_painted_pilot() else Vector2.ZERO)
		relic_sprite.rotation = side * 0.12
		return
	var key := current_animation.replace("walk_", "walk-")
	var entry: Dictionary = weapon_outfit.get("idle" if uses_painted_pilot() else key, {})
	var pilot := _active_pilot()
	var dedicated: bool = uses_painted_pilot() and pilot.has("weapon_front")
	if dedicated:
		entry = {"frames":6,"layers":{"front":pilot.weapon_front,"back":pilot.weapon_back}}
	var weapon_frames := 6 if dedicated else (4 if uses_painted_pilot() else body.hframes)
	if int(entry.get("frames", 0)) != weapon_frames:
		return
	for layer in ["back", "front"]:
		var sprite: Sprite2D = weapon_back if layer == "back" else weapon_front
		var texture := _texture(str(entry.get("layers", {}).get(layer, "")))
		if texture == null or texture.get_size() != Vector2(256 * weapon_frames, 256):
			continue
		sprite.texture = texture
		sprite.hframes = weapon_frames
		sprite.frame = int(pilot.source_idle_cell) if uses_painted_pilot() and not dedicated else body.frame
		if uses_painted_pilot() and not dedicated:
			sprite.position = _pilot_offset("weapon_offsets")
		sprite.visible = true
