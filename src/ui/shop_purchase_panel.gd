extends "res://src/tutorial_dialogue.gd"
# Read-only shop presentation. Save validates and commits every purchase; this
# view only submits an explicit, stable intent after a separate review step.
signal confirm_requested(item_id: String, quantity: int, transaction_id: String)

const Catalog = preload("res://src/shop_catalog.gd")
var save_state
var shop_id := "apothecary"
var selected_item_id := ""
var quantity := 1
var confirming := false
var transaction_id := ""
var select_buttons: Dictionary = {}
var decrement_button: Button
var increment_button: Button
var quantity_label: Label
var review_button: Button
var confirm_button: Button
var edit_button: Button
var _catalog: Dictionary = {}
var _notice := ""

func configure_shop(state, id: String) -> void:
	save_state = state
	shop_id = id
	selected_item_id = ""
	quantity = 1
	confirming = false
	transaction_id = ""
	pending = false
	_dismiss_pending = false
	_notice = ""
	if is_node_ready():
		_render()

func _read_catalog() -> void:
	_catalog = {"ok":false, "message":"Shop supplies are unavailable. Return to the shopkeeper and try again.", "offers":[], "wallet_gold":0}
	if save_state == null:
		return
	_catalog = save_state.get_shop_catalog().duplicate(true)
	if not _catalog.get("ok", false):
		return
	if _catalog.get("shop_id", "") != shop_id:
		_catalog = {"ok":false, "message":"Return to this shopkeeper before buying supplies.", "offers":[], "wallet_gold":save_state.wallet_gold}

func _render() -> void:
	_read_catalog()
	_release_touch_owners()
	# Rebuilt choice controls must not accumulate old secondary-touch references.
	_touch_buttons.clear()
	_touch_buttons.append(close_button)
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	select_buttons.clear()
	decrement_button = null
	increment_button = null
	quantity_label = null
	review_button = null
	confirm_button = null
	edit_button = null
	title_label.text = "Review purchase" if confirming else Catalog.shop_name(shop_id)
	close_button.text = "Back"
	objective_label.text = "Wallet: %d gold · Unlimited stock\nPrices are provisional development values." % _wallet()
	notice_label.text = _notice
	notice_label.visible = not _notice.is_empty()
	content.move_child(notice_label, 0)
	if not _catalog.get("ok", false):
		body_label.text = str(_catalog.get("message", "Shop supplies are unavailable."))
		return
	if confirming:
		_render_confirmation()
	else:
		_render_browse()
	notice_label.visible = not notice_label.text.is_empty()
	_apply_controls()
	scroll.scroll_vertical = 0

func _render_browse() -> void:
	body_label.text = "Choose supplies and a quantity, then review. Items go to this character's bag and are character-bound. Potion use and effects are unavailable."
	for offer in _catalog.get("offers", []):
		var id := str(offer.item_id)
		var prefix := "Selected: " if id == selected_item_id else "Select: "
		var button := _button("%s%s · %d gold each" % [prefix, offer.label, offer.unit_price_gold], choices)
		button.name = "Select_" + id
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(select_item.bind(id))
		select_buttons[id] = button
	if not selected_item_id.is_empty():
		var row := HBoxContainer.new()
		row.name = "ShopQuantityRow"
		row.add_theme_constant_override("separation", 12)
		choices.add_child(row)
		decrement_button = _button("−", row)
		decrement_button.name = "DecreaseShopQuantity"
		decrement_button.custom_minimum_size.x = 64
		decrement_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		decrement_button.pressed.connect(func(): set_quantity(quantity - 1))
		quantity_label = _label(row, 20)
		quantity_label.name = "ShopQuantity"
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		increment_button = _button("+", row)
		increment_button.name = "IncreaseShopQuantity"
		increment_button.custom_minimum_size.x = 64
		increment_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		increment_button.pressed.connect(func(): set_quantity(quantity + 1))
		review_button = _button("Review purchase", choices)
		review_button.name = "ReviewShopPurchase"
		review_button.pressed.connect(review_purchase)
		_update_quantity_text()
	elif _minimum_price() > _wallet() and _notice.is_empty():
		notice_label.text = "You need at least %d gold in your wallet to buy a potion." % _minimum_price()

func _render_confirmation() -> void:
	var offer := _selected_offer()
	if offer.is_empty():
		body_label.text = "This item is no longer available. Go back and choose your supplies again."
		return
	body_label.text = "%s × %d · %d gold each\nTotal: %d gold · Wallet after purchase: %d gold\nCharacter-bound to this character's bag. Potion use and effects are unavailable." % [offer.label, quantity, int(offer.unit_price_gold), total_price(), _wallet() - total_price()]
	confirm_button = _button("Confirm purchase · %d gold" % total_price(), choices)
	confirm_button.name = "ConfirmShopPurchase"
	confirm_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_button.pressed.connect(confirm_purchase)
	edit_button = _button("Change selection", choices)
	edit_button.name = "ChangeShopSelection"
	edit_button.pressed.connect(return_to_browse)

