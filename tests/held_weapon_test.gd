extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HELD WEAPON TEST FAILED: " + description)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for base in ["male", "female"]:
		var avatar = preload("res://src/layered_avatar.gd").new()
		root.add_child(avatar)
		avatar.configure(base, "Warrior")
		check(not avatar.weapon_front.visible, "No equipped item means no weapon")
		avatar.set_equipped_weapon("warrior_01_weapon")
		for direction in range(4):
			avatar.advance(direction, false, 0)
			check(avatar.weapon_front.frame == direction and avatar.weapon_back.frame == direction, "Idle facing matches")
			for frame in range(8):
				avatar.advance(direction, true, 0)
				avatar.elapsed = float(frame) / 16
				avatar.advance(direction, true, 0)
				check(avatar.weapon_front.visible and avatar.weapon_back.visible, "Both weapon layers available")
				check(avatar.weapon_front.frame == (1 if avatar.current_animation == "walk_left" and avatar.uses_painted_pilot() else avatar.body.frame) and avatar.weapon_back.frame == (1 if avatar.current_animation == "walk_left" and avatar.uses_painted_pilot() else avatar.body.frame), "Weapon gait registered")
		check(avatar.weapon_back.get_index() < avatar.body.get_index() and avatar.weapon_front.get_index() > avatar.armor.get_index(), "Back-body-armor-front depth")
		avatar.set_equipped_weapon("mage_01_weapon")
		check(not avatar.weapon_front.visible, "Wrong class weapon hidden")
		avatar.configure(base, "Mage")
		avatar.set_equipped_weapon("mage_01_weapon")
		check(avatar.weapon_front.visible, "Mage registered art available")
		avatar.queue_free()
		await process_frame
	for base in ["male", "female"]:
		for cls in preload("res://src/creator/catalog.gd").CLASSES:
			var avatar = preload("res://src/layered_avatar.gd").new()
			root.add_child(avatar)
			avatar.configure(base, cls)
			avatar.set_equipped_weapon(cls.to_lower() + "_01_weapon")
			for direction in range(4):
				for frame in range(8):
					avatar.advance(direction, true, 0)
					avatar.elapsed = float(frame) / 16
					avatar.advance(direction, true, 0)
					check(avatar.weapon_front.visible and avatar.weapon_back.visible, "Every class/both bases has paired weapon layers")
					check(avatar.weapon_front.frame == (1 if avatar.current_animation == "walk_left" and avatar.uses_painted_pilot() else avatar.body.frame) and avatar.weapon_back.frame == (1 if avatar.current_animation == "walk_left" and avatar.uses_painted_pilot() else avatar.body.frame), "Every weapon follows gait")
			avatar.queue_free()
			await process_frame
	var room = preload("res://src/bedroom.gd").new()
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.username = "WeaponTest"
	room.state.path = "user://weapon_test.json"
	check(room.state.create(draft.payload()), "Create local save")
	root.add_child(room)
	await process_frame
	check(not room.actor.weapon_front.visible, "Chest ownership not equipped")
	room.state.transfer("warrior_01_weapon", false)
	room.open_chest()
	check(not room.actor.weapon_front.visible, "Bag ownership not equipped")
	check(room.state.equip("warrior_01_weapon"), "Equip succeeds")
	room.open_chest()
	check(room.actor.weapon_front.visible, "Equip refreshes rendered state")
	var path: String = room.state.path
	room.state.path = "user://nonexistent/weapon.json"
	check(not room.state.unequip(), "Failed save rejects unequip")
	room.open_chest()
	check(room.actor.weapon_front.visible, "Failed unequip retains rendered weapon")
	room.state.path = path
	check(room.state.unequip(), "Unequip succeeds")
	room.open_chest()
	check(not room.actor.weapon_front.visible, "Unequip hides rendered weapon")
	room.state.path = "user://nonexistent/weapon.json"
	check(not room.state.equip("warrior_01_weapon"), "Failed save rejects equip")
	room.open_chest()
	check(not room.actor.weapon_front.visible, "Failed equip does not show weapon")
	room.state.path = path
	room.state.equip("warrior_01_weapon")
	check(room.state.load_saved(), "Equipped save reloads")
	room._start_character()
	check(room.actor.weapon_front.visible, "Reload restores held weapon")
	DirAccess.remove_absolute(path)
	room.queue_free()
	await process_frame
	print("HELD WEAPON: %d checks; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
