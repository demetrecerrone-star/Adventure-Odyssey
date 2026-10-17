extends RefCounted
# A single local guest slot. No account, credentials, or online name reservation.
const Draft = preload("res://src/creator/character_draft.gd")
const APPEARANCE = ["hair", "hair_color", "eyes", "skin"]
const Inventory = preload("res://src/inventory_catalog.gd")
const ITEMS = Inventory.LABELS
var path := "user://bedroom_guest_v1.json"
var character: Dictionary = {}
var bag := Inventory.empty_inventory()
var chest := Inventory.empty_inventory()
var equipped_weapon := ""
var equipped_armor := ""
var awake := true
var location := {"scene":"bedroom", "position":[535.0,670.0]}
var error := ""
func draft_from(value: Dictionary):
	var draft = Draft.new()
	draft.set_base(str(value.get("base", "")))
	draft.hair = str(value.get("hair", ""))
	draft.hair_color = str(value.get("hair_color", ""))
	draft.eyes = str(value.get("eyes", ""))
	draft.skin = str(value.get("skin", ""))
	draft.character_class = str(value.get("class", ""))
	draft.username = str(value.get("username", ""))
	return draft
func create(value: Dictionary) -> bool:
	if not character.is_empty() or value.get("base", "") not in ["male", "female"]:
		return false
	if not draft_from(value).validate().is_empty():
		return false
	character = value.duplicate(true)
	bag = Inventory.empty_inventory()
	chest = Inventory.empty_inventory()
	chest.healing_potion = 5
	chest[Inventory.starter_weapon(character["class"])] = 1
	equipped_armor = Inventory.starter_armor(character["class"])
	if not save():
		character = {}
		return false
	return true
func apply_appearance(value: Dictionary) -> bool:
	if character.is_empty():
		return false
	var candidate := character.duplicate(true)
	for key in APPEARANCE:
		if value.has(key):
			candidate[key] = value[key]
	if not draft_from(candidate).validate().is_empty():
		return false
	var previous := character
	character = candidate
	if not save():
		character = previous
		return false
	return true
func transfer(item: String, to_chest: bool) -> bool:
	if character.is_empty() or not ITEMS.has(item):
		return false
	var source: Dictionary = bag if to_chest else chest
	var target: Dictionary = chest if to_chest else bag
	if source[item] <= 0:
		return false
	source[item] -= 1
	target[item] += 1
	if not save():
		source[item] += 1
		target[item] -= 1
		return false
	return true
func save() -> bool:
	error = ""
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Couldn't save locally. Your previous save is unchanged."
		return false
	file.store_string(JSON.stringify({"version":5, "tutorial_chest_seeded":true, "character":character, "bag":bag, "chest":chest, "equipped_weapon":equipped_weapon, "equipped_armor":equipped_armor, "awake":awake, "location":location}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "Couldn't finish saving locally. Try again."
		return false
	return true
func load_saved() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		error = "Local save could not be read. It has not been overwritten."
		return false
	var data = parser.data
	if not data is Dictionary or int(data.get("version", -1)) not in [1, 2, 3, 4, 5]:
		error = "Local save could not be read. It has not been overwritten."
		return false
	var candidate = data.get("character")
	if not candidate is Dictionary or candidate.get("base", "") not in ["male", "female"] or not draft_from(candidate).validate().is_empty():
		error = "Local character is invalid. It has not been overwritten."
		return false
	# Upgrade the unreleased v1 demo inventory once, replacing arbitrary sample loot.
	var version := int(data.version)
	var migrating: bool = version < 3
	if version >= 2 and data.get("tutorial_chest_seeded") != true:
		error = "Local tutorial state is invalid. It has not been overwritten."
		return false
	var expected_items: Array = ["travel_bread", "keepsake"] if version == 1 else (["healing_potion"] if version == 2 else ITEMS.keys())
	for inventory in ["bag", "chest"]:
		if not data.get(inventory) is Dictionary:
			return false
		for item in expected_items:
			var count = data[inventory].get(item, -1)
			if not (count is float or count is int) or count < 0 or count > 999 or count != floor(count):
				return false
	var equipment: String = str(data.get("equipped_weapon", ""))
	if not equipment.is_empty() and not Inventory.can_equip(equipment, candidate["class"]):
		error = "Local equipment is invalid. It has not been overwritten."
		return false
	var armor: String = str(data.get("equipped_armor", "")) if version >= 4 else Inventory.starter_armor(candidate["class"])
	if not Inventory.armor_allowed(armor, candidate["class"]):
		error = "Local armor is invalid. It has not been overwritten."
		return false
	var saved_location = data.get("location", {"scene":"bedroom", "position":[535.0,670.0]})
	if not valid_location(saved_location):
		error = "Local location is invalid. It has not been overwritten."
		return false
	location = saved_location.duplicate(true)
	character = candidate.duplicate(true)
	bag = Inventory.empty_inventory() if migrating else data.bag.duplicate(true)
	chest = Inventory.empty_inventory() if migrating else data.chest.duplicate(true)
	if migrating:
		bag.healing_potion = 0 if version == 1 else data.bag.healing_potion
		chest.healing_potion = 5 if version == 1 else data.chest.healing_potion
		chest[Inventory.starter_weapon(character["class"])] = 1
	equipped_weapon = equipment
	equipped_armor = armor
	# The retired wake gate never controls visibility. Migration preserves all loot.
	awake = true
	if version < 5 and not save():
		character = {}
		return false
	return true

func equip(item: String) -> bool:
	if character.is_empty() or not equipped_weapon.is_empty() or not Inventory.can_equip(item, character["class"]) or bag.get(item, 0) <= 0:
		return false
	bag[item] -= 1
	equipped_weapon = item
	if not save():
		bag[item] += 1
		equipped_weapon = ""
		return false
	return true
func unequip() -> bool:
	if equipped_weapon.is_empty():
		return false
	var previous := equipped_weapon
	bag[previous] += 1
	equipped_weapon = ""
	if not save():
		bag[previous] -= 1
		equipped_weapon = previous
		return false
	return true

func valid_location(value) -> bool:
	if not value is Dictionary or value.get("scene", "") not in ["bedroom", "starter_region", "guild_interior", "blacksmith_interior", "apothecary_interior", "general_store_interior"]:
		return false
	var point = value.get("position")
	if not point is Array or point.size() != 2: return false
	for number in point:
		if not (number is float or number is int) or not is_finite(float(number)): return false
	var bounds := Vector2(4608,3072) if value.scene == "starter_region" else Vector2(1536,1024)
	return point[0] >= 0 and point[0] <= bounds.x and point[1] >= 0 and point[1] <= bounds.y
func set_location(scene: String, point: Vector2) -> bool:
	var previous := location.duplicate(true)
	var next := {"scene":scene, "position":[point.x, point.y]}
	if not valid_location(next): return false
	location = next
	if not save():
		location = previous
		return false
	return true
