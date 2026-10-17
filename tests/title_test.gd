extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAILED: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.buttons.size() == 4, "four real buttons")
	check(scene.brand.texture.get_width() == 2048, "exact brand source")
	for document in [scene.PREVIEW_DOCUMENTS.PRIVACY, scene.PREVIEW_DOCUMENTS.TERMS]:
		check("Draft for review" in document, "bundled document visibly a review draft")
		check("Developer: Dabsky" in document and "dabskycreativestudio@gmail.com" in document, "approved developer and contact bundled")
		check(document.length() > 1500, "complete document available without network")
	for kind in ["signin", "create", "google", "guest", "signin", "create"]:
		scene.open_modal(kind)
		await process_frame
		check(scene.modal_kind == kind, "modal opens " + kind)
		var current = scene.modal
		scene.open_modal(kind)
		check(scene.modal == current, "repeated click cannot stack")
		check(scene.buttons[0].disabled, "background disabled")
		if kind == "signin" or kind == "create":
			check(scene.fields.size() == (3 if kind == "create" else 2), "correct fields")
			check(scene.fields[1].secret, "password masked")
			scene.fields[0].text = "hero@example.com"
			for index in range(1, scene.fields.size()):
				scene.fields[index].text = "dummy-preview"
			scene._submit_preview()
			for field in scene.fields:
				check(field.text.is_empty(), "dummy credentials cleared")
			check("aren't available" in scene.notice.text, "honest preview message")
		scene.close_modal()
		await process_frame
		check(scene.modal == null and scene.fields.is_empty(), "modal removed and fields discarded")
		check(not scene.buttons[0].disabled, "menu restored")
		check(root.gui_get_focus_owner() != null, "keyboard focus restored")
	scene.open_modal("create")
	await process_frame
	await process_frame
	check(scene.password_toggles.size() == 2, "independent password visibility controls")
	check(scene.legal_controls.size() == 2, "privacy and terms previews present")
	for link in scene.legal_controls:
		check(not link.disabled, "preview documents available to read")
		check(link.size.y >= 48, "policy touch target")
	check(scene.modal_close.size.x >= 48 and scene.modal_close.size.y >= 48, "close touch target")
	check(scene.modal_scroll.follow_focus, "scroll follows keyboard focus")
	check(scene.modal_box.size.y <= scene.modal_scroll.size.y, "compact panel fits standard landscape without scrolling")
	scene._submit_preview()
	check("valid email" in scene.notice.text, "empty email validation")
	scene.fields[0].text = "bad email@example.com"
	scene._submit_preview()
	check("valid email" in scene.notice.text, "email whitespace rejected")
	scene.fields[0].text = "hero@example.com"
	scene.fields[1].text = "short"
	scene._submit_preview()
	check("8 characters" in scene.notice.text, "short password validation")
	scene.fields[1].text = "dummy-password"
	scene.fields[2].text = "other-password"
	scene._submit_preview()
	check("don't match" in scene.notice.text, "confirmation mismatch")
	scene.password_toggles[0].button_pressed = true
	check(not scene.fields[1].secret and scene.fields[2].secret, "show affects only chosen field")
	scene.password_toggles[0].button_pressed = false
	check(scene.fields[1].secret, "hide restores mask")
	scene.fields[0].text_submitted.emit(scene.fields[0].text)
	check(root.gui_get_focus_owner() == scene.fields[1], "keyboard next advances field")
	var retained_password = scene.fields[1]
	scene.close_modal()
	check(retained_password.text.is_empty(), "dismissal clears password before freeing")
	await process_frame
	scene.open_modal("create")
	check(scene.fields[1].secret and scene.fields[1].text.is_empty(), "reopen masked and empty")
	for safe in [Rect2(44, 24, 720, 312), Rect2(80, 28, 640, 220)]:
		scene._layout_modal(safe)
		await process_frame
		await process_frame
		check(safe.encloses(scene.modal_panel.get_rect()), "panel fits simulated cutout and keyboard safe region")
		scene.fields[2].grab_focus()
		scene._keep_focused_field_visible()
		await process_frame
		await process_frame
		await process_frame
		check(scene.modal_scroll.get_global_rect().encloses(scene.fields[2].get_global_rect()), "focused confirmation visible after keyboard reflow")
		check(scene.modal_scroll.size.y > 0, "scroll remains usable with keyboard")
		check(scene.modal_scroll.get_v_scroll_bar().max_value > scene.modal_scroll.size.y, "short landscape content scrolls")
		check(scene.modal_panel.get_global_rect().encloses(scene.modal_close.get_global_rect()), "close stays reachable without scrolling")
	scene.close_modal()
	for document_kind in ["privacy", "terms"]:
		scene.open_modal("create")
		scene.fields[1].text = "dummy-secret"
		var old_password = scene.fields[1]
		scene._open_legal_document(document_kind)
		check(old_password.text.is_empty(), "opening document immediately clears password")
		check(scene.modal_kind == document_kind and scene.fields.is_empty(), "document reader replaces form")
		await process_frame
		check(scene.notice.text.contains("No account or agreement"), "reader does not imply agreement")
		scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(scene.modal_kind == "create", "Android back returns from document to create")
		check(scene.fields[1].text.is_empty() and scene.fields[1].secret, "returned form is empty and masked")
		scene._open_legal_document(document_kind)
		scene.modal_close.pressed.emit()
		check(scene.modal_kind == "create", "document close returns to account panel")
		scene.close_modal()
		await process_frame
	scene.open_modal("create")
	scene.fields[0].text = "hero@example.com"
	scene.fields[1].text = "dummy-password"
	scene.fields[2].text = "dummy-password"
	scene._submit_preview()
	check(scene.modal_kind == "create", "valid preview does not fake registration or navigate")
	scene.fields[1].text = "dummy-password"
	scene.fields[2].text = "dummy-password"
	var old_secret = scene.fields[1]
	scene._on_registration_succeeded("hero@example.com")
	check(old_secret.text.is_empty(), "real-success callback clears original passwords")
	check(scene.modal_kind == "signin", "real-success callback returns to sign in")
	check(scene.fields[0].text == "hero@example.com" and scene.fields[1].text.is_empty(), "only email carried into sign in")
	check(root.gui_get_focus_owner() == scene.fields[1], "sign-in password focused after real success")
	scene.close_modal()
	scene._on_registration_succeeded("late@example.com")
	check(scene.modal == null, "late callback cannot reopen dismissed modal")
	scene.open_modal("signin")
	await process_frame
	await process_frame
	check(scene.modal_box.size.y <= scene.modal_scroll.size.y, "sign-in panel compact content fits")
	scene.fields[0].text = "hero@example.com"
	scene._submit_preview()
	check("Enter a dummy password" in scene.notice.text, "sign-in requires password without applying signup length policy")
	scene.fields[1].text = "dummy"
	var sign_in_secret = scene.fields[1]
	scene._switch_account_modal("create")
	check(sign_in_secret.text.is_empty() and scene.modal_kind == "create", "sign in links to clean create panel")
	scene.close_modal()
	for document_kind in ["privacy", "terms"]:
		scene.open_modal("signin")
		check(scene.legal_controls.size() == 2, "sign-in includes both document links")
		scene.fields[1].text = "dummy-secret"
		var secret_before_doc = scene.fields[1]
		scene._open_legal_document(document_kind)
		check(secret_before_doc.text.is_empty(), "sign-in document navigation clears password")
		scene._back_from_modal()
		check(scene.modal_kind == "signin" and scene.fields[1].text.is_empty(), "document returns to clean originating sign in")
		scene.close_modal()
	scene.open_modal("create")
	for target_kind in ["signin", "create", "signin", "create"]:
		scene.fields[0].text = "hero@example.com"
		scene.fields[1].text = "dummy-secret"
		scene.password_toggles[0].button_pressed = true
		var previous_password = scene.fields[1]
		scene._switch_account_modal(target_kind)
		check(previous_password.text.is_empty(), "reciprocal switch clears old secret")
		check(scene.modal_kind == target_kind and scene.fields[0].text == "hero@example.com", "reciprocal switch retains only email")
		check(scene.fields[1].text.is_empty() and scene.fields[1].secret, "reciprocal switch resets password visibility")
		await process_frame
	scene.close_modal()
	scene.open_modal("signin")
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.modal == null, "Android back dismisses")
	scene.open_modal("create")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._unhandled_key_input(escape)
	check(scene.modal == null, "Escape dismisses")
	for viewport_size in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1024,768)]:
		root.size = viewport_size
		await process_frame
		scene._layout()
		check(scene.brand.position.x >= 0, "brand fits screen")
		for button in scene.buttons:
			check(scene.get_global_rect().encloses(button.get_global_rect()), "button fits responsive viewport")
		scene.open_modal("create")
		await process_frame
		check(scene.get_global_rect().encloses(scene.modal_panel.get_global_rect()), "modal fits viewport")
		scene.close_modal()
	root.size = Vector2i(1280,720)
	await process_frame
	scene._layout()
	# Dispatch real pointer events through Godot's GUI, not button signals.
	for index in range(4):
		var point: Vector2 = scene.buttons[index].get_global_rect().get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = point
		press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = point
		release.pressed = false
		Input.parse_input_event(release)
		await process_frame
		check(scene.modal != null, "pointer button opens modal")
		scene.close_modal()
		await process_frame
	scene.buttons[3].grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	enter = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = false
	Input.parse_input_event(enter)
	await process_frame
	check(scene.modal_kind == "signin", "keyboard Enter activates sign in")
	scene.close_modal()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = scene.buttons[1].get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var lift := InputEventScreenTouch.new()
	lift.index = 0
	lift.position = touch.position
	lift.pressed = false
	Input.parse_input_event(lift)
	await process_frame
	check(scene.modal_kind == "guest", "touch opens Guest")
	scene.close_modal()
	check(scene.runners.size() == 2, "two separate runners")
	for runner in scene.runners:
		check(runner.sprite_frames.get_frame_count("default") == 4, "four distinct sprite atlas frames")
		check(runner.is_playing(), "runner animation playing")
		check(runner.offset == Vector2(-256,-430), "registered foot pivot")
	scene.elapsed = 0
	scene._process(0)
	check(scene.runners[1].position.x > scene.runners[0].position.x, "goblin leads sword skeleton")
	check(not FileAccess.file_exists("user://account.json"), "no account persistence")
	print("TITLE CHECKS: ",checks,"; failures: ",failures)
	if failures == 0:
		print("ADVENTURE ODYSSEY TITLE TEST: PASS")
	quit(0 if failures == 0 else 1)
