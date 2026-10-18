extends "res://tests/tutorial_save_test.gd"
func capture(file: String) -> void:
	for tick in 3: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+file)==OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	var state = fixture("Ranger","female")
	assert(state.transfer("ranger_01_weapon",false) and state.equip("ranger_01_weapon"))
	for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]: take_step(state,action)
	assert(state.set_location("starter_region",Vector2(1110,2250)))
	assert(state.record_encounter_victory("south_meadow_slimes"))
	take_step(state,"guild_complete_first_combat")
	take_step(state,"guild_assign_forest_patrol")
	assert(state.set_location("starter_region",Vector2(740,1060)))
	var world = load("res://src/starter_world.gd").new()
	world.state = state
	root.add_child(world); world.set_process(false)
	world.player = Vector2(740,1060); world._update_actor(); world._process_encounter(0)
	world.message.text = "Western Forest patrol • Two wolves guard the wooded bend."
	await capture("forest_patrol_meadow_1280.png")
	world.player = Vector2(700,950); world._update_actor(); world._process_encounter(0.05)
	await capture("forest_patrol_windup_1280.png")
	world.attack_nearby()
	await capture("forest_patrol_strike_1280.png")
	world.use_class_skill(0)
	for tick in 18: world._process_encounter(0.05)
	assert(state.transfer("healing_potion",false))
	root.size = Vector2i(844,390)
	for handed in [false,true]:
		world.control_preferences.left_handed = handed
		world._layout(); world._apply_control_layout()
		await capture("forest_patrol_phone_%s.png" % ("left" if handed else "right"))
		world.open_menu(); world.overlay.show_page("quest_log")
		await capture("forest_patrol_journal_%s.png" % ("left" if handed else "right"))
		world.cancel_overlay()
		world.open_field_supplies()
		await capture("forest_patrol_supplies_%s.png" % ("left" if handed else "right"))
		world.cancel_overlay()
	for enemy in world.encounter.enemies:
		world.player = enemy.position+Vector2(0,60)
		for hit in 8:
			if enemy.hp <= 0: break
			world.encounter.attack_cooldown = 0
			world.attack_nearby()
	world._process_encounter(0)
	assert(state.encounter_is_complete("west_forest_patrol"))
	world.queue_free(); await process_frame
	move_near(state,"guild_complete_forest_patrol")
	var room = load("res://src/town_interior.gd").new()
	room.room_id = "guild_interior"; room.state = state
	root.add_child(room); room.set_process(false); await process_frame
	var npc: Dictionary = room.room_data.npcs[0]
	room.player = Vector2(npc.interaction_anchor[0],npc.interaction_anchor[1]); room._update_actor()
	room.interact(); await process_frame
	await capture("forest_patrol_actual_turnin.png")
	room.overlay.action_requested.emit("guild_complete_forest_patrol"); await process_frame
	assert(state.wallet_gold == 81 and state.tutorial.stage == "forest_patrol_complete")
	await capture("forest_patrol_actual_complete.png")
	room.cancel_overlay(); room.open_menu(); room.overlay.show_page("quest_log")
	await capture("forest_patrol_completed_journal.png")
	room.queue_free(); await process_frame
	for path in paths: DirAccess.remove_absolute(path)
	print("FOREST PATROL NATIVE: 12 views captured")
	quit()
