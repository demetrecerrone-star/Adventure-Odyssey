extends "res://tests/tutorial_save_test.gd"

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(844,390)
	for selected_class in ["Warrior", "Ranger", "Mage", "Necromancer", "Assassin", "Paladin"]:
		var state = fixture(selected_class)
		var weapon: String = Save.Inventory.starter_weapon(selected_class)
		check(state.transfer(weapon, false) and state.equip(weapon), "Equip " + selected_class)
		for action in ["read_envelope", "guild_assign_blacksmith", "blacksmith_claim_starter", "upgrade", "guild_after_blacksmith", "apothecary_claim_gift", "guild_after_apothecary", "general_store_claim_keepsake", "guild_after_general_store", "guild_assign_first_combat"]:
			take_step(state, action)
		check(state.set_location("starter_region", Vector2(1000,2020)), "Persist field entry")
		var world = load("res://src/starter_world.gd").new()
		world.state = state
		root.add_child(world)
		world.set_process(false)
		await process_frame
		world._process_encounter(0)
		check(not world.hud.attack_button.disabled, "Equipped class can use Attack")
		check(not world.interact_button.visible, "Inactive Use button never obscures the encounter")
		world.player = world.ENVELOPE; world._process_encounter(0)
		check(world.interact_button.visible, "Real nearby interaction remains available during assignment")
		world.player = Vector2(1000,2020); world._process_encounter(0)
		var before: Dictionary = snap(state)
		world.encounter.hp = 0
		world.encounter.defeated = true
		world._process_encounter(0)
		check(is_instance_valid(world.overlay) and not world.joystick.input_enabled, "Defeat is modal")
		world.cancel_overlay()
		check(world.encounter.hp == 100 and world.encounter.living_count() == 3 and snap(state).bag == before.bag and snap(state).item_ledger == before.item_ledger and state.wallet_gold == before.wallet_gold, "Retry restores encounter and preserves belongings")
		world.open_menu()
		var first_hp: int = world.encounter.enemies[0].hp
		world.player = world.encounter.enemies[0].position
		world.attack_nearby()
		check(world.encounter.enemies[0].hp == first_hp, "Menu blocks attacks")
		world._close_overlay()
		check(state.unequip(), "Temporarily remove weapon")
		world.attack_nearby()
		check(world.encounter.enemies[0].hp == first_hp, "Weapon required")
		check(state.equip(weapon), "Restore weapon")
		for enemy in world.encounter.enemies:
			world.player = enemy.position + Vector2(0,60)
			check(world.can_stand(world.player), "Player can stand in attack range")
			for hit in range(3):
				world.encounter.attack_cooldown = 0
				world.attack_nearby()
			check(enemy.hp == 0, "Actual world strike defeats assigned slime")
		check(world.encounter.victory and state.tutorial.stage == "first_combat_active", "Victory pending persistence")
		DirAccess.make_dir_absolute(state.path + ".tmp")
		world._process_encounter(0)
		check(state.tutorial.stage == "first_combat_active" and world.message.text.contains("could not save"), "Failed save visibly retains victory retry")
		DirAccess.remove_absolute(state.path + ".tmp")
		world._process_encounter(2.1)
		check(state.tutorial.stage == "return_guild_first_combat" and state.wallet_gold == 0, "Real encounter event advances quest without payment")
		check(state.load_saved() and state.encounter_is_complete("south_meadow_slimes"), "Real victory persists")
		world.queue_free()
		await process_frame
		world = load("res://src/starter_world.gd").new(); world.state = state
		root.add_child(world); world.set_process(false)
		await process_frame
		world._process_encounter(0)
		for enemy in world.enemy_nodes: check(not enemy.visible, "Reload never respawns cleared monsters")
		check(world.hud.attack_button.disabled, "Cleared encounter disables combat")
		world.queue_free(); await process_frame
		var room = load("res://src/town_interior.gd").new()
		room.room_id = "guild_interior"; room.state = state
		root.add_child(room); room.set_process(false)
		await process_frame
		var npc: Dictionary = room.room_data.npcs[0]
		room.player = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1]); room._update_actor()
		room.interact(); await process_frame
		check(is_instance_valid(room.overlay) and room.overlay._view.choices[0].id == "guild_complete_first_combat", "Guild offers earned turn-in")
		room.overlay.action_requested.emit("guild_complete_first_combat")
		await process_frame
		check(state.wallet_gold == 25 and state.tutorial.stage == "tutorial_complete", "Scene turn-in pays once")
		check(room.overlay._view.choices.size() == 1 and room.overlay._view.choices[0].id == "guild_assign_forest_patrol", "Completed guild offers next assignment, never repeats reward")
		if selected_class == "Warrior" and "--capture" in OS.get_cmdline_user_args():
			for tick in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://screenshots/quest_completed_guild_scene_844.png") == OK, "Capture actual completed guild scene")
		room._close_overlay(); room.open_menu(); room.overlay.show_page("quest_log")
		await process_frame
		check(state.load_saved() and state.wallet_gold == 25, "Completed scene state reloads")
		if selected_class == "Warrior" and "--capture" in OS.get_cmdline_user_args():
			for tick in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://screenshots/quest_completed_log_844.png") == OK, "Capture actual completed quest log")
		room.queue_free(); await process_frame
	for path in paths: DirAccess.remove_absolute(path)
	print("FIRST COMBAT INTEGRATION CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
