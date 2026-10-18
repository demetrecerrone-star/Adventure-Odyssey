extends RefCounted
# Item IDs are types, never binding rules. Ownership belongs to each saved stack.
const LABELS = {
	"healing_potion":"Healing potion",
	"mana_potion":"Mana potion",
	"keepsake_ring":"Keepsake ring",
	"warrior_01_weapon":"Warrior's basic sword",
	"ranger_01_weapon":"Ranger's basic bow",
	"mage_01_weapon":"Mage's basic staff",
	"necromancer_01_weapon":"Necromancer's basic staff",
	"assassin_01_weapon":"Assassin's basic daggers",
	"paladin_01_weapon":"Paladin's basic sword"
}
const LEGACY_ITEMS = ["healing_potion", "warrior_01_weapon", "ranger_01_weapon", "mage_01_weapon", "necromancer_01_weapon", "assassin_01_weapon", "paladin_01_weapon"]
const WEAPONS = {
	"warrior_01_weapon":{"class_id":"Warrior", "type":"sword", "slot":"weapon"},
	"ranger_01_weapon":{"class_id":"Ranger", "type":"bow", "slot":"weapon"},
	"mage_01_weapon":{"class_id":"Mage", "type":"staff", "slot":"weapon"},
	"necromancer_01_weapon":{"class_id":"Necromancer", "type":"staff", "slot":"weapon"},
	"assassin_01_weapon":{"class_id":"Assassin", "type":"daggers", "slot":"weapon"},
	"paladin_01_weapon":{"class_id":"Paladin", "type":"sword", "slot":"weapon"}
}
static func starter_weapon(selected_class: String) -> String:
	for id in WEAPONS:
		if WEAPONS[id].class_id == selected_class:
			return id
	return ""
static func empty_inventory() -> Dictionary:
	var result := {}
	for id in LABELS:
		result[id] = 0
	return result
static func can_equip(item: String, selected_class: String) -> bool:
	return WEAPONS.has(item) and WEAPONS[item].class_id == selected_class
static func ring_allowed(item: String) -> bool:
	return item == "keepsake_ring"
static func starter_armor(selected_class: String) -> String:
	if starter_weapon(selected_class).is_empty():
		return ""
	return selected_class.to_lower() + "_01_armor"
static func armor_allowed(item: String, selected_class: String) -> bool:
	return not item.is_empty() and item == starter_armor(selected_class)
static func binding_for_source(source: String) -> String:
	return "character" if source == "starter" or source == "npc_purchase" or source.begins_with("tutorial.") else "unbound"
