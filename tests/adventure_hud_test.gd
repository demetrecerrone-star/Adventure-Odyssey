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
	check(hud.portrait.clip_contents, "actual portrait clips to its small head frame")
	check(hud.portrait_avatar.get_script().resource_path == "res://src/layered_avatar.gd", "portrait uses original layered game character")
	check(hud.portrait_avatar.artwork_ready and hud.portrait_avatar.visible, "saved Ranger portrait artwork is available")
	check(hud.portrait_avatar.appearance == draft.payload(), "portrait receives complete saved appearance")
	check(hud.username_label.text == draft.username and hud.class_label.text == "Ranger", "identity uses actual saved name and class")
	check(hud.progression_label.text == "Level / XP unavailable", "progression has no invented values")
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
		for left in [false, true]:
			hud.set_left_handed(left)
			await settle()
			var context := "%s left=%s" % [resolution, left]
			check(hud.identity_panel.get_rect() == original_identity and hud.map_panel.get_rect() == original_map and hud.message.get_rect() == original_message, context + " handedness changes actions only")
			var pad_x := float(resolution.x - 18 - 176) if left else 18.0
			var thumb := Rect2(pad_x, resolution.y - 16 - 176, 176, 176)
			for panel in [hud.identity_panel, hud.map_panel, hud.quest_panel, hud.vitals_panel, hud.action_cluster, hud.message]:
				check(contains(viewport_rect, panel), context + " panel fits screen " + panel.name)
			for button in all_buttons(hud):
				check(button.mouse_filter == Control.MOUSE_FILTER_STOP, context + " button stops pointer " + button.name)
				check(button.size.x >= 44 and button.size.y >= 44, context + " minimum touch target " + button.name)
				check(contains(viewport_rect, button), context + " button fits screen " + button.name)
				check(not button.get_global_rect().intersects(thumb), context + " button clears thumb zone " + button.name)
			for first in all_buttons(hud):
				for second in all_buttons(hud):
					if first.get_instance_id() < second.get_instance_id():
						check(not first.get_global_rect().intersects(second.get_global_rect()), context + " distinct buttons do not overlap " + first.name + "/" + second.name)
			check(not hud.message.get_global_rect().intersects(thumb), context + " message clears thumb zone")
			check(not hud.message.get_global_rect().intersects(hud.action_cluster.get_global_rect()), context + " message clears action cluster")
			check(not hud.vitals_panel.get_global_rect().intersects(hud.action_cluster.get_global_rect()), context + " vitals clear action cluster")
	var safe := Rect2(32, 10, 780, 366)
	hud.set_safe_rect(safe)
	await settle()
	for panel in [hud.identity_panel, hud.map_panel, hud.quest_panel, hud.vitals_panel, hud.action_cluster, hud.message]:
		check(contains(safe, panel), "safe area contains " + panel.name)
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
