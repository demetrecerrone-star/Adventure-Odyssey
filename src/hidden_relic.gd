extends RefCounted
const ITEM := "hidden_old_stick"
const SOURCE := "hidden_relic"
const SOURCE_ID := "secret.old_stick"
const BONUS_DAMAGE := 988 # 12 baseline + 988 = 1000, before STR.
# Fixed eligible trees on existing reachable paths; one is selected once per slot.
const TREES := {
 "oak_mature__01":Vector2(300,1050),
 "oak_young__02":Vector2(880,1000),
 "oak_mature__02":Vector2(770,1535)
}
static func initial() -> Dictionary:
 var ids := TREES.keys()
 return {"tree_id":ids[randi()%ids.size()],"claimed":false}
static func valid(value) -> bool:
 return value is Dictionary and value.size()==2 and value.get("tree_id") in TREES and value.get("claimed") is bool
static func point(value: Dictionary) -> Vector2:
 return TREES.get(value.get("tree_id",""),Vector2.ZERO)
static func texture() -> AtlasTexture:
 var source: Texture2D = preload("res://assets/hidden-relic/old-stick.png")
 var atlas := AtlasTexture.new()
 atlas.atlas = source
 atlas.region = source.get_image().get_used_rect()
 return atlas