func _wallet() -> int:
	if save_state != null:
		return int(save_state.wallet_gold)
	return int(_catalog.get("wallet_gold", 0))

func _minimum_price() -> int:
	var minimum := 0
	for offer in _catalog.get("offers", []):
		var price := int(offer.unit_price_gold)
		if price > 0 and (minimum == 0 or price < minimum):
			minimum = price
	return minimum

func _selected_offer() -> Dictionary:
	for offer in _catalog.get("offers", []):
		if offer.item_id == selected_item_id:
			return offer
	return {}

func maximum_quantity() -> int:
	var offer := _selected_offer()
	if offer.is_empty() or int(offer.unit_price_gold) <= 0:
		return 0
	return mini(Catalog.MAX_QUANTITY, mini(int(_catalog.get("max_quantity", Catalog.MAX_QUANTITY)), int(_wallet() / int(offer.unit_price_gold))))

func total_price() -> int:
	return quantity * int(_selected_offer().get("unit_price_gold", 0))

func _valid_selection() -> bool:
	return _catalog.get("ok", false) and not _selected_offer().is_empty() and quantity >= 1 and quantity <= maximum_quantity()

func _update_quantity_text() -> void:
	if is_instance_valid(quantity_label):
		quantity_label.text = "Quantity: %d / %d\nTotal: %d gold" % [quantity, maximum_quantity(), total_price()]
	if is_instance_valid(review_button):
		review_button.text = "Review purchase · %d gold" % total_price()

func _apply_controls() -> void:
	for id in select_buttons:
		var offer: Dictionary = {}
		for entry in _catalog.get("offers", []):
			if entry.item_id == id:
				offer = entry
		select_buttons[id].disabled = pending or not _catalog.get("ok", false) or offer.is_empty() or _wallet() < int(offer.get("unit_price_gold", 0))
	if is_instance_valid(decrement_button):
		decrement_button.disabled = pending or quantity <= 1
	if is_instance_valid(increment_button):
		increment_button.disabled = pending or quantity >= maximum_quantity()
	if is_instance_valid(review_button):
		review_button.disabled = pending or not _valid_selection()
	if is_instance_valid(confirm_button):
		confirm_button.disabled = pending or not _valid_selection()
	if is_instance_valid(edit_button):
		edit_button.disabled = pending

func select_item(item_id: String) -> void:
	if pending or _dismiss_pending or confirming or not _catalog.get("ok", false):
		return
	var valid := false
	for offer in _catalog.get("offers", []):
		if offer.item_id == item_id and _wallet() >= int(offer.unit_price_gold):
			valid = true
	if not valid:
		return
	if selected_item_id != item_id:
		transaction_id = ""
		quantity = 1
	selected_item_id = item_id
	_notice = ""
	_render()

func set_quantity(value: int) -> void:
	if pending or _dismiss_pending or confirming or selected_item_id.is_empty():
		return
	var maximum := maximum_quantity()
	if maximum < 1:
		return
	var next := clampi(value, 1, maximum)
	if next != quantity:
		transaction_id = ""
		quantity = next
		_notice = ""
		notice_label.text = ""
	_update_quantity_text()
	_apply_controls()

func review_purchase() -> void:
	if pending or _dismiss_pending or confirming or not _valid_selection():
		return
	confirming = true
	_notice = ""
	_render()

func return_to_browse() -> void:
	if pending or _dismiss_pending:
		return
	confirming = false
	_notice = ""
	_render()

func confirm_purchase() -> void:
	if pending or _dismiss_pending or not confirming or not _valid_selection():
		return
	if transaction_id.is_empty():
		transaction_id = "shop_%s_%d" % [Crypto.new().generate_random_bytes(16).hex_encode(), Time.get_ticks_usec()]
	set_pending(true)
	confirm_requested.emit(selected_item_id, quantity, transaction_id)

func set_pending(value: bool) -> void:
	pending = value
	if not is_node_ready():
		return
	_apply_controls()
	# Back remains fixed and usable while the owner resolves a transaction.

func show_error(message: String) -> void:
	pending = false
	_notice = message
	_render()

func purchase_succeeded() -> void:
	# Only the owning scene calls this after Save confirms a durable result.
	pending = false
	confirming = false
	selected_item_id = ""
	quantity = 1
	transaction_id = ""
	_notice = "Purchase saved. Your supplies are in this character's bag."
	_render()
