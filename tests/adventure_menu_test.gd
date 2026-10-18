extends SceneTree
const Menu = preload("res://src/ui/adventure_menu.gd")
const Save = preload("res://src/bedroom_save.gd")
const Preferences = preload("res://src/control_preferences.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
var equip_requests: Array[String] = []
var unequip_requests := 0
var control_requests: Array = []
var title_requests := 0
var dismissals := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for _i in range(6): await process_frame

func all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button: result.append(child)
		result.append_array(all_buttons(child))
	return result

func labels(node: Node) -> String:
	var result := ""
	for child in node.get_children():
		if child is Label: result += child.text + "\n"
		result += labels(child)
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	var state = Save.new()
	state.path = "user://menu_test_save_%s.json" % Time.get_ticks_usec()
	var draft = Draft.new()
	draft.username = "MenuTester"
	draft.set_base("female")
	check(state.create(draft.payload()), "Create a valid persistent menu fixture")
	for _i in range(3): check(state.transfer("healing_potion", false), "Seed potion through save authority")
	check(state.transfer("warrior_01_weapon", false), "Seed starter weapon through save authority")
	check(state.receive_item("mage_01_weapon", 1, "world_drop", "menu.fixture.mage"), "Seed wrong-class fixture weapon")
	var before := JSON.stringify({"character":state.character, "bag":state.bag, "chest":state.chest, "armor":state.equipped_armor, "weapon":state.equipped_weapon})
	var preferences = Preferences.new()
	preferences.path = "user://menu_test_controls_%s.json" % Time.get_ticks_usec()
	var menu = Menu.new()
	menu.state = state
	menu.preferences = preferences
	menu.equip_requested.connect(func(item: String): equip_requests.append(item))
	menu.unequip_requested.connect(func(): unequip_requests += 1)
	menu.settings_changed.connect(func(mode: String, handed: bool): control_requests.append([mode, handed]))
	menu.title_requested.connect(func(): title_requests += 1)
	menu.dismissed.connect(func(): dismissals += 1)
	root.add_child(menu)
	await settle()
	check(menu.avatar != null and menu.avatar.artwork_ready, "Character uses the approved layered avatar artwork")
	check(menu.avatar.character_class == "Warrior" and menu.avatar.appearance == state.character, "Avatar is configured from the saved class/base/appearance")
	for dimensions in [Vector2(1280, 720), Vector2(960, 540), Vector2(844, 390)]:
		menu.size = dimensions
		for page in ["character", "inventory", "stats", "quest_log", "settings"]:
			menu.show_page(page)
			await settle()
			var viewport_rect := Rect2(Vector2.ZERO, dimensions)
			check(viewport_rect.encloses(menu.panel.get_global_rect()), "%s %s: page panel fits" % [dimensions, page])
			check(viewport_rect.encloses(menu.sidebar.get_global_rect()), "%s %s: sidebar fits" % [dimensions, page])
			check(menu.panel.get_global_rect().encloses(menu.close_button.get_global_rect()), "%s %s: Close remains on screen" % [dimensions, page])
			check(menu.panel.get_global_rect().encloses(menu.body_scroll.get_global_rect()), "%s %s: body scroll remains on screen" % [dimensions, page])
			check(menu.body_scroll.get_h_scroll_bar().max_value <= menu.body_scroll.size.x + 1, "%s %s: no hidden horizontal content" % [dimensions, page])
			for button in all_buttons(menu):
				if not button.is_visible_in_tree(): continue
				check(button.size.x >= 44 and button.size.y >= 44, "%s %s: 44px touch target %s" % [dimensions, page, button.name])
			for button in menu.page_buttons.values():
				check(menu.sidebar.get_global_rect().encloses(button.get_global_rect()), "%s: sidebar button accessible" % dimensions)
			if page == "stats":
				for attribute in Menu.CORE_ATTRIBUTES:
					var row = menu.body.find_child("Stat_" + attribute[0], true, false)
					check(row != null and menu.body_scroll.get_global_rect().grow(1).encloses(row.get_global_rect()), "%s: core stat visible without scrolling %s" % [dimensions, attribute[0]])
			var close_before: Rect2 = menu.close_button.get_global_rect()
			var side_before: Rect2 = menu.sidebar.get_global_rect()
			menu.body_scroll.scroll_vertical = 10000
			await settle()
			check(close_before == menu.close_button.get_global_rect() and side_before == menu.sidebar.get_global_rect(), "Scrolling body never moves Close or navigation")
			if page == "character":
				var avatar_rect := Rect2(menu.avatar.position + Vector2(-128, -232) * menu.avatar.scale, Vector2(256, 256) * menu.avatar.scale)
				check(Rect2(Vector2.ZERO, menu.portrait_stage.size).encloses(avatar_rect), "Full sprite frame stays inside portrait")
				check(absf(menu.portrait_stage.get_global_rect().get_center().x - menu.body.get_global_rect().get_center().x) < 2, "Character stands centered with equipment on both sides")
	menu.selected_item = "warrior_01_weapon"
	menu.show_page("inventory")
	await settle()
	menu.find_child("Inspect_warrior_01_weapon",true,false).pressed.emit()
	await settle()
	check(labels(menu.item_popup).contains("Basic strike: 12 damage"), "Comparison reflects implemented damage")
	var equip: Button = menu.find_child("Equip_warrior_01_weapon", true, false)
	check(not equip.disabled, "Owned matching-class item can request equip")
	equip.pressed.emit()
	check(equip_requests == ["warrior_01_weapon"] and state.equipped_weapon.is_empty() and state.bag.warrior_01_weapon == 1, "Equip emits request without changing inventory authority")
	var inspect: Button = menu.find_child("Inspect_mage_01_weapon", true, false)
	inspect.pressed.emit()
	await settle()
	check(menu.selected_item == "mage_01_weapon" and equip_requests.size() == 1, "Inspection never equips")
	var wrong_class: Button = menu.find_child("Equip_mage_01_weapon", true, false)
	check(wrong_class.disabled, "Inspected wrong-class item cannot equip")
	check(labels(menu.item_popup).contains("Your class cannot equip this weapon"), "Inspection explains wrong-class restriction")
	check(before == JSON.stringify({"character":state.character, "bag":state.bag, "chest":state.chest, "armor":state.equipped_armor, "weapon":state.equipped_weapon}), "Opening all pages and inspection never mutate guest save")
	# Simulate the owner succeeding, then refresh from the authoritative object.
	check(state.equip("warrior_01_weapon"), "Fixture owner equips using authoritative save")
	menu.refresh_state()
	await settle()
	menu.find_child("EquipmentSlot_equipped_weapon",true,false).pressed.emit()
	await settle()
	var unequip: Button = menu.find_child("UnequipWeapon", true, false)
	check(unequip != null and labels(menu.item_popup).contains("Warrior's basic sword"), "Refresh displays newly equipped weapon")
	unequip.pressed.emit()
	check(unequip_requests == 1 and state.equipped_weapon == "warrior_01_weapon", "Unequip is a request without local mutation")
	menu.show_page("character")
	await settle()
	check(menu.avatar.equipped_weapon == "warrior_01_weapon", "Portrait reflects authoritative held weapon")
	menu.character_tab = "details"
	menu.refresh_state()
	await settle()
	var detail_text := labels(menu.body)
	check(detail_text.contains("MenuTester") and detail_text.contains("Class: Warrior") and detail_text.contains("Body: Female"), "Details show actual immutable identity")
	check(detail_text.contains("STR 10") and detail_text.contains("LUK 10") and detail_text.contains("HP/MP caps and mana recovery are active"), "Character details show configured stats and honest planned-combat boundary")
	menu.show_page("stats")
	await settle()
	var stats_text := labels(menu.body)
	for key in ["STR", "AGI", "VIT", "INT", "WIS", "LUK"]:
		check(stats_text.contains(key), "Planned attribute exists: " + key)
	check(stats_text.count("10") >= 6 and menu.subtitle_label.text.contains("No points available"), "Six configured core stats and actual zero balance are shown")
	check(menu.find_child("StatMinus_LUK", true, false) == null and menu.find_child("StatPlus_LUK", true, false) == null, "Luck has no free-point controls")
	check(menu.stat_rows.LUK.xp_label.text == "0 / 100 XP", "Luck shows actual baseline XP progress")
	check(stats_text.find("Luck") < stats_text.find("STAT EFFECTS"), "Luck belongs to core attributes, before planned effects")
	menu.show_page("quest_log")
	check(labels(menu.body).contains("Read the envelope") and labels(menu.body).contains("Guild assignments reward you once"), "Quest log shows actual tutorial and field assignment")
	menu.show_page("settings")
	await settle()
	menu.floating_button.pressed.emit()
	check(control_requests.back() == ["floating", false], "Floating request preserves handedness")
	check(preferences.mode == "fixed", "Menu never writes settings itself")
	check(preferences.apply("floating", false), "Fixture owner applies floating")
	menu.sync_preferences()
	menu.handed_button.pressed.emit()
	check(control_requests.back() == ["floating", true], "Left-handed request preserves floating mode")
	check(preferences.apply("floating", true), "Fixture owner applies handedness")
	menu.sync_preferences()
	check(menu.handed_button.text == "Left-handed: On", "Preferences synchronize after successful save")
	menu.fixed_button.pressed.emit()
	check(control_requests.back() == ["fixed", true], "Fixed request preserves left-handed preference")
	preferences.path = "user://missing_menu_test_directory/control.json"
	check(not preferences.apply("fixed", false), "Fixture owner reports a failed preference save")
	menu.sync_preferences()
	menu.set_notice(preferences.error, true)
	check(preferences.mode == "floating" and preferences.left_handed and menu.handed_button.text == "Left-handed: On", "Failed save keeps live preferences and toggle unchanged")
	check(menu.notice.text.contains("previous settings are unchanged"), "Parent errors are visible")
	# Buttons must remain usable by finger one while finger zero is still held.
	var request_count := control_requests.size()
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = menu.floating_button.size * 0.5
	menu.floating_button.gui_input.emit(touch)
	check(menu.floating_button.get_meta("touch_owner", -1) == 2, "Secondary pointer owns a menu button")
	touch.index = 3
	menu.floating_button.gui_input.emit(touch)
	check(menu.floating_button.get_meta("touch_owner", -1) == 2, "Another pointer cannot steal the button")
	touch.pressed = false
	touch.position = menu.floating_button.get_global_rect().get_center()
	menu._input(touch)
	check(control_requests.size() == request_count, "Non-owner release cannot activate button")
	touch.index = 2
	menu._input(touch)
	check(control_requests.size() == request_count + 1, "Secondary release activates exactly once")
	touch.position = menu.floating_button.size * 0.5
	menu.floating_button.gui_input.emit(touch)
	check(control_requests.size() == request_count + 1, "Global release and GUI delivery cannot duplicate activation")
	request_count = control_requests.size()
	for release_case in ["outside", "cancel", "drag", "focus", "primary", "disabled"]:
		touch.index = 0 if release_case == "primary" else 2
		touch.pressed = true
		touch.canceled = false
		touch.position = menu.floating_button.size * 0.5
		menu.floating_button.disabled = release_case == "disabled"
		menu.floating_button.gui_input.emit(touch)
		if release_case == "drag":
			var drag := InputEventScreenDrag.new()
			drag.index = 2
			drag.position = menu.floating_button.get_global_rect().get_center() + Vector2(24, 0)
			menu._input(drag)
		if release_case == "focus": menu._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		touch.pressed = false
		touch.canceled = release_case == "cancel"
		touch.position = Vector2.ZERO if release_case == "outside" else menu.floating_button.get_global_rect().get_center()
		menu._input(touch)
		check(control_requests.size() == request_count, "Touch " + release_case + " does not activate a menu button")
		check(not menu.floating_button.has_meta("touch_owner"), "Touch " + release_case + " releases ownership")
		menu.floating_button.disabled = false
	menu.find_child("SaveAndTitle", true, false).pressed.emit()
	check(title_requests == 1, "Save and return to title has an explicit signal")
	menu.show_page("menu")
	await settle()
	check(menu.dropdown.visible and not menu.panel.visible and not menu.sidebar.visible, "Hamburger opens a compact dropdown first")
	check(Rect2(Vector2.ZERO, menu.size).encloses(menu.dropdown.get_global_rect()), "Small-landscape dropdown stays on screen")
	for button in all_buttons(menu.dropdown):
		check(button.size.y >= 44, "Dropdown entries keep touch height")
		check(button.size.x >= (menu.dropdown_scroll.size.x - 8) / 2 - 2, "Dropdown columns use the available panel width")
		check(menu.dropdown_scroll.get_global_rect().encloses(button.get_global_rect()), "Every dropdown destination is visible without scrolling")
	menu.find_child("Dropdown_inventory", true, false).pressed.emit()
	check(menu.page == "inventory" and menu.panel.visible and not menu.dropdown.visible, "Dropdown entry opens own panel")
	menu.show_page("menu")
	var outside := InputEventScreenTouch.new()
	outside.position = Vector2(800, 200)
	outside.pressed = true
	menu._input(outside)
	check(dismissals == 1, "Outside touch dismisses dropdown")
	menu.close_button.pressed.emit()
	check(dismissals == 1, "Repeated close is idempotent")
	menu.queue_free()
	await settle()
	for _i in range(3):
		var reopened = Menu.new()
		reopened.state = state
		reopened.preferences = preferences
		reopened.dismissed.connect(func(): dismissals += 1)
		root.add_child(reopened)
		await settle()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		reopened._input(escape)
		check(reopened._dismiss_pending, "Reopened menu accepts keyboard dismissal")
		reopened.queue_free()
		await settle()
	check(dismissals == 4, "Every freshly opened menu dismisses exactly once")
	for path in DirAccess.get_files_at("user://"):
		if path.begins_with("menu_test_controls_") or path.begins_with("menu_test_save_"): DirAccess.remove_absolute("user://" + path)
	print("ADVENTURE MENU TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
