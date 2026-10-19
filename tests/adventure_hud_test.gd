extends SceneTree
const HUD = preload("res://src/ui/adventure_hud.gd")
const Ornate = preload("res://src/ui/ornate_panel.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
var menu_requests := 0
var interactions := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func settle() -> void:
	await process_frame
	await process_frame
func contains(outer: Rect2, control: Control) -> bool:
	return outer.grow(0.1).encloses(control.get_global_rect())
func all_buttons(hud) -> Array[Button]:
	var result: Array[Button] = [hud.menu_button, hud.interact_button, hud.attack_button, hud.potion_button]
	result.append_array(hud.skill_buttons)
	return result
func thumb_zone(safe: Rect2, left: bool, mode: String) -> Rect2:
	var extent := Vector2(244, clampf(safe.size.y - 190, 176, 200)) if mode == "floating" else Vector2(164, 164)
	var x := safe.end.x - extent.x - 18 if left else safe.position.x + 18
	return Rect2(Vector2(x, maxf(safe.position.y + 100, safe.end.y - extent.y - 16)), extent)
func check_layout(hud, safe: Rect2, left: bool, mode: String, context: String) -> void:
	var thumb := thumb_zone(safe, left, mode)
	check(hud.quest_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and hud.quest_label.max_lines_visible == 2, context + " objective has two readable lines")
	check(hud.quest_panel.size.y >= 52 and hud.quest_label.size.x >= 198, context + " objective has expanded reading area")
	for panel in [hud.identity_panel, hud.map_panel, hud.quest_panel, hud.vitals_panel, hud.action_cluster, hud.interaction_panel, hud.message]:
		check(contains(safe, panel), context + " panel fits safe area " + panel.name)
	for button in all_buttons(hud):
		check(button.mouse_filter == Control.MOUSE_FILTER_STOP, context + " button stops pointer " + button.name)
		check(button.size.x >= 44 and button.size.y >= 44, context + " minimum touch target " + button.name)
		check(contains(safe, button), context + " button fits safe area " + button.name)
		check(not button.get_global_rect().intersects(thumb), context + " button clears thumb zone " + button.name)
		for header in [hud.identity_panel, hud.map_panel, hud.quest_panel]:
			check(not button.get_global_rect().intersects(header.get_global_rect()), context + " button clears header " + button.name + "/" + header.name)
	for first in all_buttons(hud):
		for second in all_buttons(hud):
			if first.get_instance_id() < second.get_instance_id():
				check(not first.get_global_rect().intersects(second.get_global_rect()), context + " distinct buttons do not overlap " + first.name + "/" + second.name)
	check(hud.attack_button.size == Vector2(112, 112), context + " attack target is enlarged to 112 px")
	for skill in hud.skill_buttons:
		check(skill.size == Vector2(76, 76), context + " skill target is enlarged to 76 px " + skill.name)
	check(not hud.message.get_global_rect().intersects(thumb), context + " message clears thumb zone")
	for center_control in [hud.message, hud.vitals_panel, hud.interaction_panel]:
		check(not center_control.get_global_rect().intersects(hud.action_cluster.get_global_rect()), context + " center control clears combat cluster " + center_control.name)
	check(not hud.interaction_panel.get_global_rect().intersects(hud.vitals_panel.get_global_rect()), context + " interaction clears vitals")
	check(not hud.interaction_panel.get_global_rect().intersects(hud.message.get_global_rect()), context + " interaction clears message")
	check(hud.interaction_panel.get_global_rect().end.y + 8 <= hud.vitals_panel.get_global_rect().position.y, context + " interaction has a separate lane above vitals")
func secondary_touch(hud, button: Button, down: bool, point: Vector2, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 3
	event.pressed = down
	event.position = point
	event.canceled = canceled
	if down:
		button.gui_input.emit(event)
	else:
		event.position = button.get_global_transform_with_canvas() * point
		hud._input(event)
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var draft = Draft.new()
	draft.username = "LongAdventureHero123"
	draft.set_base("female")
	draft.character_class = "Ranger"
	draft.hair_color = "Silver"
	draft.eyes = "Violet"
	draft.skin = "deep"
	var hud = HUD.new()
	hud.set_character(draft.payload())
	hud.set_world_position("guild_interior", Vector2(716.4, 1321.7))
	root.add_child(hud)
	check(hud.interact_button != null and hud.message != null and hud.status != null, "compatibility controls exist synchronously after add_child")
	hud.menu_requested.connect(func(): menu_requests += 1)
	hud.interact_button.pressed.connect(func(): interactions += 1)
	await settle()
	check(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "full-screen root does not block world input")
	check(hud.action_cluster.mouse_filter == Control.MOUSE_FILTER_IGNORE, "empty areas between action buttons pass world input")
	check(hud.interaction_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "interaction wrapper passes through empty space")
	check(hud.interact_button.get_parent() == hud.interaction_panel and not hud.action_cluster.is_ancestor_of(hud.interact_button), "contextual interaction is separate from the combat cluster")
	check(hud.portrait.clip_contents, "actual portrait clips to its small head frame")
	check(hud.portrait_avatar.get_script().resource_path == "res://src/layered_avatar.gd", "portrait uses original layered game character")
	check(hud.portrait_avatar.artwork_ready and hud.portrait_avatar.visible, "saved Ranger portrait artwork is available")
	check(hud.portrait_avatar.appearance == draft.payload(), "portrait receives complete saved appearance")
	check(hud.username_label.text == draft.username and hud.class_label.text == "Ranger", "identity uses actual saved name and class")
	check(hud.progression_label.text == "Level / XP unavailable", "unconfigured HUD has no invented level")
	hud.set_progression({"ok":true,"level":3})
	check(hud.progression_label.text == "Level 3 · XP unavailable", "validated level renders without inventing XP")
	hud.set_progression({"ok":false})
	check(hud.progression_label.text == "Level / XP unavailable", "failed summary clears level")
	check(hud.location_label.text == "Adventurer Guild" and hud.coordinates_label.text == "X 716  ·  Y 1322", "pre-ready location uses real rounded coordinates")
	check(hud.attack_button.disabled and hud.potion_button.disabled, "combat and potion controls unavailable")
	check(hud.attack_button.text.strip_edges() == "Attack" and hud.attack_button.emblem == "attack", "attack has a distinct caption for its custom face")
	for index in hud.skill_buttons.size():
		check(hud.skill_buttons[index].text == ["I", "II", "III"][index] and hud.skill_buttons[index].emblem == "skill", "custom skill face has an identifiable Roman caption")
	for skill in hud.skill_buttons:
		check(skill.disabled, "skill unavailable " + skill.name)
	check(hud.hp_label.text == "HP unavailable" and hud.mp_label.text == "MP unavailable", "vitals contain no invented stats or bars")
	hud.set_world_position("starter_region", Vector2(2010.2, 1100.3))
	check(hud.location_label.text == "Starter region" and hud.coordinates_label.text == "X 2010  ·  Y 1100", "location update reports actual scene and coordinates")
	var cached: Vector2i = hud._rendered_coordinates
	hud.set_world_position("starter_region", Vector2(2010.4, 1100.4))
	check(hud._rendered_coordinates == cached, "subpixel movement does not rebuild coordinate text")
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(844, 390)]:
		root.size = resolution
		await settle()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(resolution))
		var original_identity: Rect2 = hud.identity_panel.get_rect()
		var original_map: Rect2 = hud.map_panel.get_rect()
		var original_message: Rect2 = hud.message.get_rect()
		var original_interaction: Rect2 = hud.interaction_panel.get_rect()
		for left in [false, true]:
			hud.set_left_handed(left)
			await settle()
			var context := "%s left=%s" % [resolution, left]
			check(hud.identity_panel.get_rect() == original_identity and hud.map_panel.get_rect() == original_map and hud.message.get_rect() == original_message, context + " handedness changes actions only")
			check(hud.interaction_panel.get_rect() == original_interaction, context + " contextual interaction stays centered when combat swaps sides")
			for mode in ["fixed", "floating"]:
				check_layout(hud, viewport_rect, left, mode, context + " " + mode)
	var safe := Rect2(32, 10, 780, 366)
	hud.set_safe_rect(safe)
	await settle()
	for left in [false, true]:
		hud.set_left_handed(left)
		await settle()
		for mode in ["fixed", "floating"]:
			check_layout(hud, safe, left, mode, "inset safe area left=%s %s" % [left, mode])
	var interaction_rect: Rect2 = hud.interact_button.get_global_rect()
	hud.interact_button.text = "Enter the Adventurer Guild [E]"
	await settle()
	check(hud.interact_button.get_global_rect() == interaction_rect, "long contextual caption does not enlarge the target into other controls")
	hud.interact_button.text = "Use [E]"
	hud.set_safe_rect(Rect2())
	hud.interact_button.disabled = false
	secondary_touch(hud, hud.menu_button, true, Vector2(20, 20))
	secondary_touch(hud, hud.menu_button, false, Vector2(20, 20))
	check(menu_requests == 1, "secondary touch opens menu exactly once")
	secondary_touch(hud, hud.interact_button, true, Vector2(20, 20))
	secondary_touch(hud, hud.interact_button, false, Vector2(20, 20))
	check(interactions == 1, "secondary touch activates separate interaction")
	secondary_touch(hud, hud.interact_button, true, Vector2(20, 20))
	secondary_touch(hud, hud.interact_button, false, Vector2(-40, -40))
	check(interactions == 1 and not hud.interact_button.has_meta("touch_owner"), "release outside clears touch owner without action")
	secondary_touch(hud, hud.interact_button, true, Vector2(20, 20))
	secondary_touch(hud, hud.interact_button, false, Vector2(20, 20), true)
	check(interactions == 1, "canceled secondary touch does not activate")
	secondary_touch(hud, hud.menu_button, true, Vector2(20, 20))
	hud.set_modal_active(true)
	secondary_touch(hud, hud.menu_button, false, Vector2(20, 20))
	check(menu_requests == 1 and hud.menu_button.disabled and hud.interact_button.disabled, "modal blocks and clears held controls")
	hud.set_modal_active(false)
	check(not hud.menu_button.disabled and not hud.interact_button.disabled, "modal close restores prior interaction availability")
	hud.interact_button.disabled = true
	hud.set_modal_active(true)
	hud.set_modal_active(false)
	check(hud.interact_button.disabled, "modal close never enables an unavailable interaction")
	secondary_touch(hud, hud.menu_button, true, Vector2(20, 20))
	hud._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not hud.menu_button.has_meta("touch_owner"), "focus loss clears secondary touch ownership")
	draft.hair_color = "Auburn"
	draft.eyes = "Blue"
	hud.configure(draft.payload())
	check(hud.portrait_avatar.appearance.hair_color == "Auburn" and hud.portrait_avatar.appearance.eyes == "Blue", "mirror update refreshes actual saved portrait")
	hud.set_character({})
	check(not hud.portrait_avatar.visible, "missing character never displays invented appearance")
	check(Ornate.make_button_style().border_width_left >= 2 and Ornate.make_button_style(false, true).bg_color != Ornate.make_button_style().bg_color, "shared ornament button theme has a visible disabled state")
	hud.free()
	await process_frame
	print("ADVENTURE HUD CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
