extends Control
# Native UI icons: unchanged inventory weapon illustrations and registered armor layers, plus purpose-drawn bottles/ring.
const Catalog = preload("res://src/inventory_catalog.gd")
static var gear_cache := {}
var item_id := ""
var base := "male"
var textures: Array = []
var source_bounds := Rect2()
var artwork_ready := false
func configure(id: String, selected_base: String = "male") -> void:
 item_id = id
 base = selected_base if selected_base in ["male", "female"] else "male"
 textures = []
 source_bounds = Rect2()
 artwork_ready = id in ["healing_potion", "mana_potion", "keepsake_ring"]
 var key := base + ":" + id
 if not artwork_ready:
  if not gear_cache.has(key): gear_cache[key] = _load_gear(id, base)
  var entry: Dictionary = gear_cache[key]
  textures = entry.get("textures", [])
  source_bounds = entry.get("bounds", Rect2())
  artwork_ready = not textures.is_empty() and source_bounds.has_area()
 tooltip_text = Catalog.LABELS.get(id, id.replace("_01_armor", " armor").capitalize())
 queue_redraw()
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size = Vector2(52, 52)
 resized.connect(queue_redraw)
func _load_gear(id: String, selected_base: String) -> Dictionary:
 if id == "hidden_old_stick":
  var stick = preload("res://src/hidden_relic.gd").texture()
  return {"textures":[stick], "bounds":Rect2(Vector2.ZERO,stick.get_size())}
 var paths: Array = []
 if Catalog.WEAPONS.has(id):
  paths = ["res://assets/inventory-icons/" + id + ".png"]
 elif id.ends_with("_01_armor"):
  var class_name_id := id.trim_suffix("_01_armor")
  var path := "res://assets/character-outfits/" + selected_base + "/" + class_name_id + "/idle-armor.png"
  if ResourceLoader.exists(path): paths = [path]
 var loaded: Array = []
 var bounds := Rect2i()
 for path in paths:
  var texture = load(path)
  if not texture is Texture2D: continue
  var cell: Image = texture.get_image().get_region(Rect2i(0, 0, mini(256, texture.get_width()), mini(256, texture.get_height())))
  var used := cell.get_used_rect()
  if not used.has_area(): continue
  bounds = used if not bounds.has_area() else bounds.merge(used)
  loaded.append(texture)
 return {"textures":loaded, "bounds":Rect2(bounds)}
func _draw() -> void:
 var center := size * 0.5
 var radius := minf(size.x, size.y) * 0.5 - 2
 draw_circle(center, radius, Color("e4d7b8"))
 draw_arc(center, radius, 0, TAU, 48, Color("a9833c"), 1.6, true)
 draw_arc(center, radius - 3, 0, TAU, 48, Color("f9efd1"), 1, true)
 if item_id in ["healing_potion", "mana_potion"]:
  var factor := radius / 24.0
  var liquid := Color("b64b49") if item_id == "healing_potion" else Color("397fbc")
  draw_circle(center + Vector2(0, 5) * factor, 13 * factor, Color("ede6ce"))
  draw_circle(center + Vector2(0, 7) * factor, 10 * factor, liquid)
  draw_arc(center + Vector2(0, 5) * factor, 13 * factor, 0, TAU, 32, Color("735f43"), 1.5, true)
  draw_rect(Rect2(center + Vector2(-5, -15) * factor, Vector2(10, 12) * factor), Color("e9e0c3"))
  draw_rect(Rect2(center + Vector2(-6, -17) * factor, Vector2(12, 5) * factor), Color("9d7845"))
  draw_line(center + Vector2(-7, 0) * factor, center + Vector2(-7, 7) * factor, Color(1, 1, 0.9, 0.6), 2, true)
 elif item_id == "keepsake_ring":
  draw_arc(center + Vector2(0, 4), radius * 0.49, 0, TAU, 48, Color("99722a"), 5, true)
  draw_arc(center + Vector2(0, 3), radius * 0.49, 0, TAU, 48, Color("efce71"), 2, true)
  var top := center + Vector2(0, -radius * 0.42)
  draw_colored_polygon(PackedVector2Array([top + Vector2(0,-6),top + Vector2(6,0),top + Vector2(0,6),top + Vector2(-6,0)]), Color("459286"))
 elif artwork_ready:
  var available := size - Vector2(12, 12)
  var factor := minf(available.x / source_bounds.size.x, available.y / source_bounds.size.y)
  var extent := source_bounds.size * factor
  var target := Rect2((size - extent) * 0.5, extent)
  for texture in textures: draw_texture_rect_region(texture, target, source_bounds)
 else:
  draw_line(center - Vector2(8,8), center + Vector2(8,8), Color("746349"), 2, true)
