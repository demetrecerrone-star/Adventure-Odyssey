extends "res://tests/tutorial_save_test.gd"

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(844,390)
	var capture := "--capture" in OS.get_cmdline_user_args()
	for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
		var state = fixture(selected_class)
		var weapon: String = Save.Inventory.starter_weapon(selected_class)
		check(state.transfer(weapon,false) and state.equip(weapon),"Equip "+selected_class)
		check(state.transfer("healing_potion",false),"Carry healing potion")
		for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]: take_step(state,action)
		check(state.set_location("starter_region",Vector2(1000,2020)),"Enter field")
		var world = load("res://src/starter_world.gd").new()
		world.state = state
		root.add_child(world); world.set_process(false)
		await process_frame
		world._update_combat_hud()
		check(world._uses_touch_hints() and not world.hud.combat_status.text.contains("[P]"),"Phone layout uses touch hints")
		root.size = Vector2i(1280,720)
		await process_frame
		check(world._uses_touch_hints() == (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()),"Wide desktop detection preserves keyboard hints")
		root.size = Vector2i(844,390)
		await process_frame
		for slot in 3:
			world.encounter.reset(); world.encounter.hp = 60
			world.player = world.encounter.enemies[0].position+Vector2(0,60)
			world._update_actor()
			check(world._checkpoint_combat(),"Persist skill fixture")
			var before: Dictionary = world.encounter.capture()
			DirAccess.make_dir_absolute(state.path+".tmp")
			world.use_class_skill(slot)
			check(world.encounter.capture() == before,"Failed save rolls back skill effects and cost")
			DirAccess.remove_absolute(state.path+".tmp")
			world._update_combat_hud()
			check(not world.hud.skill_buttons[slot].disabled,"Skill button enabled")
			world.hud.skill_buttons[slot].pressed.emit()
			check(world.encounter.skill_cooldowns[slot] > 0 and world.encounter.mana < 50,"Actual button applies skill and cost")
			check(state.load_saved() and state.combat.mana == world.encounter.mana,"Skill mana durable")
			world.encounter.reset(); world.encounter.hp = 60
			world.player = world.encounter.enemies[0].position+Vector2(0,60)
			check(world._checkpoint_combat(),"Reset for touch input")
			world._update_combat_hud()
			var control: Button = world.hud.skill_buttons[slot]
			var touch := InputEventScreenTouch.new()
			touch.index = 2; touch.pressed = true; touch.position = control.size*0.5
			control.gui_input.emit(touch)
			var release := InputEventScreenTouch.new()
			release.index = 2; release.pressed = false
			release.position = control.get_global_transform_with_canvas()*(control.size*0.5)
			world._input(release)
			check(world.encounter.skill_cooldowns[slot] > 0,"Secondary touch casts while movement finger held")
			var spent: float = world.encounter.mana
			world._input(release)
			check(world.encounter.mana == spent,"Released touch cannot cast twice")
			if capture:
				world._sync_encounter_visuals()
				for frame in 3: await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://screenshots/skill_%s_%d_844.png" % [selected_class.to_lower(),slot+1]) == OK,"Capture live skill")
		world.encounter.reset(); world.encounter.hp = 30; world.encounter.mana = 0
		check(world._checkpoint_combat(),"Save injured empty-mana state")
		world.open_field_supplies(); await process_frame
		check(is_instance_valid(world.overlay),"Supplies opens")
		if capture:
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://screenshots/supplies_%s_844.png" % selected_class.to_lower()) == OK,"Capture supplies")
		var count: int = state.bag.healing_potion
		DirAccess.make_dir_absolute(state.path+".tmp")
		world.overlay.action_requested.emit("healing_potion")
		check(state.bag.healing_potion == count and world.encounter.hp == 30,"Failed potion write consumes nothing")
		DirAccess.remove_absolute(state.path+".tmp")
		world.overlay.action_requested.emit("healing_potion")
		check(state.bag.healing_potion == count-1 and world.encounter.hp == 70,"Actual supply action heals and consumes one")
		world.overlay.action_requested.emit("mana_potion")
		check(world.encounter.mana == 0,"Shared cooldown blocks second potion")
		world._close_overlay()
		world.player = world.encounter.enemies[0].position+Vector2(0,60)
		var hp: int = world.encounter.enemies[0].hp
		world.attack_nearby()
		check(world.encounter.enemies[0].hp < hp,"Zero mana still permits basic attack")
		world.encounter.hp = 0; world.encounter.defeated = true
		world._process_encounter(0); world.cancel_overlay()
		check(world.encounter.hp == world.encounter.max_hp and world.encounter.mana == world.encounter.max_mana,"Free retry restores resources")
		check(state.load_saved() and state.bag.healing_potion == count-1,"Retry and reload never refund consumed potion")
		world.queue_free(); await process_frame
	for path in paths: DirAccess.remove_absolute(path)
	print("FIELD COMBAT INTEGRATION CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
