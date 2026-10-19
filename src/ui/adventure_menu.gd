extends Control
# Reads authoritative save state. Equipment requests remain scene-owned; stat
# allocation uses the save service only after an explicit preview and confirmation.
signal dismissed
signal inventory_requested
signal equip_requested(item: String)
signal ring_equip_requested
signal ring_unequip_requested
signal potion_requested(item: String)
signal unequip_requested
signal settings_changed(mode: String, left_handed: bool)
signal title_requested

const Ornate = preload("res://src/ui/ornate_panel.gd")
const Avatar = preload("res://src/layered_avatar.gd")
const Inventory = preload("res://src/inventory_catalog.gd")
const Catalog = preload("res://src/creator/catalog.gd")
const CORE_ATTRIBUTES := [["STR", "Strength"], ["AGI", "Agility"], ["VIT", "Vitality"], ["INT", "Intelligence"], ["WIS", "Wisdom"], ["LUK", "Luck"]]
const PAGES := {"character":"Character", "inventory":"Inventory", "stats":"Stats", "quest_log":"Quest Log", "settings":"Settings"}
const INK := Color("35291d")
const MUTED := Color("76664e")
var state
var preferences
var initial_page := "character"
var page := "character"
var character_tab := "equipment"
var selected_item := ""
var notice: Label
var sidebar: Control
var panel: Control
var body_scroll: ScrollContainer
var body: VBoxContainer
var close_button: Button
var page_buttons := {}
var title_label: Label
var subtitle_label: Label
var avatar
var portrait_stage: Control
var fixed_button: Button
var floating_button: Button
var handed_button: Button
var _dismiss_pending := false
var _portrait_height := 300.0
var _keyboard_navigation := false
var dropdown: Control
var dropdown_scroll: ScrollContainer
var dropdown_entries: GridContainer
var _dim: ColorRect
var _touch_buttons: Array[Button] = []
var stat_footer: HBoxContainer
var stat_primary: Button
var stat_cancel: Button
var stat_edit: Button
var stat_rows := {}
var stat_effect_labels := {}
var _stat_snapshot: Dictionary = {}
var _stat_deltas: Dictionary = {}
var _stat_preview: Dictionary = {}
var _stat_reviewing := false
var _stat_committing := false
const ItemIcon = preload("res://src/ui/inventory_item_icon.gd")
var inventory_row: HBoxContainer
var inventory_scroll: ScrollContainer
var inventory_content: VBoxContainer
var inventory_details: Control
var item_popup: Control
var item_container := "bag"
const PLANNED_EFFECTS := [
	["physical_power", "Physical power", "number"], ["spell_power", "Spell power", "number"],
	["max_hp", "Maximum HP", "number"], ["max_mana", "Maximum mana", "number"],
	["mana_recovery_per_second", "Mana recovery / sec", "decimal"], ["accuracy_chance", "Accuracy", "percent"],
	["auto_dodge_chance", "Auto-dodge", "percent"], ["resilience", "Resilience", "percent"],
	["critical_chance", "Critical chance", "percent"], ["rare_drop_multiplier", "Rare-drop multiplier", "multiplier"]
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_theme()
	_dim = ColorRect.new()
	_dim.color = Color(0.10, 0.12, 0.10, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	sidebar = Ornate.new()
	sidebar.name = "MenuSidebar"
	add_child(sidebar)
	var menu_title := _label("MENU", sidebar, 24, true)
	menu_title.name = "MenuTitle"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for id in PAGES:
		var button := _button(PAGES[id], sidebar)
		button.name = "Page_" + id
		button.pressed.connect(show_page.bind(id))
		page_buttons[id] = button
	panel = Ornate.new()
	panel.name = "PagePanel"
	add_child(panel)
	title_label = _label("", panel, 26, true)
	title_label.name = "PageTitle"
	subtitle_label = _label("", panel, 14)
	subtitle_label.modulate = MUTED
	close_button = _button("Close", panel)
	close_button.name = "CloseMenu"
	close_button.pressed.connect(_dismiss)
	body_scroll = ScrollContainer.new()
	body_scroll.name = "PageScroll"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus = false
	body_scroll.scroll_deadzone = 8
	panel.add_child(body_scroll)
	body = VBoxContainer.new()
	body.name = "PageBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	body_scroll.add_child(body)
	stat_footer = HBoxContainer.new()
	stat_footer.name = "StatActions"
	stat_footer.add_theme_constant_override("separation", 10)
	stat_footer.visible = false
	panel.add_child(stat_footer)
	notice = _label("", panel, 14)
	notice.name = "Notice"
	notice.max_lines_visible = 2
	_create_dropdown()
	resized.connect(_layout)
	_layout()
	show_page(initial_page)

func _setup_theme() -> void:
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/body.ttf")
	theme.default_font_size = 16
	for type in ["Label", "Button"]:
		theme.set_color("font_color", type, INK)
	for key in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(key, "Button", INK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", Ornate.make_button_style())
	theme.set_stylebox("hover", "Button", Ornate.make_button_style(true))
	theme.set_stylebox("pressed", "Button", Ornate.make_button_style(true))
	theme.set_stylebox("disabled", "Button", Ornate.make_button_style(false, true))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("267e88")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	theme.set_stylebox("focus", "Button", focus)
	# A finger-sized scrollbar supplements touch scrolling in the page body.
	theme.set_constant("scrollbar_width", "ScrollContainer", 44)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("e0d2b5")
	rail.content_margin_left = 22
	rail.content_margin_right = 22
	rail.set_corner_radius_all(7)
	theme.set_stylebox("scroll", "VScrollBar", rail)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("b39154")
	grabber.content_margin_left = 22
	grabber.content_margin_right = 22
	grabber.content_margin_top = 22
	grabber.content_margin_bottom = 22
	grabber.set_corner_radius_all(7)
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		theme.set_stylebox(style, "VScrollBar", grabber)

func _create_dropdown() -> void:
	dropdown = Ornate.new()
	dropdown.name = "HamburgerDropdown"
	dropdown.compact = true
	add_child(dropdown)
	dropdown_scroll = ScrollContainer.new()
	dropdown_scroll.name = "DropdownScroll"
	dropdown_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dropdown_scroll.scroll_deadzone = 8
	dropdown.add_child(dropdown_scroll)
	var entries := GridContainer.new()
	dropdown_entries = entries
	entries.columns = 1
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("h_separation", 8)
	entries.add_theme_constant_override("v_separation", 8)
	dropdown_scroll.add_child(entries)
	for id in PAGES:
		var entry := _button(PAGES[id], entries)
		entry.name = "Dropdown_" + id
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.pressed.connect(show_page.bind(id))
	var leave := _button("Save & title", entries)
	leave.name = "DropdownSaveAndTitle"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func(): title_requested.emit())

func _layout() -> void:
	if not is_instance_valid(panel): return
	dropdown.position = Vector2(80, 118)
	dropdown_entries.columns = 2 if size.y < 500 else 1
	dropdown.size = Vector2(minf(410 if size.y < 500 else 242, size.x - 92), minf(188 if size.y < 500 else 340, size.y - 130))
	dropdown_scroll.position = Vector2(14, 14)
	dropdown_scroll.size = dropdown.size - Vector2(28, 28)
	var margin := 12.0 if size.y < 500 else 22.0
	var available := size - Vector2.ONE * margin * 2
	var side_width := clampf(size.x * 0.215, 176, 242)
	sidebar.position = Vector2.ONE * margin
	sidebar.size = Vector2(side_width, available.y)
	var menu_title: Label = sidebar.get_node("MenuTitle")
	menu_title.position = Vector2(20, 17)
	menu_title.size = Vector2(side_width - 40, 30)
	var gap := 7.0 if size.y < 500 else 12.0
	var button_height := clampf((available.y - 90 - gap * 4) / 5, 44, 72)
	var index := 0
	for id in page_buttons:
		var button: Button = page_buttons[id]
		button.position = Vector2(16, 63 + index * (button_height + gap))
		button.size = Vector2(side_width - 32, button_height)
		index += 1
	panel.position = Vector2(margin + side_width + 14, margin)
	panel.size = Vector2(available.x - side_width - 14, available.y)
	close_button.position = Vector2(panel.size.x - 100, 17)
	close_button.size = Vector2(80, 44)
	title_label.position = Vector2(26, 15)
	title_label.size = Vector2(panel.size.x - 140, 34)
	subtitle_label.position = Vector2(26, 49)
	subtitle_label.size = Vector2(panel.size.x - 54, 22)
	var footer := 38.0 if not notice.text.is_empty() else 0.0
	if page == "stats": footer += 54
	stat_footer.position = Vector2(22, panel.size.y - 66)
	stat_footer.size = Vector2(panel.size.x - 44, 44)
	body_scroll.position = Vector2(22, 80)
	body_scroll.size = Vector2(panel.size.x - 44, maxf(80, panel.size.y - 102 - footer))
	notice.position = Vector2(26, panel.size.y - (108 if page == "stats" else 54))
	notice.size = Vector2(panel.size.x - 52, 40)
	_portrait_height = clampf(body_scroll.size.y - 58, 190, 430)
	if is_instance_valid(portrait_stage):
		portrait_stage.custom_minimum_size.y = _portrait_height
	if is_instance_valid(inventory_row):
		inventory_row.custom_minimum_size.y = body_scroll.size.y - 2
		portrait_stage.custom_minimum_size = Vector2(clampf(body_scroll.size.x * 0.29, 222, 250), body_scroll.size.y - 2)
		inventory_scroll.custom_minimum_size.y = body_scroll.size.y - 2
		_place_avatar()
	_layout_item_popup()

func show_page(id: String) -> void:
	_close_item_popup()
	if id == "quests": id = "quest_log"
	if not PAGES.has(id) and id != "menu": id = "character"
	_reset_stat_draft()
	page = id
	if not is_node_ready():
		initial_page = id
		return
	stat_footer.visible = page == "stats"
	dropdown.visible = page == "menu"
	sidebar.visible = page != "menu"
	panel.visible = page != "menu"
	_dim.color.a = 0.15 if page == "menu" else 0.78
	if page == "menu":
		dropdown_scroll.scroll_vertical = 0
		_layout()
		return
	_clear_body()
	notice.text = ""
	title_label.text = PAGES[page].to_upper()
	subtitle_label.text = _identity_summary() if page == "character" else "Saved on this device"
	for key in page_buttons:
		_set_active(page_buttons[key], key == page)
	match page:
		"character": _build_character()
		"inventory": _build_inventory()
		"stats": _build_stats()
		"quest_log": _build_quests()
		"settings": _build_settings()
	body_scroll.scroll_vertical = 0
	_layout()

func refresh_state() -> void:
	# Rebuild from the authoritative object, never a local inventory copy.
	var previous_notice := notice.text if is_instance_valid(notice) else ""
	var previous_error := is_instance_valid(notice) and notice.get_theme_color("font_color") == Color("9c3027")
	var previous_scroll := body_scroll.scroll_vertical if is_instance_valid(body_scroll) else 0
	show_page(page)
	set_notice(previous_notice, previous_error)
	body_scroll.set_deferred("scroll_vertical", previous_scroll)

func set_notice(message: String, is_error: bool = false) -> void:
	if not is_instance_valid(notice): return
	notice.text = message
	notice.add_theme_color_override("font_color", Color("9c3027") if is_error else Color("346b61"))
	if is_error and is_instance_valid(item_popup):
		var popup_notice = item_popup.find_child("ItemActionNotice", true, false)
		if popup_notice != null:
			popup_notice.text = message
			popup_notice.show()
			item_popup.find_child("ItemDetailScroll", true, false).set_deferred("scroll_vertical", 0)
	_layout()

func _clear_body() -> void:
	_release_touch_owners()
	_touch_buttons = _touch_buttons.filter(func(button): return is_instance_valid(button) and not body.is_ancestor_of(button))
	avatar = null
	portrait_stage = null
	inventory_row = null
	inventory_scroll = null
	inventory_content = null
	inventory_details = null
	fixed_button = null
	floating_button = null
	handed_button = null
	stat_rows = {}
	stat_effect_labels = {}
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _character() -> Dictionary:
	return state.character if state != null else {}

func _identity_summary() -> String:
	var character := _character()
	return "%s  ·  %s" % [character.get("username", "No local character"), character.get("class", "Class unavailable")]

func _build_character() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	body.add_child(tabs)
	for id in ["equipment", "details"]:
		var tab := _button(id.capitalize(), tabs)
		tab.name = "CharacterTab_" + id
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_active(tab, id == character_tab)
		tab.pressed.connect(func():
			character_tab = id
			show_page("character")
		)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	if character_tab == "equipment":
		var armor_side := VBoxContainer.new()
		armor_side.name = "ArmorSide"
		armor_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		armor_side.custom_minimum_size.x = 140
		armor_side.size_flags_stretch_ratio = 0.7
		columns.add_child(armor_side)
		var armor := _card(armor_side, "ARMOR", _armor_label())
		_label("Equipped starting outfit · Character-bound", armor, 13).modulate = MUTED
		_card(armor_side, "RING", "Keepsake ring · Character-bound" if state != null and not state.equipped_ring.is_empty() else "No ring equipped")
		_make_portrait(columns)
		_add_equipment_slots()
		var weapon_side := VBoxContainer.new()
		weapon_side.name = "WeaponSide"
		weapon_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_side.custom_minimum_size.x = 140
		weapon_side.size_flags_stretch_ratio = 0.7
		columns.add_child(weapon_side)
		var weapon_id := str(state.equipped_weapon) if state != null else ""
		var weapon := _card(weapon_side, "WEAPON", _weapon_label(weapon_id))
		_label("Equipped" if not weapon_id.is_empty() else "No weapon equipped", weapon, 13).modulate = MUTED
		_label("Manage equipment in Inventory.", weapon_side, 14).modulate = MUTED
	else:
		_make_portrait(columns)
		var character := _character()
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.custom_minimum_size.x = 200
		details.add_theme_constant_override("separation", 10)
		columns.add_child(details)
		var identity := _card(details, "IDENTITY", str(character.get("username", "Unavailable")))
		_label("Class: " + str(character.get("class", "Unavailable")), identity, 14)
		_label("Body: " + str(character.get("base", "Unavailable")).capitalize(), identity, 14)
		var earned: Dictionary = state.get_progression_summary()
		_label("Level %d · XP %d / %d" % [earned.level,earned.xp,earned.xp_required],identity,14)
		_label("Name, class and body are fixed for this character.", identity, 13).modulate = MUTED
		var stat_summary: Dictionary = state.get_stat_summary() if state != null and state.has_method("get_stat_summary") else {}
		var current_stats: Array[String] = []
		if stat_summary.get("ok", false):
			for attribute in CORE_ATTRIBUTES:
				current_stats.append("%s %d" % [attribute[0], int(stat_summary.attributes[attribute[0]])])
		var attributes := _card(details, "CORE ATTRIBUTES", "  ·  ".join(current_stats) if not current_stats.is_empty() else "Stats unavailable")
		_label("Strength · Agility · Vitality · Intelligence · Wisdom · Luck", attributes, 13).modulate = MUTED
		_label("All six start at 10. Level-ups grant 5 points for STR, AGI, VIT, INT and WIS. Luck grows only through XP.", attributes, 14).modulate = MUTED
		var values := _card(details, "PLANNED COMBAT VALUES", "View provisional bonuses in Stats.")
		_label("HP/MP caps and mana recovery are active in the field. Basic attacks gain +1 per weapon upgrade and half of STR above 10. Other displayed effects remain planned.", values, 13).modulate = MUTED

func _make_portrait(parent: Node) -> void:
	portrait_stage = Ornate.new()
	portrait_stage.name = "SavedAvatarStage"
	portrait_stage.custom_minimum_size = Vector2(180, _portrait_height)
	portrait_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_stage.size_flags_stretch_ratio = 1.3
	portrait_stage.clip_contents = true
	parent.add_child(portrait_stage)
	portrait_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var character := _character()
	if character.is_empty(): return
	avatar = Avatar.new()
	avatar.name = "SavedLayeredAvatar"
	portrait_stage.add_child(avatar)
	avatar.configure(str(character.get("base", "")), str(character.get("class", "")), character)
	avatar.set_equipped_weapon(str(state.equipped_weapon))
	avatar.set_cosmetic_dye(str(state.cosmetics.equipped.armor_dye))
	avatar.advance(0, false, 0)
	portrait_stage.resized.connect(_place_avatar)
	_place_avatar()
	if not avatar.artwork_ready:
		var missing := _label("Character artwork unavailable", portrait_stage)
		missing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _place_avatar() -> void:
	if not is_instance_valid(avatar) or not is_instance_valid(portrait_stage): return
	var reserved := 78.0 if portrait_stage.has_meta("equipment_footer") else 0.0
	var usable := portrait_stage.size - Vector2(30, 30 + reserved)
	var factor := minf(usable.x / 256.0, usable.y / 256.0)
	factor = maxf(0.1, factor)
	avatar.scale = Vector2.ONE * factor
	avatar.position = Vector2(portrait_stage.size.x * 0.5, (portrait_stage.size.y - reserved) * 0.5 + 104 * factor)

func _build_inventory() -> void:
	inventory_row = HBoxContainer.new()
	inventory_row.name = "InventorySplit"
	inventory_row.add_theme_constant_override("separation", 12)
	inventory_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(inventory_row)
	_make_portrait(inventory_row)
	portrait_stage.name = "InventoryCharacter"
	_add_equipment_slots()
	portrait_stage.size_flags_horizontal = Control.SIZE_FILL
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.name = "OwnedItemsScroll"
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_row.add_child(inventory_scroll)
	inventory_content = VBoxContainer.new()
	inventory_content.name = "OwnedItems"
	inventory_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_content.add_theme_constant_override("separation", 10)
	inventory_scroll.add_child(inventory_content)
	if state == null:
		_label("No local character is available.", inventory_content)
		return
	_label("Wallet: %d gold · %d Sigils" % [state.wallet_gold,state.wallet_sigils], inventory_content, 16, true)
	var owned: Array[String] = []
	for id in Inventory.LABELS:
		if int(state.bag.get(id, 0)) > 0: owned.append(id)
	owned.sort_custom(func(a, b): return Inventory.LABELS[a].naturalnocasecmp_to(Inventory.LABELS[b]) < 0)
	if owned.is_empty():
		_card(inventory_content, "YOUR BAG", "Your bag is empty. Collect supplies from your storage chest.")
		return
	if selected_item not in owned: selected_item = owned[0]
	_label("YOUR BAG", inventory_content, 18, true)
	for id in owned:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		inventory_content.add_child(row)
		var inspect := _button("%s  × %d" % [Inventory.LABELS[id], int(state.bag[id])], row)
		inspect.name = "Inspect_" + id
		inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inspect.alignment = HORIZONTAL_ALIGNMENT_LEFT
		inspect.custom_minimum_size.y = 64
		inspect.clip_text = true
		inspect.tooltip_text = Inventory.LABELS[id] + " × " + str(state.bag[id])
		_set_active(inspect, selected_item == id)
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style = inspect.get_theme_stylebox(style_name).duplicate()
			style.content_margin_left = 62
			inspect.add_theme_stylebox_override(style_name, style)
		var icon = ItemIcon.new()
		inspect.add_child(icon)
		icon.configure(id, str(_character().get("base", "male")))
		icon.position = Vector2(5, 6)
		icon.size = Vector2(52, 52)
		inspect.pressed.connect(func():
			_open_item_popup(id, "bag")
		)
	_label("Tap an item or equipment slot for details.", inventory_content, 14).modulate = MUTED

func _build_equipped_inventory() -> void:
	if state != null:
		var ring_card := _card(inventory_content, "RING", "Keepsake ring" if not state.equipped_ring.is_empty() else "No ring equipped")
		if not state.equipped_ring.is_empty():
			_add_item_icon(ring_card, str(state.equipped_ring))
			var remove_ring := _button("Unequip ring to bag", ring_card)
			remove_ring.name = "UnequipRing"
			remove_ring.pressed.connect(func(): ring_unequip_requested.emit())
	if state != null:
		var armor_card := _card(inventory_content, "WORN ARMOR", str(state.equipped_armor).replace("_01_armor", " armor").capitalize())
		_add_item_icon(armor_card, str(state.equipped_armor))
	var equipped := _card(inventory_content, "EQUIPPED WEAPON", _weapon_label(str(state.equipped_weapon) if state != null else ""))
	if state != null and not str(state.equipped_weapon).is_empty():
		_add_item_icon(equipped, str(state.equipped_weapon))
		var unequip := _button("Unequip to bag", equipped)
		unequip.name = "UnequipWeapon"
		unequip.pressed.connect(func(): unequip_requested.emit())

func _add_item_icon(parent: Node, id: String) -> void:
	var icon = ItemIcon.new()
	parent.add_child(icon)
	icon.configure(id, str(_character().get("base", "male")))
	icon.custom_minimum_size = Vector2(52, 52)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func _reveal_inventory_details() -> void:
	await get_tree().process_frame
	if page != "inventory" or not is_instance_valid(inventory_details) or not is_instance_valid(inventory_scroll): return
	inventory_scroll.scroll_vertical = int(inventory_details.get_parent().position.y)

func _add_equipment_slots() -> void:
	portrait_stage.set_meta("equipment_footer", true)
	portrait_stage.custom_minimum_size.x = maxf(222, portrait_stage.custom_minimum_size.x)
	var slot_index := 0
	for data in [["Weapon",state.equipped_weapon,"equipped_weapon",Vector2(0,0)], ["Armor",state.equipped_armor,"equipped_armor",Vector2(1,0)], ["Ring",state.equipped_ring,"equipped_ring",Vector2(0,1)]]:
		var button := _button("", portrait_stage)
		button.name = "EquipmentSlot_" + data[2]
		button.custom_minimum_size = Vector2(58,58)
		button.size = Vector2(58,58)
		button.clip_text = true
		button.tooltip_text = data[0]
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var icon = ItemIcon.new()
		button.add_child(icon)
		icon.position = Vector2(3,3)
		icon.size = Vector2(52,52)
		if not str(data[1]).is_empty(): icon.configure(data[1], str(_character().get("base","male")))
		else:
			icon.hide()
			button.text = data[0]
			button.add_theme_font_size_override("font_size",12)
		var column := slot_index
		slot_index += 1
		var place := func(): button.position = Vector2((portrait_stage.size.x - 186) * 0.5 + column * 64, maxf(12,portrait_stage.size.y-74))
		portrait_stage.resized.connect(place)
		place.call()
		button.pressed.connect(func():
			if not str(data[1]).is_empty(): _open_item_popup(data[1],data[2])
			else: set_notice("This %s slot is empty. Choose an item from your bag." % str(data[0]).to_lower())
		)

func _close_item_popup() -> void:
	if is_instance_valid(item_popup):
		_release_touch_owners()
		_touch_buttons = _touch_buttons.filter(func(button): return is_instance_valid(button) and not item_popup.is_ancestor_of(button))
		remove_child(item_popup)
		item_popup.queue_free()
	item_popup = null

func _open_item_popup(id: String, container: String) -> void:
	_close_item_popup()
	_release_touch_owners()
	selected_item = id
	item_container = container
	item_popup = Control.new()
	item_popup.name = "ItemPopup"
	item_popup.z_index = 10 # Above preview weapon layers as well as the dimming shade.
	item_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(item_popup)
	var shade := ColorRect.new()
	shade.color = Color(0.08,0.10,0.08,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_popup.add_child(shade)
	var frame := Ornate.new()
	frame.name = "ItemPopupFrame"
	item_popup.add_child(frame)
	frame.size = Vector2(minf(560,size.x-32),minf(490,size.y-24))
	frame.position = (size-frame.size)*0.5
	var close := _button("Close",frame)
	close.name = "CloseItemPopup"
	close.position = Vector2(frame.size.x-106,16)
	close.size = Vector2(86,44)
	close.pressed.connect(_close_item_popup)
	var heading := _label("ITEM DETAILS",frame,20,true)
	heading.name = "ItemPopupHeading"
	heading.position = Vector2(22,22)
	heading.size = Vector2(frame.size.x-150,32)
	var scroll := ScrollContainer.new()
	scroll.name = "ItemDetailScroll"
	frame.add_child(scroll)
	scroll.position = Vector2(20,68)
	scroll.size = frame.size-Vector2(40,88)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	var popup_notice := _label("", content, 15)
	popup_notice.name = "ItemActionNotice"
	popup_notice.add_theme_color_override("font_color", Color("9c3027"))
	popup_notice.hide()
	_build_item_details(content)
	var popup_buttons: Array[Button] = []
	for button in _touch_buttons:
		if is_instance_valid(button) and item_popup.is_ancestor_of(button) and not button.disabled: popup_buttons.append(button)
	for i in popup_buttons.size():
		var previous: NodePath = popup_buttons[posmod(i-1,popup_buttons.size())].get_path()
		var following: NodePath = popup_buttons[(i+1)%popup_buttons.size()].get_path()
		popup_buttons[i].focus_previous = previous
		popup_buttons[i].focus_next = following
		popup_buttons[i].focus_neighbor_top = previous
		popup_buttons[i].focus_neighbor_bottom = following
		popup_buttons[i].focus_neighbor_left = previous
		popup_buttons[i].focus_neighbor_right = following
	_layout_item_popup()
	close.grab_focus()

func _layout_item_popup() -> void:
	if not is_instance_valid(item_popup): return
	var frame = item_popup.get_node_or_null("ItemPopupFrame")
	if frame == null or not frame.has_node("ItemDetailScroll"): return
	frame.size = Vector2(minf(560,size.x-32),minf(490,size.y-24))
	frame.position = (size-frame.size)*0.5
	frame.get_node("CloseItemPopup").position = Vector2(frame.size.x-106,16)
	frame.get_node("ItemPopupHeading").size = Vector2(frame.size.x-150,32)
	frame.get_node("ItemDetailScroll").size = frame.size-Vector2(40,88)

func _weapon_damage(id: String, container: String) -> int:
	if id.is_empty(): return 0
	var details: Dictionary = state.get_item_details(id,container)
	var summary: Dictionary = state.get_stat_summary()
	return (1000 if id == "hidden_old_stick" else 12) + int(details.get("upgrade_level",0)) + int((summary.attributes.STR-10)*0.5)

func _build_item_details(parent: Node = null) -> void:
	if parent == null: parent = inventory_content
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",8)
	parent.add_child(info)
	inventory_details = info
	var item: Dictionary = state.get_item_details(selected_item,item_container)
	var identity := HBoxContainer.new()
	info.add_child(identity)
	_add_item_icon(identity,selected_item)
	_label(Inventory.LABELS.get(selected_item,_armor_label()),identity,18,true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	info.add_child(actions)
	if item_container == "bag" and Inventory.WEAPONS.has(selected_item):
		var equip := _button("Equip" if state.equipped_weapon.is_empty() else "Equip & swap",actions)
		equip.name = "Equip_" + selected_item
		equip.disabled = not Inventory.can_equip(selected_item,str(_character().get("class","")))
		equip.pressed.connect(func(): equip_requested.emit(selected_item))
	elif item_container == "bag" and selected_item == "keepsake_ring":
		var equip := _button("Equip ring",actions)
		equip.name = "EquipRing"
		equip.pressed.connect(func(): ring_equip_requested.emit())
	elif item_container == "bag" and selected_item in ["healing_potion","mana_potion"]:
		var use := _button("Use potion",actions)
		use.name = "Use_" + selected_item
		use.pressed.connect(func(): potion_requested.emit(selected_item))
	elif item_container in ["equipped_weapon","equipped_ring"]:
		var remove := _button("Unequip to bag",actions)
		remove.name = "UnequipWeapon" if item_container == "equipped_weapon" else "UnequipRing"
		remove.pressed.connect(func():
			if item_container == "equipped_weapon": unequip_requested.emit()
			else: ring_unequip_requested.emit()
		)
	_label("Count: %d · %s" % [int(state.bag.get(selected_item,0)) if item_container == "bag" else 1,"In bag" if item_container == "bag" else "Equipped"],info,14)
	_label("Character-bound" if item.get("binding","") == "character" else "Unbound",info,14)
	if selected_item in ["healing_potion","mana_potion"]:
		_label("Restores 40 HP." if selected_item == "healing_potion" else "Restores 25 MP.",info,16)
		_label("No potion consumed at full health/mana. Shared 3-second cooldown.",info,14)
	elif Inventory.WEAPONS.has(selected_item):
		var damage := _weapon_damage(selected_item,item_container)
		_label("Basic strike: %s damage" % str(damage),info,18,true)
		var difference := damage - _weapon_damage(state.equipped_weapon,"equipped_weapon")
		var comparison := _label("%+d damage compared with equipped weapon" % difference,info,15)
		comparison.add_theme_color_override("font_color",Color("28723d") if difference > 0 else (Color("a32e26") if difference < 0 else MUTED))
		_label("Upgrade +%d · Strength included" % int(item.get("upgrade_level",0)),info,14)
		_label("All classes" if selected_item == "hidden_old_stick" else str(Inventory.WEAPONS[selected_item].class_id)+" only",info,14)
		if not Inventory.can_equip(selected_item,str(_character().get("class",""))): _label("Your class cannot equip this weapon.",info,14).modulate = Color("a32e26")
		_label("Unique hidden find." if selected_item == "hidden_old_stick" else "A dependable starter weapon.",info,14)
		_label("Swapping keeps your old weapon in the bag. Class skills have separate damage values.",info,14).modulate = MUTED
	else:
		_label("A personal keepsake. No numeric combat bonus." if selected_item == "keepsake_ring" else "Your class outfit. Cosmetic dyes change its color; no numeric armor bonus is active.",info,14)

func _reset_stat_draft() -> void:
	_stat_snapshot = {}
	_stat_deltas = {}
	_stat_preview = {}
	_stat_reviewing = false
	_stat_committing = false

func _stat_total() -> int:
	var total := 0
	for value in _stat_deltas.values(): total += int(value)
	return total

func _build_stats() -> void:
	if _stat_snapshot.is_empty():
		_stat_snapshot = state.get_stat_summary() if state != null and state.has_method("get_stat_summary") else {"ok":false, "message":"No local character is available."}
	_clear_stat_actions()
	if not _stat_snapshot.get("ok", false):
		_card(body, "CORE ATTRIBUTES", str(_stat_snapshot.get("message", "Your local stats are unavailable.")))
		subtitle_label.text = "No points have been spent"
		return
	if _stat_reviewing:
		_build_stat_review()
	else:
		_build_stat_grid()
	_build_planned_effects()
	_build_stat_actions()
	_sync_stat_controls()

func _build_stat_grid() -> void:
	var grid := GridContainer.new()
	grid.name = "CoreStatGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for attribute in CORE_ATTRIBUTES:
		var key: String = attribute[0]
		var card := PanelContainer.new()
		card.name = "Stat_" + key
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f5ecd9")
		style.border_color = Color("c7ae75")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", style)
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		card.add_child(row)
		if key == "LUK":
			_build_luck_progress(row)
			continue
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.custom_minimum_size.x = 78
		identity.add_theme_constant_override("separation", 0)
		row.add_child(identity)
		_label(key, identity, 18, true)
		_label(attribute[1], identity, 13).modulate = MUTED
		var minus := _button("−", row)
		minus.name = "StatMinus_" + key
		minus.custom_minimum_size.x = 44
		minus.tooltip_text = "Remove one draft point from " + attribute[1]
		minus.pressed.connect(_change_stat.bind(key, -1))
		var value := _label("", row, 17)
		value.name = "StatValue_" + key
		value.custom_minimum_size.x = 48
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var plus := _button("+", row)
		plus.name = "StatPlus_" + key
		plus.custom_minimum_size.x = 44
		plus.tooltip_text = "Add one draft point to " + attribute[1]
		plus.pressed.connect(_change_stat.bind(key, 1))
		stat_rows[key] = {"minus":minus, "plus":plus, "value":value}
	var help := _label("Use + / − to plan your points. Only Confirm saves them.", body, 14)
	help.name = "StatHelp"
	help.modulate = MUTED
	_label("Luck grows through XP. XP earning is not available yet. Monster XP advances character level.", body, 13).modulate = MUTED

func _build_luck_progress(row: HBoxContainer) -> void:
	row.add_theme_constant_override("separation", 14)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 80
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 0)
	row.add_child(identity)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	identity.add_child(heading)
	var name_label := _label("LUK", heading, 18, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value := _label("", heading, 17)
	value.name = "StatValue_LUK"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label("Luck", identity, 13).modulate = MUTED
	var progress := VBoxContainer.new()
	progress.name = "LuckProgress"
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_theme_constant_override("separation", 5)
	row.add_child(progress)
	var xp_label := _label("", progress, 13)
	xp_label.name = "LuckXPLabel"
	xp_label.modulate = MUTED
	var xp_bar := ProgressBar.new()
	xp_bar.name = "LuckXPBar"
	xp_bar.custom_minimum_size = Vector2(90, 10)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	xp_bar.tooltip_text = "Luck grows only through XP. XP earning is not available yet."
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("dfd2b4")
	rail.border_color = Color("b39154")
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("background", rail)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("397c72")
	fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("fill", fill)
	progress.add_child(xp_bar)
	stat_rows.LUK = {"value":value, "xp_label":xp_label, "xp_bar":xp_bar}

func _build_stat_review() -> void:
	var review := _card(body, "REVIEW ALLOCATION", "Spend %d points · %d will remain" % [_stat_total(), int(_stat_preview.get("unspent_points", 0))])
	review.name = "StatReview"
	var changes: Array[String] = []
	for attribute in CORE_ATTRIBUTES:
		var key: String = attribute[0]
		if int(_stat_deltas.get(key, 0)) > 0:
			changes.append("%s  %d → %d (+%d)" % [key, int(_stat_snapshot.attributes[key]), int(_stat_preview.attributes[key]), int(_stat_deltas[key])])
	_label("   ·   ".join(changes), review, 17)
	_label("Confirm permanently spends these points. Cancel keeps your saved stats.", review, 14).modulate = MUTED

func _build_planned_effects() -> void:
	var section := _card(body, "STAT EFFECTS · PARTIAL", "HP/MP caps and mana recovery are active. Basic strike uses STR above 10 and the starter weapon upgrade. Other damage/chance values below remain previews.")
	section.name = "PlannedStatEffects"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 9)
	section.add_child(grid)
	for definition in PLANNED_EFFECTS:
		var value := _label("", grid, 14)
		value.name = "StatEffect_" + definition[0]
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_effect_labels[definition[0]] = value
	_label("All attributes start at 10. Each level after 1 grants 5 points for the other five stats; Luck grows through XP. Chance bonuses use diminishing returns; tuning may change.", section, 13).modulate = MUTED

func _clear_stat_actions() -> void:
	_release_touch_owners()
	_touch_buttons = _touch_buttons.filter(func(button): return is_instance_valid(button) and not stat_footer.is_ancestor_of(button))
	for child in stat_footer.get_children():
		stat_footer.remove_child(child)
		child.queue_free()
	stat_primary = null
	stat_cancel = null
	stat_edit = null

func _build_stat_actions() -> void:
	# Primary action follows the preferred action-hand side, and remains outside
	# the scroller for both layouts.
	var order := ["cancel", "edit", "primary"]
	if _left_handed(): order.reverse()
	for action in order:
		if action == "edit" and not _stat_reviewing: continue
		var button := _button("", stat_footer)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match action:
			"cancel":
				stat_cancel = button
				button.name = "StatCancel"
				button.text = "Cancel"
				button.pressed.connect(_cancel_stat_draft)
			"edit":
				stat_edit = button
				button.name = "StatEdit"
				button.text = "Edit points"
				button.pressed.connect(_edit_stat_draft)
			"primary":
				stat_primary = button
				button.name = "StatConfirm" if _stat_reviewing else "StatPreview"
				button.pressed.connect(_confirm_stat_draft if _stat_reviewing else _preview_stat_draft)
				_set_active(button, true)

func _format_stat_effect(value: float, kind: String) -> String:
	match kind:
		"percent": return "%.2f%%" % (value * 100.0)
		"decimal": return "%.1f" % value
		"multiplier": return "%.3f×" % value
	return str(int(round(value)))

func _sync_stat_controls() -> void:
	if not _stat_snapshot.get("ok", false): return
	var spent := _stat_total()
	var unspent := int(_stat_snapshot.unspent_points)
	var remaining := unspent - spent
	subtitle_label.text = "Level %d  ·  %d unspent  ·  %d in draft" % [int(_stat_snapshot.level), unspent, spent]
	if unspent == 0: subtitle_label.text = "Level %d  ·  No points available  ·  5 per level-up" % int(_stat_snapshot.level)
	for key in stat_rows:
		var row: Dictionary = stat_rows[key]
		var saved := int(_stat_snapshot.attributes[key])
		if key == "LUK":
			row.value.text = str(saved)
			row.xp_label.text = "%d / %d XP" % [int(_stat_snapshot.luck_xp), int(_stat_snapshot.luck_xp_required)]
			row.xp_bar.max_value = maxf(1, float(_stat_snapshot.luck_xp_required))
			row.xp_bar.value = float(_stat_snapshot.luck_xp)
			continue
		var added := int(_stat_deltas.get(key, 0))
		row.value.text = "%d" % saved if added == 0 else "%d\n+%d" % [saved, added]
		row.value.add_theme_color_override("font_color", Color("236f68") if added > 0 else INK)
		row.minus.disabled = added <= 0 or _stat_committing
		row.plus.disabled = remaining <= 0 or _stat_committing
	if is_instance_valid(stat_primary):
		stat_primary.text = "Confirm %d points" % spent if _stat_reviewing else ("Preview %d points" % spent if spent > 0 else "Preview allocation")
		stat_primary.disabled = spent <= 0 or _stat_committing
	if is_instance_valid(stat_cancel): stat_cancel.disabled = spent <= 0 or _stat_committing
	if is_instance_valid(stat_edit): stat_edit.disabled = _stat_committing
	var proposed: Dictionary = _stat_snapshot
	if not _stat_preview.is_empty(): proposed = _stat_preview
	for definition in PLANNED_EFFECTS:
		var key: String = definition[0]
		var current := float(_stat_snapshot.get("planned_effects", {}).get(key, 0))
		var future := float(proposed.get("planned_effects", {}).get(key, current))
		var formatted := _format_stat_effect(current, definition[2])
		if not is_equal_approx(current, future): formatted += " → " + _format_stat_effect(future, definition[2])
		stat_effect_labels[key].text = definition[1] + ": " + formatted

func _change_stat(key: String, change: int) -> void:
	if page != "stats" or _stat_reviewing or _stat_committing or _dismiss_pending or not _stat_snapshot.get("ok", false): return
	if key == "LUK" or change not in [-1, 1] or not _stat_snapshot.attributes.has(key): return
	var current := int(_stat_deltas.get(key, 0))
	if change == -1 and current <= 0: return
	if change == 1 and _stat_total() >= int(_stat_snapshot.unspent_points): return
	var candidate := _stat_deltas.duplicate(true)
	candidate[key] = current + change
	if int(candidate[key]) == 0: candidate.erase(key)
	if candidate.is_empty():
		_stat_deltas = {}
		_stat_preview = {}
	else:
		var result: Dictionary = state.preview_stat_allocation(candidate, int(_stat_snapshot.revision))
		if not result.get("ok", false):
			_stat_failure(result)
			return
		_stat_deltas = candidate
		_stat_preview = result
	if not notice.text.is_empty(): set_notice("")
	_sync_stat_controls()

func _preview_stat_draft() -> void:
	if page != "stats" or _stat_reviewing or _stat_committing or _dismiss_pending or _stat_total() <= 0: return
	var result: Dictionary = state.preview_stat_allocation(_stat_deltas, int(_stat_snapshot.revision))
	if not result.get("ok", false):
		_stat_failure(result)
		return
	_stat_preview = result
	_stat_reviewing = true
	notice.text = ""
	_redraw_stats(false)

func _edit_stat_draft() -> void:
	if not _stat_reviewing or _stat_committing or _dismiss_pending: return
	_stat_reviewing = false
	_redraw_stats(false)

func _cancel_stat_draft() -> void:
	if _stat_committing or _dismiss_pending: return
	_reset_stat_draft()
	notice.text = ""
	_redraw_stats(true)

func _confirm_stat_draft() -> void:
	if page != "stats" or not _stat_reviewing or _stat_committing or _dismiss_pending or _stat_total() <= 0: return
	_stat_committing = true
	_sync_stat_controls()
	var result: Dictionary = state.allocate_stat_points(_stat_deltas.duplicate(true), int(_stat_snapshot.revision))
	_stat_committing = false
	if not result.get("ok", false):
		_stat_failure(result)
		return
	_reset_stat_draft()
	_stat_snapshot = state.get_stat_summary()
	_redraw_stats(false)
	set_notice("Points saved. Planned effects are not active in gameplay.")

func _stat_failure(result: Dictionary) -> void:
	# Reload authority after stale or failed writes. No stale draft can be confirmed
	# a second time, and failed persistence never changes the displayed saved values.
	_reset_stat_draft()
	_redraw_stats(true)
	set_notice(str(result.get("message", "Points were not saved. Please try again.")), true)

func _redraw_stats(preserve_scroll: bool) -> void:
	var previous_scroll := body_scroll.scroll_vertical if preserve_scroll else 0
	_clear_body()
	_build_stats()
	_layout()
	body_scroll.set_deferred("scroll_vertical", previous_scroll)

func _build_quests() -> void:
	if state == null:
		_card(body, "TUTORIAL", "No character loaded.")
		return
	var progress = load("res://src/tutorial_progress.gd")
	var forest_stages := ["forest_patrol_active", "return_guild_forest", "forest_patrol_complete"]
	var heading := "WESTERN FOREST · COMPLETE" if state.tutorial.stage == "forest_patrol_complete" else ("WESTERN FOREST · IN PROGRESS" if state.tutorial.stage in forest_stages else ("TUTORIAL · COMPLETE" if state.tutorial.stage == "tutorial_complete" else "TUTORIAL · IN PROGRESS"))
	_card(body, heading, progress.objective(state.tutorial))
	_card(body, "WILDERNESS GROUPS", "Slimes roam the South Meadow; wolves roam the western woods. Follow the roadside signs. You can fight without a quest. Defeated monsters return after 25 seconds; repeat fights earn gold and XP. Main roads are safe.")
	for group in state.Rewards.ENCOUNTERS:
		if state.tutorial.stage == state.Rewards.ENCOUNTERS[group].stage:
			_label("Assignment kills: %d / %d · Only kills after acceptance count." % [state.progression.population.quest_kills[group],state.Rewards.ENCOUNTERS[group].count],body,16,true)
	if progress.STAGES.find(state.tutorial.stage) < progress.STAGES.find("first_combat_active"):
		var tasks := [
			["read_envelope", "Read the envelope outside home."],
			["blacksmith_upgrade_applied", "Finish the blacksmith’s free +1 lesson."],
			["apothecary_claim_gift", "Collect the apothecary’s gift."],
			["general_store_claim_keepsake", "Collect the general store keepsake."]]
		var lines := ""
		for task in tasks:
			var done: bool = state.tutorial.action_receipts.has(task[0]) or state.tutorial.event_receipts.has(task[0])
			lines += ("Done: " if done else "Pending: ") + task[1] + "\n"
		_card(body, "UNLOCK THE FIRST MONSTER ASSIGNMENT", lines + "Report to the guild between errands. After the keepsake, speak to the receptionist and choose Accept: clear the South Meadow.")
	_label("Guild assignments reward you once, when you report back. Progress and rewards are saved for this character.", body, 16).modulate = MUTED
	var receipts: Dictionary = state.tutorial.get("reward_receipts", {})
	for reward in receipts:
		var names := {"tutorial.blacksmith.upgrade_supplies":"Blacksmith upgrade supplies", "tutorial.apothecary.mana_potions":"Five mana potions", "tutorial.general_store.keepsake_ring":"Keepsake ring", "tutorial.guild.first_combat_gold":"First assignment · 25 gold", "guild.west_forest_patrol.gold":"Western Forest patrol · 40 gold"}
		_card(body, "RECEIVED", names.get(reward, reward))

func _build_settings() -> void:
	var controls := _card(body, "MOVEMENT CONTROLS", "Choose how the joystick appears.")
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	controls.add_child(modes)
	fixed_button = _button("Fixed", modes)
	fixed_button.name = "FixedJoystick"
	floating_button = _button("Floating", modes)
	floating_button.name = "FloatingJoystick"
	for button in [fixed_button, floating_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fixed_button.pressed.connect(func(): _request_settings("fixed", _left_handed()))
	floating_button.pressed.connect(func(): _request_settings("floating", _left_handed()))
	_label("Fixed stays in one place. Floating begins where you touch the movement area.", controls, 14).modulate = MUTED
	var layout := _card(body, "CONTROL LAYOUT", "Handedness is independent of joystick mode.")
	handed_button = _button("", layout)
	handed_button.name = "LeftHandedToggle"
	handed_button.pressed.connect(func(): _request_settings(_control_mode(), not _left_handed()))
	_label("Left-handed layout puts movement on the right and actions on the left.", layout, 14).modulate = MUTED
	var session := _card(body, "LOCAL ADVENTURE", "Control preferences are saved separately from your character.")
	var leave := _button("Save and return to title", session)
	leave.name = "SaveAndTitle"
	leave.pressed.connect(func(): title_requested.emit())
	sync_preferences()

func sync_preferences() -> void:
	if not is_instance_valid(fixed_button): return
	_set_active(fixed_button, _control_mode() == "fixed")
	_set_active(floating_button, _control_mode() == "floating")
	handed_button.text = "Left-handed: " + ("On" if _left_handed() else "Off")
	_set_active(handed_button, _left_handed())

func _control_mode() -> String:
	return str(preferences.mode) if preferences != null else "fixed"

func _left_handed() -> bool:
	return bool(preferences.left_handed) if preferences != null else false

func _request_settings(mode: String, left_handed: bool) -> void:
	settings_changed.emit(mode, left_handed)
	# A synchronous parent may already have saved or rejected this request.
	# Either way, redraw from the authoritative preference values.
	sync_preferences()

func _armor_label() -> String:
	if state == null or str(state.equipped_armor).is_empty(): return "None equipped"
	var selected_class := str(_character().get("class", ""))
	if Inventory.armor_allowed(str(state.equipped_armor), selected_class):
		return selected_class + " starting outfit"
	return "Equipment unavailable"

func _weapon_label(id: String) -> String:
	if id.is_empty(): return "None equipped"
	var value := str(Inventory.LABELS.get(id, "Equipment unavailable"))
	if state != null and id == state.equipped_weapon:
		var level: int = state.weapon_upgrade_level("equipped_weapon")
		if level > 0: value += " +%d" % level
	return value

func _card(parent: Node, heading: String, description: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5ecd9")
	style.border_color = Color("c7ae75")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	_label(heading, column, 16, true).modulate = Color("7b5b2b")
	if not description.is_empty(): _label(description, column, 16)
	return column

func _label(value: String, parent: Node, font_size: int = 16, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	if heading: label.add_theme_font_override("font", preload("res://assets/fonts/title.ttf"))
	parent.add_child(label)
	return label

func _button(value: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	_bind_extra_touch(button)
	button.focus_entered.connect(func():
		if _keyboard_navigation and is_instance_valid(inventory_scroll) and inventory_scroll.is_ancestor_of(button):
			inventory_scroll.ensure_control_visible(button)
		elif _keyboard_navigation and body_scroll.is_ancestor_of(button): body_scroll.ensure_control_visible(button)
	)
	return button

func _bind_extra_touch(button: Button) -> void:
	_touch_buttons.append(button)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.index > 0:
			if event.pressed and not event.canceled and not button.disabled and not _dismiss_pending:
				if not button.has_meta("touch_owner"):
					button.set_meta("touch_owner", event.index)
					button.set_meta("touch_start", button.get_global_transform_with_canvas() * event.position)
					button.set_meta("touch_dragged", false)
			elif button.get_meta("touch_owner", -1) == event.index:
				var dragged := bool(button.get_meta("touch_dragged", false))
				_clear_touch_owner(button)
				if not dragged and not event.canceled and not button.disabled and not _dismiss_pending and Rect2(Vector2.ZERO, button.size).has_point(event.position):
					button.pressed.emit()
			button.accept_event()
	)

func _clear_touch_owner(button: Button) -> void:
	for key in ["touch_owner", "touch_start", "touch_dragged"]:
		if button.has_meta(key): button.remove_meta(key)

func _release_touch_owners() -> void:
	for button in _touch_buttons:
		if is_instance_valid(button): _clear_touch_owner(button)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_release_touch_owners()

func _set_active(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override("normal", Ornate.make_button_style(active))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _dismiss_pending: return
	if event is InputEventScreenDrag and event.index > 0:
		for button in _touch_buttons:
			if is_instance_valid(button) and button.get_meta("touch_owner", -1) == event.index:
				if Vector2(button.get_meta("touch_start", event.position)).distance_to(event.position) > 12:
					button.set_meta("touch_dragged", true)
	if event is InputEventScreenTouch and event.index > 0 and not event.pressed:
		for button in _touch_buttons.duplicate():
			if is_instance_valid(button) and button.get_meta("touch_owner", -1) == event.index:
				var dragged := bool(button.get_meta("touch_dragged", false))
				_clear_touch_owner(button)
				var point: Vector2 = button.get_global_transform_with_canvas().affine_inverse() * event.position
				if not dragged and not event.canceled and not button.disabled and button.is_visible_in_tree() and Rect2(Vector2.ZERO, button.size).has_point(point):
					button.pressed.emit()
				get_viewport().set_input_as_handled()
				return
	if page == "menu" and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		if not dropdown.get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
			_dismiss()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if is_instance_valid(item_popup): _close_item_popup()
			else: _dismiss()
			return
		if event.keycode == KEY_TAB:
			_keyboard_navigation = true
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		_keyboard_navigation = false

func _dismiss() -> void:
	if _dismiss_pending: return
	_dismiss_pending = true
	_reset_stat_draft()
	_release_touch_owners()
	dismissed.emit()
