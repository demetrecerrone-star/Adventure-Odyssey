extends SceneTree
const Progress = preload("res://src/tutorial_progress.gd")
const Dialogue = preload("res://src/tutorial_dialogue.gd")
const Inventory = preload("res://src/inventory_catalog.gd")
const CLASSES := ["Warrior", "Ranger", "Mage", "Necromancer", "Assassin", "Paladin"]
var checks := 0
var failures := 0
var action_count := 0
var service_count := 0
var close_count := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func context_for(selected_class: String) -> Dictionary:
	return {"character_class":selected_class, "item_id":Inventory.starter_weapon(selected_class), "from_level":0, "to_level":1, "supplies_consumed":true, "encounter_id":"south_meadow_slimes"}

func apply_step(state: Dictionary, index: int, selected_class: String = "Warrior", receipt: String = "") -> Dictionary:
	var step: Dictionary = Progress.STEPS[index]
	var request := "receipt_" + str(index) if receipt.is_empty() else receipt
	if step.kind == "event":
		var context := context_for(selected_class)
		if step.id == "forest_patrol_completed": context.encounter_id = "west_forest_patrol"
		return Progress.plan_event(state, step.id, request, context)
	return Progress.plan_action(state, step.id, request, context_for(selected_class))

func state_at(index: int, selected_class: String = "Warrior") -> Dictionary:
	var state := Progress.initial_state()
	for step in range(index):
		state = apply_step(state, step, selected_class).next_state
	return state

