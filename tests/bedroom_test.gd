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
	check(room.sleeping, "New character begins asleep")
	for id in room.anchors:
		check(room.can_stand(room.anchors[id]), "Interaction anchor is walkable: " + id)
		check(reachable(room, room.wake_spawn, room.anchors[id]), "Interaction accessible from wake spawn: " + id)
	check(room.prop_nodes.has("bed") and room.prop_nodes.has("chest") and room.prop_nodes.has("mirror"), "Three separate furniture layers")
	room.wake_up()
	check(not room.sleeping and room.state.awake, "Wake flow sets saved flag")
	check(room.can_stand(room.player), "Wake beside bed in walkable space")
	check(not room.can_stand(Vector2(400, 550)), "Bed collision")
	check(not room.can_stand(room.prop_rects.chest.get_center()), "Chest collision")
	check(not room.can_stand(Vector2(0, 0)), "Room boundary")
	room.player = Vector2(650, 600)
	room.move_player(Vector2(-1000, 0))
	check(room.player.x >= room.prop_rects.bed.end.x + 16, "Large movement cannot tunnel through bed")
	room.player = room.anchors.mirror
	check(room.nearest_prop() == "mirror", "Mirror interaction radius")
	room.interact()
	await process_frame
	check(is_instance_valid(room.overlay), "Open mirror")
	check(room.overlay.base_option.disabled and room.overlay.class_option.disabled and not room.overlay.name_field.editable, "Mirror identity controls locked")
	var first = room.overlay
	room.interact()
	check(room.overlay == first, "Repeated interaction does not stack panels")
	room._close_overlay()
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
	check(main.bedroom.overlay == null and main.bedroom.sleeping, "Creator submit starts wake scene")
	main.bedroom.wake_up()
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
