extends SceneTree
const ShopPanel = preload("res://src/ui/shop_purchase_panel.gd")
const Catalog = preload("res://src/shop_catalog.gd")

class ReadOnlySave:
	extends RefCounted
	var wallet_gold := 100
	var shop_id := "apothecary"
	var available := true
	var bag := {"healing_potion":0, "mana_potion":0}
	func get_shop_catalog() -> Dictionary:
		return {"ok":available, "code":"ok" if available else "wrong_location", "message":"Return to the shopkeeper.", "shop_id":shop_id, "shop_name":Catalog.shop_name(shop_id), "stock_policy":"unlimited", "offers":Catalog.entries_for(shop_id) if available else [], "max_quantity":10, "wallet_gold":wallet_gold}
	func snapshot() -> String:
		return JSON.stringify({"wallet":wallet_gold, "bag":bag, "shop":shop_id})

var checks := 0
var failures := 0
var requests: Array = []
var dismissals := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for _tick in range(5):
		await process_frame

func all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			result.append(child)
		result.append_array(all_buttons(child))
	return result

func labels(node: Node) -> String:
	var result := ""
	for child in node.get_children():
		if child is Label:
			result += child.text + "\n"
		result += labels(child)
	return result

func make_panel(state, shop: String):
	var panel = ShopPanel.new()
	panel.configure_shop(state, shop)
	panel.confirm_requested.connect(func(item: String, amount: int, transaction: String): requests.append([item, amount, transaction]))
	panel.dismissed.connect(func(): dismissals += 1)
	root.add_child(panel)
	return panel

