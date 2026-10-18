extends RefCounted
# Pure quest planning. The Save owner must apply rewards and this candidate state
# in ONE transaction; neither this model nor its dialogue view writes a save.
const Inventory = preload("res://src/inventory_catalog.gd")
const VERSION := 1
const STAGES := [
	"awaiting_letter", "visit_guild", "visit_blacksmith", "upgrade_blacksmith",
	"return_guild_blacksmith", "visit_apothecary", "return_guild_apothecary",
	"visit_general_store", "return_guild_general_store", "first_combat_pending",
	"first_combat_active", "return_guild_first_combat", "tutorial_complete",
	"forest_patrol_active", "return_guild_forest", "forest_patrol_complete"
]
const STEPS := [
	{"id":"read_envelope", "kind":"action", "rewards":[]},
	{"id":"guild_assign_blacksmith", "kind":"action", "rewards":[]},
	{"id":"blacksmith_claim_starter", "kind":"action", "rewards":["tutorial.blacksmith.upgrade_supplies"]},
	{"id":"blacksmith_upgrade_applied", "kind":"event", "rewards":[]},
	{"id":"guild_after_blacksmith", "kind":"action", "rewards":[]},
	{"id":"apothecary_claim_gift", "kind":"action", "rewards":["tutorial.apothecary.mana_potions"]},
	{"id":"guild_after_apothecary", "kind":"action", "rewards":[]},
	{"id":"general_store_claim_keepsake", "kind":"action", "rewards":["tutorial.general_store.keepsake_ring"]},
	{"id":"guild_after_general_store", "kind":"action", "rewards":[]},
	{"id":"guild_assign_first_combat", "kind":"action", "rewards":[]},
	{"id":"first_combat_completed", "kind":"event", "rewards":[]},
	{"id":"guild_complete_first_combat", "kind":"action", "rewards":["tutorial.guild.first_combat_gold"]},
	{"id":"guild_assign_forest_patrol", "kind":"action", "rewards":[]},
	{"id":"forest_patrol_completed", "kind":"event", "rewards":[]},
	{"id":"guild_complete_forest_patrol", "kind":"action", "rewards":["guild.west_forest_patrol.gold"]}
]
const OBJECTIVES := {
	"awaiting_letter":"Read the envelope at your doorstep.",
	"visit_guild":"Visit the Adventurer Guild and speak to the receptionist.",
	"visit_blacksmith":"Visit the blacksmith for your first lesson.",
	"upgrade_blacksmith":"Use the blacksmith's upgrade service to upgrade your tutorial weapon to +1.",
	"return_guild_blacksmith":"Return to the guild receptionist after your upgrade lesson.",
	"visit_apothecary":"Visit the apothecary for your first supply gift.",
	"return_guild_apothecary":"Return to the guild receptionist after visiting the apothecary.",
	"visit_general_store":"Visit the general store for a keepsake.",
	"return_guild_general_store":"Return to the guild receptionist with your keepsake.",
	"first_combat_pending":"Speak to the guild receptionist to accept your first field assignment.",
	"first_combat_active":"Follow the gold road marks past home to the South Meadow. Clear three slimes.",
	"return_guild_first_combat":"Three slimes defeated. Return to the guild receptionist for your reward.",
	"tutorial_complete":"Training complete. Speak to the guild receptionist about the Western Forest patrol.",
	"forest_patrol_active":"Clear two wolves from the Western Forest trail. Cross the west bridge, follow the northern branch, and search just east of the first wooded bend.",
	"return_guild_forest":"Patrol complete. Return to the guild for 40 gold.",
	"forest_patrol_complete":"Patrol complete. Spend Sigils on home dyes and decor."
}

static func initial_state() -> Dictionary:
	return {"version":VERSION, "stage":STAGES[0], "action_receipts":{}, "event_receipts":{}, "reward_receipts":{}}

static func validate_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5:
		return false
	if not _whole_number(value.get("version")) or int(value.version) != VERSION:
		return false
	var stage = value.get("stage")
	if not stage is String or stage not in STAGES:
		return false
	for field in ["action_receipts", "event_receipts", "reward_receipts"]:
		if not value.get(field) is Dictionary:
			return false
	var completed := STAGES.find(stage)
	var expected_actions := 0
	var expected_events := 0
	var expected_rewards := 0
	var seen_ids := {}
	for index in range(completed):
		var step: Dictionary = STEPS[index]
		var receipts: Dictionary = value[step.kind + "_receipts"]
		var receipt = receipts.get(step.id)
		if not receipt is Dictionary or receipt.size() != 3:
			return false
		if not _valid_receipt_id(receipt.get("id")) or seen_ids.has(receipt.id):
			return false
		if receipt.get("from") != STAGES[index] or receipt.get("to") != STAGES[index + 1]:
			return false
		seen_ids[receipt.id] = true
		if step.kind == "action":
			expected_actions += 1
		else:
			expected_events += 1
		for reward_id in step.rewards:
			expected_rewards += 1
			var reward = value.reward_receipts.get(reward_id)
			if not reward is Dictionary or reward.size() != 2:
				return false
			if reward.get("id") != receipt.id or reward.get("owner") != step.id:
				return false
	return value.action_receipts.size() == expected_actions and value.event_receipts.size() == expected_events and value.reward_receipts.size() == expected_rewards

