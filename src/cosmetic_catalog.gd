extends RefCounted
# Earned-currency tuning only. Cosmetic IDs never enter equipment/stat calculations.
const ITEMS := {
 "armor_original":{"label":"Original outfit", "slot":"armor_dye", "price":0, "color":"ffffff", "description":"Your class's original painted outfit."},
 "armor_moonweave":{"label":"Moonweave dye", "slot":"armor_dye", "price":3, "color":"6088bf", "description":"Cool blue pigments. Skin, hair and weapons stay unchanged."},
 "armor_emberweave":{"label":"Emberweave dye", "slot":"armor_dye", "price":3, "color":"a34d65", "description":"Warm rose pigments. Appearance only; no combat bonuses."},
 "bed_oak_green":{"label":"Green oak bed", "slot":"bed", "price":0, "color":"ffffff", "description":"Your original green blanket and oak bed."},
 "bed_riverside":{"label":"Riverside blanket", "slot":"bed", "price":4, "color":"447dba", "description":"River-blue bedding with the original oak frame and pillow."},
 "bed_rosewood":{"label":"Rose dusk blanket", "slot":"bed", "price":4, "color":"a75072", "description":"Soft rose bedding with the original oak frame and pillow."}
}
const DEFAULTS := {"armor_dye":"armor_original", "bed":"bed_oak_green"}
static func initial() -> Dictionary:
 return {"owned":["armor_original","bed_oak_green"], "equipped":DEFAULTS.duplicate()}
static func item(id: String) -> Dictionary:
 return ITEMS.get(id, {}).duplicate(true)
static func material(id: String) -> ShaderMaterial:
 if not ITEMS.has(id) or int(ITEMS[id].price) == 0: return null
 var result := ShaderMaterial.new()
 result.shader = preload("res://src/cosmetic_palette.gdshader")
 result.set_shader_parameter("pigment", Color(ITEMS[id].color))
 result.set_shader_parameter("blanket_only", ITEMS[id].slot == "bed")
 return result