func assert_layout(panel, dimensions: Vector2) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, dimensions)
	check(viewport_rect.encloses(panel.panel.get_global_rect()), "%s: ornate shop panel fits" % dimensions)
	check(panel.panel.get_global_rect().encloses(panel.close_button.get_global_rect()), "%s: fixed Back stays inside panel" % dimensions)
	check(panel.panel.get_global_rect().encloses(panel.scroll.get_global_rect()), "%s: scroll body stays inside panel" % dimensions)
	check(panel.scroll.get_h_scroll_bar().max_value <= panel.scroll.size.x + 1, "%s: no hidden horizontal content" % dimensions)
	for button in all_buttons(panel):
		if button.is_visible_in_tree():
			check(button.size.x >= 44 and button.size.y >= 44, "%s: %s has a 44px touch target" % [dimensions, button.name])

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var state := ReadOnlySave.new()
	var before := state.snapshot()
	var panel = make_panel(state, "apothecary")
	await settle()
	check(panel.select_buttons.keys().size() == 2 and panel.select_buttons.has("healing_potion") and panel.select_buttons.has("mana_potion"), "Apothecary offers exactly healing and mana potions")
	check(panel.confirm_button == null and panel.review_button == null, "Browsing has no purchase confirmation before selection")
	check(labels(panel).contains("Wallet: 100 gold"), "Shop displays the actual wallet")
	check(labels(panel).contains("Unlimited stock") and labels(panel).contains("Prices are provisional development values"), "Stock and provisional development price are explicit")
	check(labels(panel).contains("character-bound") and labels(panel).contains("Potion use and effects are unavailable"), "Browsing explains binding and unavailable potion behavior")
	panel.confirm_purchase()
	check(requests.is_empty(), "Direct confirmation cannot bypass selection and review")
	panel.select_item("keepsake_ring")
	check(panel.selected_item_id.is_empty(), "Unknown catalog items cannot be selected")
	for dimensions in [Vector2(1280, 720), Vector2(844, 390)]:
		root.size = Vector2i(dimensions)
		panel.size = dimensions
		panel.select_item("healing_potion")
		await settle()
		assert_layout(panel, dimensions)
		check(panel.quantity == 1 and panel.maximum_quantity() == 10 and panel.total_price() == 10, "Selection starts with one affordable potion")
		panel.set_quantity(-99)
		check(panel.quantity == 1 and panel.decrement_button.disabled, "Quantity cannot fall below one")
		panel.set_quantity(999)
		check(panel.quantity == 10 and panel.increment_button.disabled and panel.total_price() == 100, "Quantity is capped at ten and total is derived from catalog")
		panel.set_quantity(2)
		panel.confirm_purchase()
		check(requests.is_empty(), "Selection alone cannot submit a purchase")
		var close_before: Rect2 = panel.close_button.get_global_rect()
		panel.scroll.scroll_vertical = 10000
		await settle()
		check(panel.close_button.get_global_rect() == close_before, "Scrolling the choices never moves Back")
		panel.review_purchase()
		await settle()
		check(panel.confirming and panel.select_buttons.is_empty() and panel.review_button == null, "Review is separate from browsing")
		check(panel.confirm_button != null and not panel.confirm_button.disabled, "Reviewed selection enables explicit confirmation")
		check(panel.scroll.get_global_rect().encloses(panel.confirm_button.get_global_rect()), "%s: explicit Confirm is visible without scrolling" % dimensions)
		check(labels(panel).contains("Healing potion × 2") and labels(panel).contains("Total: 20 gold") and labels(panel).contains("Wallet after purchase: 80 gold"), "Review displays item, quantity, total, and resulting wallet")
		assert_layout(panel, dimensions)
		panel.set_quantity(7)
		panel.select_item("mana_potion")
		check(panel.quantity == 2 and panel.selected_item_id == "healing_potion", "Reviewed intent cannot change without returning to selection")
		panel.return_to_browse()
		await settle()
		panel.select_item("mana_potion")
		check(panel.quantity == 1 and panel.selected_item_id == "mana_potion", "Changing item resets quantity")
		panel.select_item("healing_potion")
	check(state.snapshot() == before and requests.is_empty(), "Browsing, quantities, and review never mutate save or emit transactions")
	# Secondary finger behavior is inherited for quantity controls and confirmation.
	panel.set_quantity(1)
	await settle()
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = panel.increment_button.size * 0.5
	panel.increment_button.gui_input.emit(touch)
	check(panel.increment_button.get_meta("touch_owner", -1) == 2, "Secondary finger owns quantity button")
	touch.index = 3
	panel.increment_button.gui_input.emit(touch)
	check(panel.increment_button.get_meta("touch_owner", -1) == 2, "Another finger cannot steal quantity button")
	touch.pressed = false
	touch.position = panel.increment_button.get_global_rect().get_center()
	panel._input(touch)
	check(panel.quantity == 1, "Non-owner release cannot change quantity")
	touch.index = 2
	panel._input(touch)
	check(panel.quantity == 2, "Secondary finger changes quantity exactly once")
	touch.position = panel.increment_button.size * 0.5
	panel.increment_button.gui_input.emit(touch)
	check(panel.quantity == 2, "Global and GUI release cannot double-activate quantity")
	for release_case in ["outside", "cancel", "drag", "focus", "primary", "disabled"]:
		touch.index = 0 if release_case == "primary" else 2
		touch.pressed = true
		touch.canceled = false
		touch.position = panel.increment_button.size * 0.5
		panel.increment_button.disabled = release_case == "disabled"
		panel.increment_button.gui_input.emit(touch)
		if release_case == "drag":
			var drag := InputEventScreenDrag.new()
			drag.index = 2
			drag.position = panel.increment_button.get_global_rect().get_center() + Vector2(24, 0)
			panel._input(drag)
		if release_case == "focus":
			panel._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		touch.pressed = false
		touch.canceled = release_case == "cancel"
		touch.position = Vector2.ZERO if release_case == "outside" else panel.increment_button.get_global_rect().get_center()
		panel._input(touch)
		check(panel.quantity == 2, "Touch %s does not change quantity" % release_case)
		check(not panel.increment_button.has_meta("touch_owner"), "Touch %s releases ownership" % release_case)
		panel.increment_button.disabled = false
	panel.review_purchase()
	await settle()
	touch.index = 2
	touch.pressed = true
	touch.canceled = false
	touch.position = panel.confirm_button.size * 0.5
	panel.confirm_button.gui_input.emit(touch)
	touch.pressed = false
	touch.position = panel.confirm_button.get_global_rect().get_center()
	panel._input(touch)
	check(requests.size() == 1 and requests[0][0] == "healing_potion" and requests[0][1] == 2, "Secondary confirm emits exact reviewed intent")
	var first_transaction: String = requests[0][2]
	check(not first_transaction.is_empty() and first_transaction == panel.transaction_id, "Confirmation has a unique stable transaction ID")
	panel.confirm_purchase()
	panel.confirm_button.pressed.emit()
	check(requests.size() == 1 and panel.pending and panel.confirm_button.disabled and panel.edit_button.disabled, "Pending double-taps cannot emit duplicate requests")
	check(not panel.close_button.disabled, "Back remains available during pending confirmation")
	check(state.snapshot() == before, "Emitting a confirmed purchase never mutates save authority")
	panel.show_error("Saving failed. Please retry.")
	await settle()
	check(not panel.pending and not panel.confirm_button.disabled and panel.notice_label.text.contains("Saving failed"), "Failure is visible and reenables confirmation")
	check(panel.scroll.get_global_rect().encloses(panel.notice_label.get_global_rect()), "Save failure message is immediately visible at phone size")
	check(panel.transaction_id == first_transaction and panel.quantity == 2, "Failure preserves the exact reviewed intent")
	panel.confirm_purchase()
	check(requests.size() == 2 and requests[1] == requests[0], "Retry uses the same ID, item, and quantity")
	# Simulate only the owning scene applying a durable success.
	state.wallet_gold = 80
	state.bag.healing_potion = 2
	panel.purchase_succeeded()
	await settle()
	check(not panel.pending and not panel.confirming and panel.selected_item_id.is_empty() and panel.transaction_id.is_empty(), "Successful owner callback clears the old intent")
	check(labels(panel).contains("Wallet: 80 gold") and panel.notice_label.text.contains("Purchase saved"), "Success refreshes actual saved wallet and receipt notice")
	panel.select_item("mana_potion")
	panel.set_quantity(20)
	check(panel.quantity == 8 and panel.maximum_quantity() == 8, "Quantity is bounded by current wallet affordability")
	panel.set_quantity(1)
	panel.review_purchase()
	panel.confirm_purchase()
	check(requests.size() == 3 and requests[2][2] != first_transaction, "A new purchase receives a new transaction ID")
	panel.show_error("Try again.")
	panel.return_to_browse()
	panel.set_quantity(2)
	panel.review_purchase()
	panel.confirm_purchase()
	check(requests.size() == 4 and requests[3][2] != requests[2][2], "Changing an abandoned intent cannot reuse its transaction ID")
	var before_back := state.snapshot()
	panel._dismiss()
	panel._dismiss()
	panel.confirm_purchase()
	check(dismissals == 1 and requests.size() == 4 and state.snapshot() == before_back, "Back emits once and prevents further requests without save mutation")
	panel.free()
	await settle()
	state.shop_id = "general_store"
	state.wallet_gold = 19
	panel = make_panel(state, "general_store")
	await settle()
	check(panel.select_buttons.keys() == ["healing_potion"], "General store offers only healing potion")
	panel.select_item("mana_potion")
	check(panel.selected_item_id.is_empty(), "General store cannot select apothecary-only mana")
	panel.select_item("healing_potion")
	panel.set_quantity(2)
	check(panel.quantity == 1 and panel.maximum_quantity() == 1 and panel.increment_button.disabled, "Affordability floors fractional remaining gold")
	panel.free()
	await settle()
	state.wallet_gold = 0
	panel = make_panel(state, "general_store")
	await settle()
	check(panel.select_buttons.healing_potion.disabled and labels(panel).contains("need at least 10 gold"), "Empty wallet disables unaffordable selection with explanation")
	panel.select_item("healing_potion")
	panel.review_purchase()
	panel.confirm_purchase()
	check(panel.selected_item_id.is_empty() and requests.size() == 4, "Unaffordable selection never emits a purchase")
	panel.free()
	await settle()
	state.available = false
	panel = make_panel(state, "general_store")
	await settle()
	check(panel.select_buttons.is_empty() and labels(panel).contains("Return to the shopkeeper"), "Unavailable authoritative catalog exposes no purchase actions")
	panel.free()
	await settle()
	state.available = true
	panel = make_panel(state, "apothecary")
	await settle()
	check(panel.select_buttons.is_empty() and labels(panel).contains("Return to this shopkeeper"), "Requested shop must match authoritative saved location")
	panel.free()
	await settle()
	print("Shop panel checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