static func objective(value: Dictionary) -> String:
	if not validate_state(value):
		return "Tutorial progress could not be read. Your save has not been changed."
	return OBJECTIVES[value.stage]

static func plan_action(value: Dictionary, action_id: String, receipt_id: String, context: Dictionary = {}) -> Dictionary:
	return _plan(value, "action", action_id, receipt_id, context)

static func plan_event(value: Dictionary, event_id: String, receipt_id: String, context: Dictionary = {}) -> Dictionary:
	# This API belongs to Save/gameplay systems, never to dialogue callbacks.
	return _plan(value, "event", event_id, receipt_id, context)

static func _plan(value: Dictionary, kind: String, id: String, receipt_id: String, context: Dictionary) -> Dictionary:
	if not validate_state(value):
		return _failure(value, "invalid_state", "Tutorial progress could not be read. Your save has not been changed.")
	if not _valid_receipt_id(receipt_id):
		return _failure(value, "invalid_receipt", "A valid transaction receipt is required.")
	var step_index := -1
	for index in range(STEPS.size()):
		if STEPS[index].id == id and STEPS[index].kind == kind:
			step_index = index
			break
	if step_index < 0:
		return _failure(value, "unknown_action", "This tutorial action is not available.")
	# A reused transport receipt cannot authorize a different semantic operation.
	for receipt_kind in ["action", "event"]:
		for completed_id in value[receipt_kind + "_receipts"]:
			if value[receipt_kind + "_receipts"][completed_id].id == receipt_id and (completed_id != id or receipt_kind != kind):
				return _failure(value, "receipt_conflict", "This transaction receipt belongs to another action.")
	if value[kind + "_receipts"].has(id):
		return {"ok":true, "duplicate":true, "code":"already_applied", "message":"This step is already complete.", "next_state":value.duplicate(true), "rewards":[]}
	if value.stage != STAGES[step_index]:
		return _failure(value, "wrong_stage", "Finish your current tutorial errand first.")
	var rewards: Array = []
	if id == "blacksmith_claim_starter":
		var weapon := Inventory.starter_weapon(str(context.get("character_class", "")))
		if weapon.is_empty():
			return _failure(value, "invalid_class", "A valid character class is required for your weapon.")
		rewards = [
			{"receipt_id":"tutorial.blacksmith.upgrade_supplies", "kind":"upgrade_entitlement", "entitlement_id":"tutorial_weapon_plus_one", "uses":1, "target_item_id":weapon, "target_level":1, "binding":"character", "source":"tutorial"}
		]
	elif id == "blacksmith_upgrade_applied":
		var weapon := Inventory.starter_weapon(str(context.get("character_class", "")))
		if weapon.is_empty() or context.get("item_id") != weapon:
			return _failure(value, "wrong_upgrade_target", "Upgrade your existing class-matched starter weapon.")
		if not _whole_number(context.get("from_level")) or not _whole_number(context.get("to_level")):
			return _failure(value, "invalid_upgrade", "The upgrade system must confirm a completed +1 lesson.")
		if context.from_level != 0 or context.to_level != 1 or (not context.get("supplies_consumed") is bool or context.supplies_consumed != true):
			return _failure(value, "invalid_upgrade", "The upgrade system must confirm a completed +1 lesson.")
	elif id == "first_combat_completed":
		if context.get("encounter_id") != "south_meadow_slimes":
			return _failure(value, "invalid_encounter", "Clear the assigned South Meadow encounter first.")
	elif id == "forest_patrol_completed":
		if context.get("encounter_id") != "west_forest_patrol":
			return _failure(value, "invalid_encounter", "Clear the assigned Western Forest wolves first.")
	elif id == "guild_complete_forest_patrol":
		rewards = [{"receipt_id":"guild.west_forest_patrol.gold", "kind":"gold", "count":40, "binding":"character", "source":"guild"}]
	elif id == "guild_complete_first_combat":
		rewards = [{"receipt_id":"tutorial.guild.first_combat_gold", "kind":"gold", "count":25, "binding":"character", "source":"tutorial"}]
	elif id == "apothecary_claim_gift":
		rewards = [{"receipt_id":"tutorial.apothecary.mana_potions", "kind":"item", "item_id":"mana_potion", "count":5, "binding":"character", "source":"tutorial"}]
	elif id == "general_store_claim_keepsake":
		rewards = [{"receipt_id":"tutorial.general_store.keepsake_ring", "kind":"item", "item_id":"keepsake_ring", "count":1, "binding":"character", "source":"tutorial"}]
	var next := value.duplicate(true)
	next.stage = STAGES[step_index + 1]
	next[kind + "_receipts"][id] = {"id":receipt_id, "from":value.stage, "to":next.stage}
	for reward in rewards:
		next.reward_receipts[reward.receipt_id] = {"id":receipt_id, "owner":id}
	return {"ok":true, "duplicate":false, "code":"ready", "message":"", "next_state":next, "rewards":rewards}

static func _failure(value: Dictionary, code: String, message: String) -> Dictionary:
	return {"ok":false, "duplicate":false, "code":code, "message":message, "next_state":value.duplicate(true), "rewards":[]}

static func _valid_receipt_id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 128 and value == value.strip_edges()

static func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value))
