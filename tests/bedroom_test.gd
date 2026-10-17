extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var avatar = preload("res://src/layered_avatar.gd").new()
	root.add_child(avatar)
	await process_frame
	var fixture := Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	fixture.fill(Color(0.4, 0.4, 0.4, 1))
	avatar.texture_cache["fixture-body"] = ImageTexture.create_from_image(fixture)
	avatar.texture_cache["fixture-armor"] = ImageTexture.create_from_image(fixture)
	avatar.outfit = {"idle":{"body":"fixture-body", "armor":"fixture-armor"}, "walk":{"down":{"body":"fixture-body", "armor":"fixture-armor", "frames":4, "fps":8}, "up":{"body":"fixture-body", "armor":"missing", "frames":4}}}
	check(avatar._valid_pair(avatar.outfit.idle, 4), "Aligned fixture body and armor pair accepted")
	check(not avatar._valid_pair({"body":"fixture-body"}, 4), "Body without armor rejected")
	avatar.artwork_ready = true
	avatar.advance(1, false, 0)
	check(avatar.body.frame == 1 and avatar.armor.frame == 1, "Idle layers use same direction")
	avatar.advance(0, true, 0.30)
	check(avatar.body.frame == 2 and avatar.armor.frame == 2, "Walk layers advance together")
	avatar.advance(3, true, 0.30)
	check(avatar.current_animation == "idle" and avatar.armor.texture != null, "Incomplete walk pair falls back to dressed idle")
	avatar.queue_free()
	await process_frame
	var path := "user://bedroom_test_%s.json" % Time.get_ticks_usec()
	var state = Save.new()
	state.path = path
	var draft = Draft.new()
	draft.username = "BedroomTester"
	draft.set_base("female")
	check(state.create(draft.payload()), "Create local character")
	check(not state.create(draft.payload()), "Cannot replace existing character")
	var edited := draft.payload()
	edited.base = "male"
	edited.username = "Hacked"
	edited["class"] = "Mage"
	edited.eyes = "Green"
	check(state.apply_appearance(edited), "Allowed appearance edits save")
	check(state.character.base == "female" and state.character.username == "BedroomTester" and state.character["class"] == "Warrior", "Mirror cannot change immutable identity")
	check(state.character.eyes == "Green", "Eye selection persisted")
	edited.hair = "male_hair_01"
	check(not state.apply_appearance(edited), "Reject cross-base hair")
	var rng := RandomNumberGenerator.new()
	for _i in range(60):
		var appearance = state.draft_from(state.character)
		appearance.randomize_appearance(rng)
		check(state.apply_appearance(appearance.payload()) and state.character.base == "female" and state.character.hair.begins_with("female_"), "Randomize respects base lock")
	check(state.chest.healing_potion == 5 and state.bag.healing_potion == 0, "New chest contains exactly five healing potions")
	check(state.transfer("healing_potion", false), "Take starter potion")
	check(state.transfer("healing_potion", true), "Deposit item")
	check(not state.transfer("healing_potion", true), "No negative quantities")
	check(not state.transfer("unknown", true), "No unknown items")
	var reload = Save.new()
	reload.path = path
	check(reload.load_saved(), "Reload save")
	check(reload.chest.healing_potion == 5 and reload.bag.healing_potion == 0, "Inventory survives reload")
	check(reload.transfer("healing_potion", false), "Withdraw item")
	check(reload.load_saved() and reload.chest.healing_potion == 4 and reload.bag.healing_potion == 1, "Re-entry does not refill starter potions")
	for _i in range(4):
		check(reload.transfer("healing_potion", false), "Take remaining potion")
	check(not reload.transfer("healing_potion", false), "Empty starter chest cannot duplicate potion")
	check(reload.load_saved() and reload.chest.healing_potion == 0 and reload.bag.healing_potion == 5, "Empty chest persists without reseeding")
	var room = preload("res://src/bedroom.gd").new()
	room.state = reload
	root.add_child(room)
	await process_frame
	check(not room.sleeping and room.actor.visible, "New character immediately appears beside bed")
	for id in room.anchors:
		check(room.can_stand(room.anchors[id]), "Interaction anchor is walkable: " + id)
		check(reachable(room, room.wake_spawn, room.anchors[id]), "Interaction accessible from wake spawn: " + id)
	check(room.prop_nodes.has("bed") and room.prop_nodes.has("chest") and room.prop_nodes.has("mirror"), "Three separate furniture layers")
	check(not room.sleeping and room.state.awake, "Character is ready immediately")
	check(room.can_stand(room.player), "Spawn beside bed in walkable space")
	check(room.actor.scale == Vector2.ONE * 1.05 and room.actor.position == room.player, "Larger avatar preserves foot anchor")
	var pad = room.joystick
	pad.set_position_input(pad.size * 0.5 + Vector2(4, 0))
	check(pad.direction == Vector2.ZERO, "Joystick deadzone prevents drift")
	pad.set_position_input(pad.size * 0.5 + Vector2(35, 0))
	check(pad.direction.x > 0 and pad.direction.x < 1, "Joystick preserves analog strength")
	pad.set_position_input(pad.size * 0.5 + Vector2(300, 300))
	check(is_equal_approx(pad.direction.length(), 1), "Joystick clamps diagonal magnitude")
	pad.reset()
	var finger := InputEventScreenTouch.new()
	finger.index = 3
	finger.pressed = true
	finger.position = pad.size * 0.5 + Vector2(60, 0)
	pad._gui_input(finger)
	check(pad.owner_index == 3 and room.touch_direction.x > 0.9, "First touch owns joystick")
	finger.index = 4
	finger.position = pad.size * 0.5 + Vector2(-60, 0)
	pad._gui_input(finger)
	check(pad.owner_index == 3 and room.touch_direction.x > 0.9, "Second finger cannot steal joystick")
	finger.pressed = false
	pad._input(finger)
	check(pad.owner_index == 3, "Other finger release cannot stop owner")
	finger.index = 3
	pad._input(finger)
	check(pad.owner_index == -1 and room.touch_direction == Vector2.ZERO, "Owner release resets movement")
	finger.pressed = true
	pad._gui_input(finger)
	finger.canceled = true
	pad._input(finger)
	check(pad.owner_index == -1 and pad.direction == Vector2.ZERO, "Touch cancel resets movement")
	pad.set_position_input(pad.size * 0.5 + Vector2(60, 0))
	pad._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(room.touch_direction == Vector2.ZERO, "Focus loss resets joystick")
	check(is_equal_approx(room.movement_speed, 155.0), "Player travel speed is 155 px/s with animation cadence preserved")
	var save_before_movement := FileAccess.get_file_as_string(path)
	room.player = Vector2(800, 650)
	room.touch_direction = Vector2.RIGHT
	room.actor.advance(2, false, 0)
	room._process(0.05)
	check(is_equal_approx(room.player.x, 807.75), "Full stick moves at 155 logical pixels per second")
	check(is_equal_approx(room.actor.elapsed, 0.05), "Full speed gait follows the approved prior cadence despite faster travel")
	check(room.actor.body.frame == 0 and room.actor.armor.frame == 0, "Paired Warrior gait retains approved 9 fps")
	room.actor.advance(2, false, 0)
	room.player = Vector2(800, 650)
	room.touch_direction = Vector2(0.5, 0)
	room._process(0.05)
	check(is_equal_approx(room.player.x, 800 + room.movement_speed * 0.025), "Half stick produces half speed")
	check(is_equal_approx(room.actor.elapsed, 0.025), "Half stick scales gait to actual travel")
	room.player = Vector2(800, 650)
	room.touch_direction = Vector2(1, 1)
	room._process(0.05)
	check(is_equal_approx(room.player.distance_to(Vector2(800, 650)), room.movement_speed * 0.05), "Diagonal movement cannot exceed speed")
	room.player = Vector2(800, 650)
	room.touch_direction = Vector2.RIGHT
	room.actor.advance(2, false, 0)
	room._process(0.5)
	check(is_equal_approx(room.player.x, 807.75) and is_equal_approx(room.actor.elapsed, 0.05), "Slow frame caps movement and gait together")
	room.touch_direction = Vector2.ZERO
	room.player = Vector2(800, 650)
	room.target = Vector2(900, 650)
	room.moving_to_target = true
	room._process(0.05)
	check(is_equal_approx(room.player.x, 807.75), "Floor-tap movement uses the same faster speed")
	check(FileAccess.get_file_as_string(path) == save_before_movement, "Movement tuning leaves persisted save untouched")
	room._reset_movement()
	# Exercise Godot's real viewport routing, not only the joystick methods.
	var routed_touch := InputEventScreenTouch.new()
	routed_touch.index = 0
	routed_touch.pressed = true
	routed_touch.position = pad.global_position + pad.size * 0.5 + Vector2(60, 0)
	Input.parse_input_event(routed_touch.duplicate())
	await process_frame
	check(pad.owner_index == 0 and room.touch_direction.x > 0.9 and not room.moving_to_target, "Viewport routes touch to joystick without floor click")
	var routed_drag := InputEventScreenDrag.new()
	routed_drag.index = 0
	routed_drag.position = pad.global_position + pad.size * 0.5 + Vector2(200, -200)
	Input.parse_input_event(routed_drag)
	await process_frame
	check(pad.direction.x > 0 and pad.direction.y < 0 and is_equal_approx(pad.direction.length(), 1), "Owned drag continues outside joystick bounds")
	routed_touch.pressed = false
	routed_touch.position = routed_drag.position
	Input.parse_input_event(routed_touch.duplicate())
	await process_frame
	check(pad.owner_index == -1 and room.touch_direction == Vector2.ZERO, "Release outside pad resets through viewport")
	routed_touch.pressed = true
	routed_touch.position = pad.global_position + pad.size * 0.5 + Vector2(60, 0)
	Input.parse_input_event(routed_touch.duplicate())
	await process_frame
	var ui_touch := InputEventScreenTouch.new()
	ui_touch.index = 1
	ui_touch.pressed = true
	ui_touch.position = Vector2(165, 40)
	Input.parse_input_event(ui_touch.duplicate())
	await process_frame
	ui_touch = ui_touch.duplicate()
	ui_touch.pressed = false
	Input.parse_input_event(ui_touch.duplicate())
	await process_frame
	check(is_instance_valid(room.overlay), "Second finger can open Bag while joystick is held")
	routed_touch.pressed = false
	Input.parse_input_event(routed_touch.duplicate())
	room._close_overlay()
	room.open_chest(false)
	routed_touch.pressed = true
	routed_touch.position = pad.global_position + pad.size * 0.5 + Vector2(60, 0)
	Input.parse_input_event(routed_touch.duplicate())
	await process_frame
	check(pad.owner_index == -1 and room.touch_direction == Vector2.ZERO, "Modal UI does not activate joystick beneath it")
	routed_touch.pressed = false
	Input.parse_input_event(routed_touch.duplicate())
	room._close_overlay()
	check(not room.can_stand(Vector2(400, 550)), "Bed collision")
	check(not room.can_stand(room.prop_rects.chest.get_center()), "Chest collision")
	check(not room.can_stand(Vector2(0, 0)), "Room boundary")
	room.player = Vector2(650, 600)
	room.move_player(Vector2(-1000, 0))
	check(room.player.x >= room.prop_rects.bed.end.x + 16, "Large movement cannot tunnel through bed")
	room.touch_direction = Vector2.LEFT
	room._process(0.05)
	check(room.can_stand(room.player) and room.actor.current_animation == "idle", "Blocked player stays outside furniture and stops gait")
	room._reset_movement()
	room.player = room.anchors.mirror
	check(room.nearest_prop() == "mirror", "Mirror interaction radius")
	room.interact()
	await process_frame
	check(is_instance_valid(room.overlay), "Open mirror")
	check(room.overlay.base_option.disabled and room.overlay.class_option.disabled and not room.overlay.name_field.editable, "Mirror identity controls locked")
	var first = room.overlay
	room.interact()
	check(room.overlay == first, "Repeated interaction does not stack panels")
	var identity_before := [room.state.character.base, room.state.character["class"], room.state.character.username]
	room.overlay.draft.skin = "purple"
	room.overlay.draft.eyes = "Green"
	room.overlay._submit()
	check(room.overlay == null, "Save mirror closes panel")
	check(room.actor.appearance.skin == "purple" and room.actor.appearance.eyes == "Green", "Mirror save refreshes rendered appearance immediately")
	check([room.state.character.base, room.state.character["class"], room.state.character.username] == identity_before, "Mirror keeps identity unchanged")
	room.interact()
	await process_frame
	room.overlay.draft.skin = "blue"
	room._close_overlay()
	check(room.actor.appearance.skin == "purple", "Cancelled mirror draft does not alter gameplay appearance")
	check(room.overlay == null, "Close mirror")
	room.player = room.anchors.chest
	room.interact()
	await process_frame
	check(room.overlay != null, "Open functional chest")
	room._close_overlay()
	room.player = Vector2(900, room.prop_rects.mirror.end.y + 50)
	room._update_actor()
	check(room.actor.z_index > room.prop_nodes.mirror.z_index, "Player sorts in front below mirror")
	room.player.y = 380
	room._update_actor()
	check(room.actor.z_index < room.prop_nodes.chest.z_index, "Player sorts behind chest")
	var final_reload = Save.new()
	final_reload.path = path
	check(final_reload.load_saved() and final_reload.awake, "Wake flag survives reload")
	check(room.stage.z_index >= 0 and room.stage.z_index + room.actor.z_index < room.message.z_index, "World stays behind modal UI")
	var failed = Save.new()
	failed.character = state.character.duplicate(true)
	failed.chest.healing_potion = 5
	failed.path = "user://missing_directory/save.json"
	var prior: int = failed.chest.healing_potion
	check(not failed.transfer("healing_potion", false) and failed.chest.healing_potion == prior, "Failed inventory save rolls back")
	var old_eyes: String = failed.character.eyes
	check(not failed.apply_appearance({"eyes":"Blue"}) and failed.character.eyes == old_eyes, "Failed cosmetics save rolls back")
	var broken_path := path + ".broken"
	var file := FileAccess.open(broken_path, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	var broken = Save.new()
	broken.path = broken_path
	check(not broken.load_saved() and FileAccess.get_file_as_string(broken_path) == "not json", "Corrupted save stays untouched")
	DirAccess.remove_absolute(broken_path)
	room.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	for selected_class in Save.Inventory.WEAPONS.values():
		for base in ["male", "female"]:
			var slot = Save.new()
			slot.path = path
			var hero = Draft.new()
			hero.username = "ClassTester"
			hero.set_base(base)
			hero.character_class = selected_class.class_id
			check(slot.create(hero.payload()), "Create class starter slot")
			var class_room = preload("res://src/bedroom.gd").new()
			class_room.state = slot
			root.add_child(class_room)
			await process_frame
			check(is_equal_approx(class_room.movement_speed, 155.0), "Every base and class receives 155 px/s movement")
			check(class_room.actor.visible and class_room.actor.artwork_ready and class_room.actor.armor.texture != null and not class_room.sleeping, "Both bases and every class spawn visibly dressed")
			class_room.queue_free()
			await process_frame
			var weapon: String = Save.Inventory.starter_weapon(hero.character_class)
			check(slot.chest.healing_potion == 5 and slot.chest[weapon] == 1, "Five potions plus one class weapon regardless of gender")
			check(slot.equipped_armor == Save.Inventory.starter_armor(hero.character_class), "Class armor starts equipped for both bases")
			check(slot.chest.values().reduce(func(a, b): return a + b, 0) == 6, "No extra starter loot")
			check(not slot.equip(weapon), "Cannot equip weapon still in chest")
			check(slot.transfer(weapon, false) and slot.equip(weapon), "Take and equip own class weapon")
			check(not slot.equip(weapon), "Repeated equip cannot duplicate")
			check(slot.load_saved() and slot.equipped_weapon == weapon and slot.chest[weapon] == 0 and slot.bag[weapon] == 0, "Equipment persists without refill")
			check(slot.equipped_armor == Save.Inventory.starter_armor(hero.character_class), "Armor persists through equipment reload")
			check(slot.unequip() and slot.bag[weapon] == 1, "Unequip returns one item")
			check(slot.transfer(weapon, true) and slot.load_saved() and slot.chest[weapon] == 1, "Weapon stores and reloads once")
			var wrong := "mage_01_weapon" if hero.character_class != "Mage" else "warrior_01_weapon"
			slot.bag[wrong] = 1
			check(not slot.equip(wrong), "Foreign class weapon rejected")
			DirAccess.remove_absolute(path)
	check(Save.Inventory.WEAPONS.necromancer_01_weapon.type == "staff", "Necromancer uses staff")
	check(Save.Inventory.WEAPONS.warrior_01_weapon.type == "sword", "Warrior uses sword")
	for old_version in [1, 2]:
		var old_file := FileAccess.open(path, FileAccess.WRITE)
		old_file.store_string(JSON.stringify({"version":old_version, "tutorial_chest_seeded":true, "character":draft.payload(), "bag":({"travel_bread":2, "keepsake":1} if old_version == 1 else {"healing_potion":5}), "chest":({"travel_bread":0, "keepsake":0} if old_version == 1 else {"healing_potion":0}), "awake":true}))
		old_file.close()
		var migration = Save.new()
		migration.path = path
		check(migration.load_saved(), "Upgrade earlier local prototype save")
		check(migration.chest.healing_potion == (5 if old_version == 1 else 0), "Migration preserves collected potion counts")
		check(migration.chest.warrior_01_weapon == 1, "Migration adds only class starter weapon")
		check(migration.transfer("warrior_01_weapon", false) and migration.load_saved() and migration.chest.warrior_01_weapon == 0 and migration.bag.warrior_01_weapon == 1, "Migration is idempotent")
		DirAccess.remove_absolute(path)
	# A build-306 save with the old asleep flag and emptied chest must retain progress.
	var legacy = Save.new()
	legacy.path = path
	check(legacy.create(draft.payload()), "Create migration fixture")
	check(legacy.transfer("healing_potion", false), "Collect potion before migration")
	check(legacy.transfer("warrior_01_weapon", false) and legacy.equip("warrior_01_weapon"), "Equip before migration")
	var prior_data = JSON.parse_string(FileAccess.get_file_as_string(path))
	prior_data.version = 4
	prior_data.awake = false
	var legacy_file := FileAccess.open(path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(prior_data))
	legacy_file.close()
	check(legacy.load_saved() and legacy.awake, "Old asleep save becomes immediately playable")
	check(legacy.bag == prior_data.bag and legacy.chest == prior_data.chest and legacy.equipped_weapon == prior_data.equipped_weapon and legacy.equipped_armor == prior_data.equipped_armor, "Wake migration preserves exact inventory and equipment")
	check(legacy.load_saved() and legacy.chest.healing_potion == 4 and legacy.chest.warrior_01_weapon == 0, "Wake migration is idempotent and never reseeds")
	DirAccess.remove_absolute(path)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.open_modal("guest")
	main._open_bedroom()
	await process_frame
	check(main.modal == null and main.bedroom != null, "Guest enters bedroom without account form")
	check(main.bedroom.overlay != null, "Guest without save opens creator")
	main.bedroom.cancel_overlay()
	await process_frame
	check(main.bedroom == null, "Cancel initial creator returns to title")
	main._open_bedroom()
	await process_frame
	main.bedroom.state.path = path
	main.bedroom.overlay.draft.username = "LocalHero"
	main.bedroom.overlay._submit()
	await process_frame
	check(main.bedroom.overlay == null and not main.bedroom.sleeping and main.bedroom.actor.visible, "Creator submit immediately shows dressed player")
	main.bedroom._exit()
	await process_frame
	check(main.bedroom == null, "Saved exit restores title")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("BEDROOM CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func reachable(room, from: Vector2, target: Vector2) -> bool:
	var pending: Array[Vector2] = [from]
	var visited := {}
	while not pending.is_empty():
		var point: Vector2 = pending.pop_back()
		if point.distance_to(target) < 32:
			return true
		for offset in [Vector2(25, 0), Vector2(-25, 0), Vector2(0, 25), Vector2(0, -25)]:
			var next: Vector2 = point + offset
			if not visited.has(next) and room.can_stand(next):
				visited[next] = true
				pending.append(next)
	return false
