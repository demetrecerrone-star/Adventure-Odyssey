extends RefCounted
# Bounded development shop policy. Prices are provisional until economy design
# supplies production values. Keep past revisions when changing current prices:
# persisted purchases are checked against the revision that charged them.
const Inventory = preload("res://src/inventory_catalog.gd")
const MAX_QUANTITY := 10
const MAX_TRANSACTION_ID_LENGTH := 96
const STOCK_POLICY := "unlimited"
const CURRENT_REVISION := 1
const PRICE_HISTORY = {
	1: {
		"apothecary": {"healing_potion":10, "mana_potion":10},
		"general_store": {"healing_potion":10}
	}
}
const SHOPS = {
	"apothecary": {"name":"Apothecary", "scene":"apothecary_interior"},
	"general_store": {"name":"General Store", "scene":"general_store_interior"}
}

static func shop_for_scene(scene: String) -> String:
	for shop_id in SHOPS:
		if SHOPS[shop_id].scene == scene: return shop_id
	return ""

static func shop_name(shop_id: String) -> String:
	return str(SHOPS.get(shop_id, {}).get("name", ""))

static func scene_for(shop_id: String) -> String:
	return str(SHOPS.get(shop_id, {}).get("scene", ""))

static func unit_price(shop_id: String, item_id: String, revision: int = CURRENT_REVISION) -> int:
	return int(PRICE_HISTORY.get(revision, {}).get(shop_id, {}).get(item_id, 0))

static func entries_for(shop_id: String) -> Array:
	var offers: Array = []
	for item_id in PRICE_HISTORY[CURRENT_REVISION].get(shop_id, {}):
		offers.append({"item_id":item_id, "label":Inventory.LABELS[item_id], "unit_price_gold":unit_price(shop_id, item_id)})
	return offers
