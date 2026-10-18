extends SceneTree
const Menu = preload("res://src/ui/adventure_menu.gd")
const Save = preload("res://src/bedroom_save.gd")
const Preferences = preload("res://src/control_preferences.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
var paths: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for _i in range(6): await process_frame
func labels(node: Node) -> String:
	var result := ""
	for child in node.get_children():
		if child is Label: result += child.text + "\n"
		result += labels(child)
	return result
func make_state():
	var state = Save.new()
	state.path = "user://stat_panel_%s.json" % Time.get_ticks_usec()
	paths.append(state.path)
	var draft = Draft.new()
	draft.username = "StatsTester"
	draft.set_base("female")
	check(state.create(draft.payload()), "Create valid isolated stat fixture")
	return state
func make_menu(state, left: bool = false):
	var menu = Menu.new()
	menu.state = state
	menu.preferences = Preferences.new()
	menu.preferences.left_handed = left
	menu.initial_page = "stats"
	root.add_child(menu)
	return menu
func add_point(menu, key: String) -> void:
	menu.stat_rows[key].plus.pressed.emit()
func preview(menu) -> void:
	menu.stat_primary.pressed.emit()
func confirm(menu) -> void:
	menu.stat_primary.pressed.emit()

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(844, 390)
	var state = make_state()
	var before_disk := FileAccess.get_file_as_string(state.path)
	var before_state := JSON.stringify(state.snapshot())
	var menu = make_menu(state)
	await settle()
	check(menu.subtitle_label.text.contains("No points available"), "Level one explains zero available points without blocking navigation")
	check(menu.stat_primary.disabled and menu.stat_cancel.disabled, "Zero-point actions are disabled")
	for attribute in Menu.CORE_ATTRIBUTES:
		var key: String = attribute[0]
		check(menu.stat_rows.has(key) and menu.stat_rows[key].value.text == "10", "Actual configured baseline shown for " + key)
		if key == "LUK":
			check(not menu.stat_rows.LUK.has("minus") and not menu.stat_rows.LUK.has("plus"), "Luck has no point allocation controls")
			check(menu.stat_rows.LUK.xp_label.text == "0 / 100 XP" and menu.stat_rows.LUK.xp_bar.value == 0 and menu.stat_rows.LUK.xp_bar.max_value == 100, "Luck displays actual initial zero of 100 XP")
			menu._change_stat("LUK", 1)
		else:
			check(menu.stat_rows[key].minus.disabled and menu.stat_rows[key].plus.disabled, "No free points or baseline refunds for " + key)
			add_point(menu, key)
	preview(menu)
	confirm(menu)
	check(before_disk == FileAccess.get_file_as_string(state.path) and before_state == JSON.stringify(state.snapshot()), "Opening stats and disabled-event injection never change save")
	check(labels(menu.body).contains("HP/MP caps and mana recovery are active") and labels(menu.body).contains("remain previews"), "Planned effects cannot be mistaken for implemented combat")
	check(labels(menu.body).contains("Physical power: 20") and labels(menu.body).contains("Maximum HP: 100") and labels(menu.body).contains("Accuracy: 90.00%"), "Planned numbers are computed from configured values")
	check(labels(menu.body).contains("XP earning is not available yet"), "Luck XP source is clearly marked unavailable")
	menu.show_page("character")
	check(menu.page == "character", "Zero-point stats never block another page")
	menu.free()
	await settle()
	check(state.advance_character_level(2, state.get_stat_summary().revision).ok, "Fixture alone seeds an earned level")
	before_disk = FileAccess.get_file_as_string(state.path)
	before_state = JSON.stringify(state.snapshot())
	for dimensions in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		for left in [false, true]:
			menu = make_menu(state, left)
			await settle()
			check(menu.body_scroll.get_h_scroll_bar().max_value <= menu.body_scroll.size.x + 1, "Stats have no horizontal clipping at %s left=%s" % [dimensions, left])
			for attribute in Menu.CORE_ATTRIBUTES:
				var key: String = attribute[0]
				var row = menu.find_child("Stat_" + key, true, false)
				check(menu.body_scroll.get_global_rect().grow(1).encloses(row.get_global_rect()), "All six stats fit first view at %s left=%s: %s" % [dimensions, left, key])
				if key == "LUK":
					check(row.get_global_rect().encloses(menu.stat_rows.LUK.xp_bar.get_global_rect()) and menu.stat_rows.LUK.xp_bar.size.x >= 90, "Luck XP bar fits beside its name and value")
					check(menu.stat_rows.LUK.value.get_global_rect().end.x < menu.stat_rows.LUK.xp_bar.get_global_rect().position.x, "Luck value sits beside its name, before XP bar")
					check(menu.find_child("StatMinus_LUK", true, false) == null and menu.find_child("StatPlus_LUK", true, false) == null, "Luck stepper nodes are absent")
					continue
				for button in [menu.stat_rows[key].minus, menu.stat_rows[key].plus]:
					check(button.size.x >= 44 and button.size.y >= 44, "44px stepper target for " + key)
					check(row.get_global_rect().encloses(button.get_global_rect()), "Stepper stays inside stat card for " + key)
			for button in [menu.stat_primary, menu.stat_cancel]:
				check(button.size.x >= 44 and button.size.y >= 44 and menu.panel.get_global_rect().encloses(button.get_global_rect()), "Fixed actions remain touch-sized and on screen")
			check((menu.stat_primary.position.x < menu.stat_cancel.position.x) == left, "Primary action follows action-hand preference")
			menu._change_stat("LUK", 1)
			check(menu._stat_total() == 0 and state.get_stat_summary().attributes.LUK == 10, "Luck cannot consume available free points even through an injected change")
			add_point(menu, "STR")
			check(menu._stat_total() == 1 and menu.stat_rows.STR.value.text.contains("+1"), "Draft stepper shows the pending increment")
			check(menu.stat_effect_labels.physical_power.text.contains("20 → 22"), "Provisional effect updates from authoritative preview")
			check(before_disk == FileAccess.get_file_as_string(state.path) and before_state == JSON.stringify(state.snapshot()), "A draft never mutates disk or authority")
			menu.body_scroll.scroll_vertical = 110
			await settle()
			var previous_scroll: int = menu.body_scroll.scroll_vertical
			var action_rect: Rect2 = menu.stat_footer.get_global_rect()
			add_point(menu, "WIS")
			await settle()
			check(menu.body_scroll.scroll_vertical == previous_scroll and menu.stat_footer.get_global_rect() == action_rect, "Stepper changes preserve scroll and fixed action position")
			menu.stat_rows.WIS.minus.pressed.emit()
			check(not menu._stat_deltas.has("WIS"), "Minus removes only draft allocations")
			menu.stat_cancel.pressed.emit()
			await settle()
			check(menu._stat_total() == 0 and menu.stat_rows.STR.value.text == "10", "Cancel discards draft and shows unchanged saved stats")
			check(menu.body_scroll.scroll_vertical == previous_scroll, "Cancel preserves scroll position")
			menu.free()
			await settle()
	root.size = Vector2i(844, 390)
	menu = make_menu(state)
	await settle()
	for _i in range(7): add_point(menu, "STR")
	check(menu._stat_total() == 5 and menu.stat_rows.STR.plus.disabled, "Draft cannot overspend even with repeated disabled signals")
	menu.stat_rows.STR.minus.pressed.emit()
	check(menu._stat_total() == 4 and not menu.stat_rows.AGI.plus.disabled, "Returning one draft point makes it available elsewhere")
	menu.stat_cancel.pressed.emit()
	add_point(menu, "STR")
	add_point(menu, "STR")
	add_point(menu, "WIS")
	preview(menu)
	await settle()
	check(menu._stat_reviewing and menu.stat_primary.name == "StatConfirm", "Spending requires explicit review state")
	check(labels(menu.body).contains("STR  10 → 12 (+2)") and labels(menu.body).contains("WIS  10 → 11 (+1)"), "Review lists exact saved-to-proposed changes")
	check(labels(menu.body).contains("3 points · 2 will remain"), "Review shows exact total and remaining balance")
	check(before_disk == FileAccess.get_file_as_string(state.path), "Preview is read-only")
	menu.stat_edit.pressed.emit()
	check(not menu._stat_reviewing and menu._stat_total() == 3, "Edit returns to the preserved draft")
	preview(menu)
	var old_confirm: Button = menu.stat_primary
	old_confirm.pressed.emit()
	old_confirm.pressed.emit()
	await settle()
	check(state.get_stat_summary().attributes.STR == 12 and state.get_stat_summary().attributes.WIS == 11 and state.get_stat_summary().attributes.LUK == 10 and state.get_stat_summary().unspent_points == 2, "Confirm commits exactly once despite a double tap")
	check(menu._stat_total() == 0 and not menu._stat_reviewing and menu.notice.text.contains("Points saved"), "Success clears draft and acknowledges persistence")
	for attribute in Menu.CORE_ATTRIBUTES:
		var row = menu.find_child("Stat_" + attribute[0], true, false)
		check(menu.body_scroll.get_global_rect().grow(1).encloses(row.get_global_rect()), "Saved result keeps all six stats in first phone view: " + attribute[0])
	var restored = Save.new()
	restored.path = state.path
	check(restored.load_saved() and restored.get_stat_summary().attributes == state.get_stat_summary().attributes, "Confirmed stats persist across reload")
	menu.character_tab = "details"
	menu.show_page("character")
	check(labels(menu.body).contains("STR 12") and labels(menu.body).contains("WIS 11") and labels(menu.body).contains("LUK 10"), "Character details reflect confirmed values")
	menu.show_page("stats")
	add_point(menu, "AGI")
	preview(menu)
	check(state.allocate_stat_points({"INT":1}, state.get_stat_summary().revision).ok, "Simulate a concurrent authoritative stat change")
	confirm(menu)
	await settle()
	check(state.get_stat_summary().attributes.AGI == 10 and state.get_stat_summary().attributes.INT == 11, "Stale confirmation cannot spend points")
	check(menu._stat_total() == 0 and menu.stat_rows.INT.value.text == "11" and menu.notice.text.contains("changed"), "Stale result reloads current authority and requires a fresh draft")
	add_point(menu, "AGI")
	check(menu.notice.text.is_empty(), "Accepted edit clears obsolete error or success status")
	preview(menu)
	before_disk = FileAccess.get_file_as_string(state.path)
	before_state = JSON.stringify(state.snapshot())
	var valid_path: String = state.path
	state.path = "user://missing_stat_panel_%s/save.json" % Time.get_ticks_usec()
	confirm(menu)
	await settle()
	check(before_state == JSON.stringify(state.snapshot()) and before_disk == FileAccess.get_file_as_string(valid_path), "Failed save rolls back all state and leaves disk unchanged")
	check(menu.stat_rows.AGI.value.text == "10" and menu._stat_total() == 0 and not menu._stat_reviewing and not menu.notice.text.is_empty(), "Failed save shows authoritative values, an error and no armed confirmation")
	state.path = valid_path
	add_point(menu, "VIT")
	check(menu.notice.text.is_empty(), "A fresh valid draft clears the previous save error")
	menu.show_page("inventory")
	menu.show_page("stats")
	check(menu._stat_total() == 0 and state.get_stat_summary().attributes.VIT == 10, "Page navigation discards unconfirmed allocations")
	add_point(menu, "INT")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	check(menu._dismiss_pending and menu._stat_total() == 0 and state.get_stat_summary().attributes.INT == 11, "Back/Escape discards draft without spending")
	menu.free()
	await settle()
	menu = make_menu(state)
	await settle()
	add_point(menu, "VIT")
	preview(menu)
	menu.close_button.pressed.emit()
	menu._confirm_stat_draft()
	check(menu._stat_total() == 0 and state.get_stat_summary().attributes.VIT == 10, "Close from review disarms even a late confirmation event")
	menu.free()
	await settle()
	# XP is seeded only through isolated fixture events, never a runtime control.
	var luck_state = make_state()
	check(luck_state.record_luck_event("stat.panel.discovery.1", "stat.panel.source.1", "first_discovery", "", luck_state.get_stat_summary().revision).ok, "Fixture records one genuine-source-shaped Luck discovery")
	var luck_before := JSON.stringify(luck_state.snapshot())
	for dimensions in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = dimensions
		for left in [false, true]:
			menu = make_menu(luck_state, left)
			await settle()
			check(menu.stat_rows.LUK.value.text == "10" and menu.stat_rows.LUK.xp_label.text == "25 / 100 XP", "Luck shows authoritative partial progress at %s left=%s" % [dimensions, left])
			check(is_equal_approx(menu.stat_rows.LUK.xp_bar.value / menu.stat_rows.LUK.xp_bar.max_value, 0.25), "Luck bar uses actual XP fraction")
			var row = menu.find_child("Stat_LUK", true, false)
			check(menu.body_scroll.get_global_rect().grow(1).encloses(row.get_global_rect()) and row.get_global_rect().encloses(menu.stat_rows.LUK.xp_bar.get_global_rect()), "Seeded Luck remains fully visible at %s left=%s" % [dimensions, left])
			check(luck_before == JSON.stringify(luck_state.snapshot()), "Reading Luck progress never awards XP")
			menu.free()
			await settle()
	for index in range(2, 5):
		check(luck_state.record_luck_event("stat.panel.discovery.%d" % index, "stat.panel.source.%d" % index, "first_discovery", "", luck_state.get_stat_summary().revision).ok, "Fixture advances Luck from earned XP")
	root.size = Vector2i(844, 390)
	for left in [false, true]:
		menu = make_menu(luck_state, left)
		await settle()
		check(menu.stat_rows.LUK.value.text == "11" and menu.stat_rows.LUK.xp_label.text == "0 / 125 XP", "XP threshold updates Luck value and next requirement")
		check(menu.stat_rows.LUK.xp_bar.value == 0 and menu.stat_rows.LUK.xp_bar.max_value == 125, "Next-rank bar resets to actual progress")
		menu.character_tab = "details"
		menu.show_page("character")
		check(labels(menu.body).contains("LUK 11"), "Character details display actual XP-earned Luck")
		menu.free()
		await settle()
	for path in paths: DirAccess.remove_absolute(path)
	print("STAT PANEL TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
