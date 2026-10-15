extends SceneTree
# Exercise both dialogue styles, page navigation, skip, and named NPC panels.
func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> bool:
	if not ok:
		push_error("DIALOGUE TEST FAILED: " + description)
		quit(1)
		return false
	return true

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._open_creator()
	scene.char_input.text = "Dialogue Tester"
	scene._create_character()
	await process_frame
	if not _check(scene.current_map == "bedroom", "tutorial begins in bedroom"): return
	if not _check(scene.popup != null and scene.popup.mode == "tutorial", "opening journal overlay displayed"): return
	if not _check(scene.popup.pages.size() == 4 and scene.popup.title_label.text == "ADVENTURER'S JOURNAL", "opening guidance pages and heading"): return
	if not _check(scene.popup.body_label.text.contains("first day as an adventurer"), "first day story text present"): return
	var tutorial = scene.popup
	tutorial.body_label.visible_characters = -1
	tutorial._on_primary()
	if not _check(tutorial.page_index == 1, "next tutorial page"): return
	tutorial._on_secondary()
	await process_frame
	if not _check(scene.popup == null and scene.data["tutorial_stage"] == "explore", "skip dismisses and records tutorial stage"): return
	if not _check(scene._load_save() and scene.data["tutorial_stage"] == "explore", "tutorial status saved"): return
	scene._show_journal("REST AND RECOVER", ["Rest at your bed."])
	await process_frame
	if not _check(scene.popup.mode == "tutorial" and scene.popup.chapter == "REST AND RECOVER", "context help reuses journal design"): return
	scene.popup._on_secondary()
	await process_frame
	scene._enter_world("town", Vector2(1030,980))
	await process_frame
	if not _check(scene.npcs.size() == 8, "town NPCs preserved"): return
	for npc in scene.npcs:
		scene._show_npc_chat(npc)
		await process_frame
		if not _check(scene.popup.mode == "npc" and scene.popup.npc_name == npc["name"], "named NPC chat: " + str(npc["name"])): return
		if not _check(scene.popup.npc_role == npc["role"] and not scene.popup.npc_advice.is_empty(), "role/advice bound: " + str(npc["name"])): return
		if not _check(scene.popup.body_label.text == npc["dialogue"], "existing NPC text retained: " + str(npc["name"])): return
		if not _check(scene.popup.primary_button.size.x >= 190 and scene.popup.secondary_button.size.y >= 50, "touch-sized NPC choices"): return
		scene.popup.body_label.visible_characters = -1
		scene.popup._on_primary()
		if not _check(scene.popup.showing_advice and scene.popup.body_label.text == scene._npc_advice(npc["name"]), "ask for advice: " + str(npc["name"])): return
		scene.popup._on_secondary()
		await process_frame
		if not _check(scene.popup == null, "goodbye closes NPC dialogue"): return
	# NPC positions move with town art; interact with the actual spawned registrar.
	scene.player.position=scene.npcs[0]["node"].position
	scene._interact()
	await process_frame
	if not _check(scene.popup!=null and scene.popup.mode=="npc" and scene.popup.npc_name=="Ilyan Crest","TALK / USE opens NPC conversation"):return
	scene.popup._on_secondary()
	await process_frame
	print("ADVENTURE ODYSSEY DIALOGUE TEST: PASS")
	quit(0)