func run() -> void:
	check(Progress.validate_state(Progress.initial_state()), "Initial state validates")
	check(Progress.objective(Progress.initial_state()).contains("doorstep"), "Envelope is the first objective")
	for selected_class in CLASSES:
		var state := Progress.initial_state()
		var delivered := {}
		for index in range(Progress.STEPS.size()):
			var before := state.duplicate(true)
			var first := apply_step(state, index, selected_class)
			check(first.ok and not first.duplicate, selected_class + " step " + str(index) + " is accepted")
			check(state == before, "Planning never mutates the supplied state")
			check(first.next_state.stage == Progress.STAGES[index + 1], "Every step advances exactly one stage")
			check(Progress.validate_state(first.next_state), "Every candidate state validates")
			check(apply_step(state, index, selected_class) == first, "Identical plans are deterministic")
			for reward in first.rewards:
				check(not delivered.has(reward.receipt_id), "A stable reward is planned only once")
				delivered[reward.receipt_id] = reward
				check(reward.binding == "character" and reward.source in ["tutorial","guild"], "Tutorial rewards are character-bound")
				check(not reward.has("damage") and not reward.has("price") and not reward.has("restoration"), "No undefined numeric balance data is invented")
			state = first.next_state
			for retry_id in ["receipt_" + str(index), "fresh_retry_" + str(index)]:
				var retry := apply_step(state, index, selected_class, retry_id)
				check(retry.ok and retry.duplicate and retry.rewards.is_empty(), "Same or new request ID cannot repeat a semantic grant")
				check(retry.next_state == state, "A duplicate keeps the latest state")
			var reloaded = JSON.parse_string(JSON.stringify(state))
			check(Progress.validate_state(reloaded), "JSON numeric normalization and receipt round trip validate")
		check(delivered.size() == 5, "Supplies, mana, keepsake and final guild payment are granted")
		check(not delivered.has("tutorial.blacksmith.weapon"), "Blacksmith never duplicates the starter chest weapon")
		var supplies: Dictionary = delivered["tutorial.blacksmith.upgrade_supplies"]
		check(supplies.kind == "upgrade_entitlement" and supplies.uses == 1 and supplies.target_level == 1, "The free upgrade entitlement permits one +1 lesson")
		check(supplies.target_item_id == Inventory.starter_weapon(selected_class), "Supplies target the existing class-matched starter weapon")
		check(delivered["tutorial.apothecary.mana_potions"].count == 5, "Apothecary gift is exactly five mana potions")
		check(delivered["tutorial.general_store.keepsake_ring"].item_id == "keepsake_ring", "General store gift is the keepsake ring")
		check(state.stage == "forest_patrol_complete", "Verified field assignment and guild return finish training")
		for fake_context in [{}, {"verified":true}, {"combat_available":true, "victory":true, "source":"combat_system"}]:
			var active := state_at(10)
			var blocked := Progress.plan_event(active, "first_combat_completed", "fake_combat", fake_context)
			check(not blocked.ok and blocked.code == "invalid_encounter" and blocked.next_state == active, "Fake combat cannot complete the tutorial")
		for index in range(Progress.STEPS.size()):
			var retry := apply_step(state, index, selected_class, "late_retry_" + str(index))
			check(retry.ok and retry.duplicate and retry.next_state == state and retry.rewards.is_empty(), "Late retries preserve the final current state")
	# Any future/out-of-order step fails without poisoning receipts or rewards.
	for current in range(Progress.STEPS.size()):
		for future in range(current + 1, Progress.STEPS.size()):
			var state := state_at(current)
			var result := apply_step(state, future)
			check(not result.ok and result.code == "wrong_stage" and result.next_state == state and result.rewards.is_empty(), "Out-of-order errand is rejected")
	for receipt in ["", "   ", " leading", "trailing ", "x".repeat(129)]:
		check(not Progress.plan_action(Progress.initial_state(), "read_envelope", receipt).ok, "Reject malformed transaction IDs")
	var first_read := state_at(1)
	var collision := Progress.plan_action(first_read, "guild_assign_blacksmith", "receipt_0")
	check(not collision.ok and collision.code == "receipt_conflict", "Receipt cannot be reused for another action")
	check(not Progress.plan_action(Progress.initial_state(), "unknown", "unknown").ok, "Unknown actions fail closed")
	check(not Progress.plan_action(state_at(3), "blacksmith_upgrade_applied", "event_as_action", context_for("Warrior")).ok, "Dialogue action cannot masquerade as an upgrade event")
	for selected_class in ["", "warrior", "Unknown"]:
		check(not Progress.plan_action(state_at(2), "blacksmith_claim_starter", "invalid_class", {"character_class":selected_class}).ok, "Unknown classes cannot claim upgrade supplies")
	for patch in [{"item_id":"mage_01_weapon"}, {"character_class":"Unknown"}, {"from_level":1}, {"to_level":2}, {"to_level":1.5}, {"to_level":true}, {"supplies_consumed":false}, {"supplies_consumed":1}]:
		var context := context_for("Warrior")
		context.merge(patch, true)
		var result := Progress.plan_event(state_at(3), "blacksmith_upgrade_applied", "bad_upgrade", context)
		check(not result.ok and result.next_state == state_at(3), "Invalid upgrade evidence cannot advance tutorial")
	_test_invalid_states()
	_test_dialogue_content()
	await _test_dialogue_controls()
	print("TUTORIAL FLOW CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _test_invalid_states() -> void:
	var corrupt: Array = [null, [], {}, {"stage":"complete"}]
	var unknown_stage := Progress.initial_state()
	unknown_stage.stage = "complete"
	corrupt.append(unknown_stage)
	var forged_progress := Progress.initial_state()
	forged_progress.stage = "first_combat_pending"
	corrupt.append(forged_progress)
	var missing_reward := state_at(3)
	missing_reward.reward_receipts.clear()
	corrupt.append(missing_reward)
	var forged_reward := Progress.initial_state()
	forged_reward.reward_receipts["fake"] = {"id":"fake", "owner":"fake"}
	corrupt.append(forged_reward)
	var reused_receipt := state_at(2)
	reused_receipt.action_receipts.guild_assign_blacksmith.id = "receipt_0"
	corrupt.append(reused_receipt)
	var bad_route := state_at(1)
	bad_route.action_receipts.read_envelope.to = "first_combat_pending"
	corrupt.append(bad_route)
	var bad_version := Progress.initial_state()
	bad_version.version = true
	corrupt.append(bad_version)
	var unknown_field := Progress.initial_state()
	unknown_field.complete = true
	corrupt.append(unknown_field)
	for state in corrupt:
		check(not Progress.validate_state(state), "Corrupt/forged progress rejected")
		if state is Dictionary:
			var before: Dictionary = state.duplicate(true)
			var plan := Progress.plan_action(state, "read_envelope", "corrupt")
			check(not plan.ok and plan.code == "invalid_state" and state == before and plan.rewards.is_empty(), "Invalid plans preserve supplied state")
	var original := Progress.initial_state()
	var plan := Progress.plan_action(original, "read_envelope", "copy")
	plan.next_state.action_receipts.read_envelope.id = "changed_outside"
	check(original.action_receipts.is_empty(), "Candidate state is a deep copy")

func _test_dialogue_content() -> void:
	for index in range(Progress.STAGES.size()):
		var state := state_at(index)
		for id in ["envelope", "guild_receptionist", "blacksmith", "apothecary", "shopkeeper"]:
			var view := Dialogue.describe(id, state, "Warrior")
			var text := JSON.stringify(view).to_lower()
			check(not text.contains("mother") and not text.contains("high-ranking"), "Public dialogue preserves the keepsake backstory")
			for choice in view.choices:
				if choice.kind == "action":
					var result := Progress.plan_action(state, choice.id, "visible_choice", context_for("Warrior"))
					check(result.ok and not result.duplicate, "Every offered action is valid at the displayed stage")
	var ring_view := Dialogue.describe("shopkeeper", state_at(7))
	check(ring_view.body.contains("I've been holding this until you were ready"), "Keepsake introduction uses the approved line")
	check(ring_view.choices.any(func(choice): return choice.id == "keepsake_origin"), "Player can ask who left the ring")
	for index in [9,10]:
		var briefing := Dialogue.describe("guild_receptionist", state_at(index))
		check(briefing.body.contains("west bridge") and briefing.body.contains("south branch"), "Field directions match the playable west-bridge route")
	var invalid := Dialogue.describe("guild_receptionist", {})
	check(invalid.choices.is_empty(), "Unreadable state exposes no actions")

func _test_dialogue_controls() -> void:
	root.size = Vector2i(1280, 720)
	var view = Dialogue.new()
	view.configure("envelope", Progress.initial_state(), "Warrior")
	view.action_requested.connect(func(_id): action_count += 1)
	view.service_requested.connect(func(_id): service_count += 1)
	view.dismissed.connect(func(): close_count += 1)
	root.add_child(view)
	await process_frame
	await process_frame
	check(action_count == 0 and service_count == 0, "Opening a conversation never performs actions")
	check(view.panel.get_script() == Dialogue.Ornate and not view.panel.dark, "Dialogue reuses the light ivory/gold ornate panel")
	check(view.close_button.size.y >= 48, "Leave button is touch-sized")
	var read_choice: Dictionary = view._view.choices[0]
	view._choose(read_choice)
	view._choose(read_choice)
	check(action_count == 1 and view.pending, "Rapid duplicate activation emits one request while pending")
	check(view.tutorial_state == Progress.initial_state(), "UI cannot advance its tutorial snapshot")
	view.show_error("Save failed. Try again.")
	check(not view.pending and view.notice_label.text.contains("Save failed"), "Save failure is visible and retry becomes available")
	view._choose(read_choice)
	check(action_count == 2, "Retry re-emits without local mutation")
	view._dismiss()
	view._dismiss()
	check(close_count == 1, "Repeated dismissal is emitted once, including during a pending save")
	view.configure("shopkeeper", state_at(7), "Warrior")
	var snapshot: Dictionary = view.tutorial_state.duplicate(true)
	var origin: Dictionary = {}
	for choice in view._view.choices:
		if choice.id == "keepsake_origin": origin = choice
	view._choose(origin)
	check(view.body_label.text == "I'll let them tell you that.", "Origin question gives the approved discreet reply")
	check(view.tutorial_state == snapshot and action_count == 2, "Lore question grants nothing and advances nothing")
	# A second finger must work even if the movement finger remains held.
	var lore_button:Button = view.choices.get_node("Choice_keepsake_origin")
	view.body_label.text = "Before touch"
	var touch := InputEventScreenTouch.new(); touch.index = 2; touch.position = lore_button.size * 0.5; touch.pressed = true
	lore_button.gui_input.emit(touch)
	touch = InputEventScreenTouch.new(); touch.index = 2; touch.position = lore_button.size * 0.5; touch.pressed = false
	lore_button.gui_input.emit(touch)
	check(view.body_label.text == "I'll let them tell you that.", "Secondary finger activates dialogue choice")
	for reason in ["cancel", "drag", "focus"]:
		view.body_label.text = "Unchanged"
		touch = InputEventScreenTouch.new(); touch.index = 3; touch.position = lore_button.size * 0.5; touch.pressed = true
		lore_button.gui_input.emit(touch)
		if reason == "focus": view._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif reason == "drag":
			var drag := InputEventScreenDrag.new(); drag.index = 3; drag.position = lore_button.get_global_transform_with_canvas() * (lore_button.size * 0.5 + Vector2(40,0)); view._input(drag)
		touch = InputEventScreenTouch.new(); touch.index = 3; touch.position = lore_button.size * 0.5; touch.pressed = false; touch.canceled = reason == "cancel"
		lore_button.gui_input.emit(touch)
		check(view.body_label.text == "Unchanged", "Dialogue " + reason + " gesture does not activate choice")
	# Production uses canvas_items stretch: get_global_rect is in logical canvas
	# coordinates, not root.size's physical window pixels. Check that mode first,
	# then explicitly disable scaling to exercise genuinely compact phone layouts.
	for viewport in [Vector2i(960, 540), Vector2i(640, 360)]:
		root.size = viewport
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(view.panel.get_global_rect()), "Production stretched dialogue stays within the logical viewport " + str(viewport))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for viewport in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(640, 360)]:
		root.size = viewport
		await process_frame
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport))
		check(viewport_rect.encloses(view.panel.get_global_rect()), "Dialogue panel stays within landscape viewport " + str(viewport))
		check(view.panel.get_global_rect().encloses(view.close_button.get_global_rect()), "Leave stays visible at " + str(viewport))
		check(view.scroll.size.y > 0 and view.scroll.size.x > 0, "Conversation remains scrollable at " + str(viewport))
		check(view.panel.get_global_rect().encloses(view.scroll.get_global_rect()), "Scrollable body stays inside the panel at " + str(viewport))
		check(view.scroll.get_h_scroll_bar().max_value <= view.scroll.size.x + 1, "Readable conversation has no horizontally clipped content at " + str(viewport))
	# Force taller button/text metrics and enough content to require scrolling.
	# The complete text must remain accessible while Leave stays fixed.
	view.theme.default_font_size = 32
	view.body_label.add_theme_font_size_override("font_size", 27)
	view.objective_label.add_theme_font_size_override("font_size", 24)
	view.title_label.add_theme_font_size_override("font_size", 34)
	view.body_label.text = ("A long conversation stays fully readable through the scroll area. ").repeat(8)
	view.show_error(("A long save explanation remains readable and retryable. ").repeat(5))
	for tick in range(6): await process_frame
	var fixed_close: Rect2 = view.close_button.get_global_rect()
	check(view.panel.get_global_rect().encloses(fixed_close), "Leave remains within phone height with taller font metrics")
	check(view.scroll.get_global_rect().position.y >= fixed_close.end.y, "Taller header never overlaps the scroll body")
	check(view.scroll.size.y >= 150, "Phone landscape retains useful scroll height under font stress")
	check(view.scroll.get_v_scroll_bar().max_value > view.scroll.size.y, "Long dialogue and errors remain available through scrolling")
	check(view.scroll.get_h_scroll_bar().max_value <= view.scroll.size.x + 1, "Font stress does not clip text horizontally")
	view.scroll.ensure_control_visible(view.objective_label) # Errors are now at the top; objective is the final content.
	for tick in range(3): await process_frame
	check(view.scroll.scroll_vertical > 0, "Bottom of long conversation can be reached")
	check(view.close_button.get_global_rect() == fixed_close, "Leave remains fixed while dialogue scrolls")
	view.theme.default_font_size = 18
	view.body_label.add_theme_font_size_override("font_size", 19)
	view.objective_label.add_theme_font_size_override("font_size", 16)
	view.title_label.add_theme_font_size_override("font_size", 25)
	view.configure("blacksmith", state_at(3), "Warrior")
	var service_choice: Dictionary = view._view.choices[0]
	view._choose(service_choice)
	view._choose(service_choice)
	check(service_count == 1 and view.pending, "Service requests are single-flight and contain no gameplay result")
	view.configure("guild_receptionist", state_at(9), "Warrior")
	check(view._view.choices.filter(func(choice): return choice.kind == "action").size() == 1 and view._view.choices[0].id == "guild_assign_first_combat", "Only assignment acceptance can advance progress before combat")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		view.configure("shopkeeper", state_at(7), "Warrior")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.save_png("res://tutorial-dialogue.png") == OK, "Native dialogue capture saved")
	view.queue_free()
	await process_frame
