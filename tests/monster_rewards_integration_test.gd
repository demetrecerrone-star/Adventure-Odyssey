extends "res://tests/tutorial_save_test.gd"
func run() -> void:
	if "--capture" in OS.get_cmdline_user_args(): DirAccess.make_dir_recursive_absolute("res://screenshots")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(844,390)
	for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
		var state = fixture(selected_class)
		var weapon: String = Save.Inventory.starter_weapon(selected_class)
		check(state.transfer(weapon,false) and state.equip(weapon),"Equip starter")
		for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]: take_step(state,action)
		check(state.set_location("starter_region",Vector2(1000,2020)),"Enter meadow")
		var world = load("res://src/starter_world.gd").new(); world.state = state
		root.add_child(world); world.set_process(false); await process_frame
		world.player = world.encounter.enemies[0].position+Vector2(0,60)
		for hit in 2: world.encounter.attack_cooldown = 0; world.attack_nearby()
		DirAccess.make_dir_absolute(state.path+".tmp")
		world.encounter.attack_cooldown = 0; world.attack_nearby()
		check(world.encounter.enemies[0].hp == 0 and state.wallet_gold == 0,"Failed reward write retains unpaid corpse without currency")
		var before: Dictionary = world.encounter.capture()
		world._process_encounter(1)
		check(world.encounter.capture() == before,"Unpaid reward pauses enemy simulation")
		DirAccess.remove_absolute(state.path+".tmp")
		world._process_encounter(0)
		check(state.wallet_gold == 3 and state.wallet_sigils == 1,"Retry persists one monster reward")
		world.encounter.hp = 0; world.encounter.defeated = true
		world._process_encounter(0); world.cancel_overlay()
		check(world.encounter.living_count() == 2 and state.wallet_gold == 3,"Death retry restores only undefeated monsters")
		world.queue_free(); await process_frame
		check(state.load_saved(),"Reload partial encounter")
		world = load("res://src/starter_world.gd").new(); world.state = state
		root.add_child(world); world.set_process(false); await process_frame
		check(world.encounter.living_count() == 2,"Reload suppresses rewarded spawn")
		for index in [1,2]:
			world.player = world.encounter.enemies[index].position+Vector2(0,60)
			for hit in 3: world.encounter.attack_cooldown = 0; world.attack_nearby()
		world._process_encounter(0)
		check(state.wallet_gold == 9 and state.wallet_sigils == 3 and state.tutorial.stage == "return_guild_first_combat","Clear pays exactly three monster rewards")
		check(world.hud.progression_label.text.contains("30 / 100") and world.hud.status.text.contains("3 Sigils"),"HUD exposes XP and separate earned currency")
		world.queue_free(); await process_frame
		check(state.load_saved() and state.get_progression_summary().total_xp == 30,"Clear and XP persist together")
		move_near(state,"guild_complete_first_combat")
		check(state.perform_tutorial_action("guild_complete_first_combat").ok,"Turn in meadow")
		check(state.perform_tutorial_action("guild_assign_forest_patrol").ok,"Accept forest")
		check(state.set_location("starter_region",Vector2(850,1230)),"Enter forest")
		world = load("res://src/starter_world.gd").new(); world.state = state
		root.add_child(world); world.set_process(false); await process_frame
		for enemy in world.encounter.enemies:
			world.player = enemy.position+Vector2(0,60)
			for hit in 4: world.encounter.attack_cooldown = 0; world.attack_nearby()
		world._update_actor()
		world._process_encounter(0)
		check(state.stats.level == 2 and state.wallet_gold == 50 and state.wallet_sigils == 7,"Actual five kills reach level2 and7 Sigils")
		check(state.get_stat_summary().unspent_points == 5,"Actual earned level grants5 free points")
		if selected_class == "Warrior" and "--capture" in OS.get_cmdline_user_args():
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://screenshots/monster_rewards_level2_844.png") == OK,"Capture real level2 wallet")
		world.open_menu(); world.overlay.show_page("stats")
		await process_frame
		check(world.overlay.subtitle_label.text.contains("5"),"Earned points shown in actual stat menu")
		if selected_class == "Warrior" and "--capture" in OS.get_cmdline_user_args():
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://screenshots/monster_rewards_statpoints_844.png") == OK,"Capture real five-point stat menu")
		check(state.allocate_stat_points({"VIT":5},state.stats.revision).ok,"Spend actual earned points")
		world._process_encounter(0)
		check(world.encounter.max_hp == state.Resources.limits(state.stats).hp and world.encounter.hp == 100,"Stat revision refreshes live cap without free healing")
		world.queue_free(); await process_frame
	for path in paths: DirAccess.remove_absolute(path)
	print("MONSTER REWARD INTEGRATION CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
