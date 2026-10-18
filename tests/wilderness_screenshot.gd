extends "res://tests/tutorial_save_test.gd"
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png((OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")+"/"+file)==OK)
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	var w = preload("res://src/starter_world.gd").new()
	w.state = fixture("Warrior")
	assert(w.state.transfer("warrior_01_weapon",false) and w.state.equip("warrior_01_weapon"))
	for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]: take_step(w.state,action)
	assert(w.state.set_location("starter_region",Vector2(1110,2250)))
	root.add_child(w)
	w.set_process(false)
	w.player = Vector2(1110,2250)
	w._update_actor()
	w._process(0)
	w.message.text = "South meadow • Attack [F] nearby. Step away from amber windups."
	await capture("wilderness_meadow.png")
	w.player = Vector2(1080,2190)
	w._update_actor()
	w._process_encounter(0.05)
	await capture("wilderness_windup.png")
	w.attack_nearby()
	await capture("wilderness_attack.png")
	root.size = Vector2i(844,390)
	w._layout()
	w._apply_control_layout()
	await capture("wilderness_phone.png")
	w.encounter.hp = 0
	w.encounter.defeated = true
	w._process_encounter(0)
	await capture("wilderness_retry.png")
	w.cancel_overlay()
	await capture("wilderness_restarted.png")
	root.size = Vector2i(1280,720)
	for sprite in w.wilderness_nodes:
		if sprite.texture.resource_path.ends_with("oak_young.png"):
			w.player = Vector2(890,2220)
			w._update_actor()
			await capture("wilderness_tree_occlusion.png")
	if "--motion" in OS.get_cmdline_user_args():
		w.encounter.reset()
		w.player = Vector2(1080,2190)
		w._update_actor()
		for frame in 120:
			w.touch_direction = Vector2.RIGHT if frame in range(26,45) else (Vector2.LEFT if frame in range(65,84) else Vector2.ZERO)
			if frame in [12,55,100]: w.attack_nearby()
			w._process(1.0/30.0)
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://screenshots/wilderness_motion_%03d.png" % frame)==OK)
		w._reset_movement()
	w.queue_free()
	await process_frame
	print("Wilderness native captures complete")
	for path in paths: DirAccess.remove_absolute(path)
	quit()
