extends SceneTree
const Draft = preload("res://src/creator/character_draft.gd")
const Catalog = preload("res://src/creator/catalog.gd")
const Flow = preload("res://src/creator/flow.gd")
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
	var draft = Draft.new()
	check(Catalog.SKINS.size() == 12 and Catalog.CLASSES.size() == 6, "approved catalog counts")
	check(Catalog.hair_ids("male").size() == 15 and Catalog.hair_ids("female").size() == 15, "separate hair counts")
	draft.username = "Hero_123"
	draft.character_class = "Necromancer"
	draft.hair = "male_hair_13"
	draft.set_base("female")
	draft.hair = "female_hair_09"
	draft.set_base("male")
	check(draft.hair == "male_hair_13", "male selection restored")
	draft.set_base("female")
	check(draft.hair == "female_hair_09", "female selection restored")
	var rng := RandomNumberGenerator.new()
	rng.seed = 900
	for i in range(200):
		draft.randomize_appearance(rng)
		check(draft.base == "female" and draft.hair.begins_with("female_"), "random obeys selected base")
		check(draft.username == "Hero_123" and draft.character_class == "Necromancer", "random preserves name and class")
		check(draft.validate().is_empty(), "random output valid")
	for bad in ["", "ab", "1Hero", " Hero", "Hero Name", "<script>", "Hero!", "abcdefghijklmnopqrstu"]:
		draft.username = bad
		check(not draft.validate().is_empty(), "invalid name rejected " + bad)
	draft.username = "Hero_123"
	check(Draft.gear_allowed({"class_id":"Warrior"}, "Warrior"), "matching class allowed")
	check(not Draft.gear_allowed({"class_id":"Warrior"}, "Mage"), "other class denied")
	check(not Draft.gear_allowed({}, "Warrior"), "legacy unrestricted gear denied")
	var flow = Flow.new()
	check(flow.begin_save(draft).is_empty(), "no save before authenticated profile")
	check(not flow.authenticated_profile_loaded({"account_id":"test"}), "unknown completion does not create character")
	check(not flow.authenticated_profile_loaded({"account_id":"test", "character_status":"complete"}), "complete requires server character id")
	check(flow.authenticated_profile_loaded({"account_id":"test", "character_status":"incomplete"}), "incomplete profile hook")
	var request: Dictionary = flow.begin_save(draft)
	check(not request.is_empty(), "save request produced")
	check(flow.begin_save(draft).is_empty(), "double save blocked")
	flow.sign_out()
	check(not flow.save_result(request.generation, true, "old-character"), "late save after sign-out ignored")
	check(flow.authenticated_profile_loaded({"account_id":"test", "character_status":"incomplete"}), "can resume incomplete account")
	request = flow.begin_save(draft)
	check(not flow.save_result(request.generation, false), "failed save never completes character")
	check(not flow.begin_save(draft).is_empty(), "failed save permits retry")
	var panel = load("res://src/creator/creator_panel.gd").new()
	panel.development_mode = true
	root.add_child(panel)
	panel.size = Vector2(960, 540)
	await process_frame
	await process_frame
	check("unavailable" in panel.preview.status.text, "missing art is honestly labeled")
	check(panel.preview.stage.get_child_count() == 0, "no fake body shown")
	check(panel.hair_option.item_count == 15, "15 selected-base choices")

	var fixture_layers := {}
	var fixture_hair: String = panel.draft.hair + "/" + panel.draft.hair_color.to_lower()
	for key in ["rear_hair/" + fixture_hair, "body/" + panel.draft.skin, "eyes/" + panel.draft.eyes.to_lower(), "front_hair/" + fixture_hair]:
		fixture_layers[key] = "res://tests/fixtures/creator-layer.svg"
	panel.preview.manifest = {"bases":{"male":{"status":"test_fixture", "view":"angled_top_down_2_5d", "layers":fixture_layers}}}
	panel.preview.update_preview(panel.draft)
	check("unavailable" in panel.preview.status.text, "test fixture denied by default")
	panel.preview.allow_test_fixtures = true
	panel.preview.update_preview(panel.draft)
	check("TEST FIXTURE ONLY" in panel.preview.status.text, "test artwork always labeled")
	check(panel.preview.stage.get_child_count() == 4, "four ordered aligned layers composed")
	panel.preview.manifest = Catalog.empty_manifest()
	panel.preview.update_preview(panel.draft)
	await process_frame
	check(panel.preview.stage.get_child_count() == 0, "old layers removed when new assets unavailable")

	for i in range(8):
		panel.base_option.item_selected.emit(i % 2)
		check(panel.hair_option.item_count == 15, "switch keeps catalog count")
		check(panel.draft.hair.begins_with(panel.draft.base), "switch keeps correct hair")
	panel.name_field.text = "ValidHero"
	panel.name_field.text_changed.emit("ValidHero")
	panel._submit()
	check("Nothing was saved" in panel.notice.text, "development save does not pretend success")
	panel.development_mode = false
	panel._submit()
	check("unavailable" in panel.notice.text, "unwired backend blocked")
	panel.size = Vector2(720, 400)
	panel.safe_override = Rect2(30, 15, 660, 370)
	panel.keyboard_height_override = 150
	panel.name_field.grab_focus()
	panel._layout()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	check(panel.panel.position.x >= 30, "safe left respected")
	check(panel.panel.position.y + panel.panel.size.y <= 250, "panel fits simulated keyboard region")
	check(panel.left_scroll.get_v_scroll_bar().max_value > panel.left_scroll.size.y, "keyboard-constrained side options scroll")
	check(panel.panel.get_global_rect().encloses(panel.name_field.get_global_rect()), "fixed username remains visible above keyboard")
	var dismiss_count := [0]
	panel.dismissed.connect(func(): dismiss_count[0] += 1)
	panel._dismiss()
	check(dismiss_count[0] == 1, "back emits dismissal")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._unhandled_key_input(escape)
	check(dismiss_count[0] == 2, "Escape emits dismissal")
	panel._notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(dismiss_count[0] == 3, "Android Back emits dismissal")
	panel.queue_free()
	await process_frame
	for i in range(3):
		var reopened = load("res://src/creator/creator_panel.gd").new()
		reopened.development_mode = true
		root.add_child(reopened)
		reopened.size = Vector2(960, 540)
		await process_frame
		check(reopened.draft.username.is_empty(), "new development session has no persisted account")
		reopened.queue_free()
		await process_frame
	print("CREATOR TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
