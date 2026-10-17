extends RefCounted
# Catalog identifiers are stable contracts, not claims that artwork exists.
const CLASSES = ["Warrior", "Ranger", "Mage", "Necromancer", "Assassin", "Paladin"]
const SKINS = [
	{"id":"porcelain", "label":"Porcelain", "color":"f2d6c2"},
	{"id":"fair", "label":"Fair", "color":"e8ba96"},
	{"id":"warm", "label":"Warm", "color":"c99065"},
	{"id":"tan", "label":"Tan", "color":"a76d49"},
	{"id":"brown", "label":"Brown", "color":"754831"},
	{"id":"deep", "label":"Deep", "color":"462e25"},
	{"id":"red", "label":"Red", "color":"ae5452"},
	{"id":"green", "label":"Green", "color":"71965b"},
	{"id":"purple", "label":"Purple", "color":"9472ae"},
	{"id":"blue", "label":"Blue", "color":"638caf"},
	{"id":"teal", "label":"Teal", "color":"4d9995"},
	{"id":"slate", "label":"Slate", "color":"75818d"}
]
const EYES = ["Brown", "Hazel", "Green", "Blue", "Gray", "Amber", "Violet"]
const HAIR_COLORS = ["Black", "Brown", "Auburn", "Blonde", "Silver", "White"]
static func hair_ids(base: String) -> Array[String]:
	var result: Array[String] = []
	if base not in ["male", "female"]:
		return result
	for i in range(1, 16):
		result.append("%s_hair_%02d" % [base, i])
	return result
static func empty_manifest() -> Dictionary:
	return {"schema_version":1, "bases":{
		"male":{"status":"missing", "label":"Male", "layers":{}},
		"female":{"status":"missing", "label":"Female", "layers":{}}
	}}

static func hair_label(base: String, number: int) -> String:
	var path := "res://assets/character-hair/manifest.json"
	if FileAccess.file_exists(path):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
		if manifest is Dictionary:
			var entry: Dictionary = manifest.get("bases", {}).get(base, {}).get("%s_hair_%02d" % [base, number], {})
			if not str(entry.get("name", "")).is_empty():
				return str(entry.name)
	return "%s hair %02d (unavailable)" % [base.capitalize(), number]
