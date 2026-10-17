extends RefCounted
const Catalog = preload("res://src/creator/catalog.gd")
var base := "male"
var hair := "male_hair_01"
var hair_color := "Brown"
var eyes := "Brown"
var skin := "warm"
var character_class := "Warrior"
var username := ""
# Separate selections survive repeated switching; no male hair ever enters female catalog.
var remembered_hair := {"male":"male_hair_01", "female":"female_hair_01"}
func set_base(value: String) -> bool:
	if value not in ["male", "female"]:
		return false
	remembered_hair[base] = hair
	base = value
	hair = remembered_hair[base]
	return true
func randomize_appearance(rng: RandomNumberGenerator) -> void:
	var hairs := Catalog.hair_ids(base)
	hair = hairs[rng.randi_range(0, hairs.size() - 1)]
	remembered_hair[base] = hair
	hair_color = Catalog.HAIR_COLORS[rng.randi_range(0, Catalog.HAIR_COLORS.size() - 1)]
	eyes = Catalog.EYES[rng.randi_range(0, Catalog.EYES.size() - 1)]
	skin = Catalog.SKINS[rng.randi_range(0, Catalog.SKINS.size() - 1)].id
func username_error() -> String:
	if username.length() < 3 or username.length() > 20:
		return "Use 3–20 letters, numbers or underscores."
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z][A-Za-z0-9_]{2,19}$")
	if pattern.search(username) == null:
		return "Start with a letter; use letters, numbers or underscores."
	return ""
func validate() -> String:
	if base not in ["male", "female"] or hair not in Catalog.hair_ids(base):
		return "Choose hair from the selected body’s catalog."
	if character_class not in Catalog.CLASSES or eyes not in Catalog.EYES or hair_color not in Catalog.HAIR_COLORS:
		return "Choose an available appearance and class."
	if not Catalog.SKINS.any(func(item): return item.id == skin):
		return "Choose an available skin palette."
	return username_error()
func payload() -> Dictionary:
	return {"schema_version":1, "base":base, "hair":hair, "hair_color":hair_color,
		"eyes":eyes, "skin":skin, "class":character_class, "username":username}
static func gear_allowed(gear: Dictionary, selected_class: String) -> bool:
	# Reject old all-class gear and incomplete definitions by default.
	return selected_class in Catalog.CLASSES and gear.get("class_id", "") == selected_class
