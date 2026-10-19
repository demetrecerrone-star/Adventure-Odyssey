extends SceneTree
const Main = preload("res://src/main.gd")
const Auth = preload("res://src/accounts/firebase_auth.gd")
class MemoryStore extends RefCounted:
 var record := {}
 var fail_clear := false
 func available(): return true
 func clear():
  if fail_clear: return false
  record.clear()
  return true
 func read(): return {"ok":true,"record":record}
 func write(value):
  record=value.duplicate()
  return true
class MockAuth extends Auth:
 var requests: Array = []
 func configured() -> bool: return true
 func _start(op: String, endpoint: String, _data: Dictionary) -> bool:
  if busy: return false
  requests.append([op, endpoint]) # Never retain passwords, even in the fixture.
  busy = true
  operation = op
  _generation += 1
  return true
 func respond(op: String, data: Dictionary) -> void:
  _response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(data).to_utf8_buffer(), _generation, op)
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size = Vector2i(844, 390)
 root.content_scale_size = Vector2i(844, 390)
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.accounts.queue_free()
 var auth = MockAuth.new()
 auth.session_store = MemoryStore.new()
 scene.accounts = auth
 scene.add_child(auth)
 auth.completed.connect(scene._account_completed)
 auth.session_changed.connect(scene._account_session_changed)
 await capture("account_title_phone")
 var guest := "user://bedroom_guest_v1.json"
 var made_fixture := not FileAccess.file_exists(guest)
 if made_fixture:
  var save = preload("res://src/bedroom_save.gd").new()
  save.path=guest
  var draft = preload("res://src/creator/character_draft.gd").new()
  draft.set_base("female")
  draft.character_class="Necromancer"
  draft.username="AccountTester"
  check(save.create(draft.payload()),"create valid nonempty guest fixture")
  var weapon: String = save.Inventory.starter_weapon("Necromancer")
  check(save.transfer(weapon,false) and save.equip(weapon),"guest fixture has equipped item before auth")
 var existing := FileAccess.get_file_as_bytes(guest)
 for kind in ["signin", "create", "reset"]:
  scene.open_modal(kind)
  await process_frame
  await capture("account_" + kind + "_phone")
  if kind in ["signin","create"]:
   check(not scene.remember_login.button_pressed and not scene.remember_login.disabled,"secure opt-in defaults off")
   if kind=="signin":
    scene.modal_scroll.ensure_control_visible(scene.remember_login)
    await capture("account_remember_phone")
    scene.modal_scroll.scroll_vertical=0
  check(scene.fields.size() == (3 if kind == "create" else 2 if kind == "signin" else 1), "correct account field count")
  scene.fields[0].text = "fixture@example.com"
  for i in range(1, scene.fields.size()): scene.fields[i].text = "fixture-only"
  scene._submit_preview()
  check(auth.busy and scene.account_submit.disabled, "in-flight submit disabled")
  for i in range(1, scene.fields.size()): check(scene.fields[i].text.is_empty(), "password clears on dispatch")
  var count = auth.requests.size()
  scene._submit_preview()
  check(auth.requests.size() == count, "duplicate submit makes no request")
  var ticket = auth._generation
  scene.close_modal()
  check(not auth.busy, "close cancels request")
  auth._response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{}'.to_utf8_buffer(), ticket, kind)
  check(scene.modal == null and not auth.signed_in(), "late response cannot reopen or authenticate")
 for kind in ["privacy", "terms"]:
  scene.open_modal(kind)
  check("Draft for review" in scene.notice.text, "configured account documents are marked for review")
  check("Firebase" in all_label_text(scene.modal) if kind == "privacy" else "preview feature notes" in all_label_text(scene.modal), "configured notice reflects actual account behavior")
  scene.close_modal()
 scene.open_modal("google")
 check("Use email sign-in" in scene.notice.text and "sends no data" in scene.notice.text, "Google unavailable notice is accurate for enabled email client")
 scene.close_modal()
 scene.open_modal("signin")
 scene.fields[0].text = "fixture@example.com"
 scene.fields[1].text = "fixture-only"
 scene.remember_login.button_pressed = true
 scene._submit_preview()
 auth.respond("signin", {"localId":"fixture-user", "email":"fixture@example.com", "idToken":"fixture-token", "refreshToken":"fixture-refresh", "expiresIn":"3600"})
 await capture("account_signed_in_phone")
 check(scene.modal_kind == "account" and auth.signed_in(), "real-response hook displays account")
 check("No cloud backup" in scene.notice.text, "honest local progress disclosure")
 check("has not been checked yet" in scene.notice.text and not "Email not verified yet" in scene.notice.text, "fresh sign-in describes unknown verification truthfully")
 check(scene.buttons[3].text == "Your Account", "signed title account entry")
 scene._account_completed("lookup",false,"Could not check verification while offline.")
 check("fixture@example.com" in scene.notice.text and "has not been checked yet" in scene.notice.text and "offline" in scene.notice.text,"offline verification preserves identity and unknown state")
 var identity_notice: String = scene.notice.text
 scene._account_completed("refresh", true, "Signed in.")
 check(scene.notice.text == identity_notice, "background refresh preserves account identity notice")
 scene._account_completed("refresh", false, "Connection interrupted.")
 check(scene.notice.text == identity_notice, "background refresh failure preserves current account notice")
 await process_frame
 await process_frame
 check(scene.modal_scroll.scroll_vertical == 0, "account starts at identity and disclosure")
 check(auth.requests[-1][0] == "lookup", "verification lookup starts automatically after login")
 auth.respond("lookup", {"users":[{"localId":"fixture-user", "email":"fixture@example.com", "emailVerified":false}]})
 check("Email not verified yet" in scene.notice.text and auth.verification_checked, "lookup distinguishes actual unverified state")
 auth.check_account()
 auth.respond("lookup", {"users":[{"localId":"fixture-user", "email":"fixture@example.com", "emailVerified":true}]})
 check(not "Send verification email" in button_texts(scene.modal), "verified UI removes verification action")
 check("Email verified." in scene.notice.text, "verified account rebuilt")
 await capture("account_verified_phone")
 scene.close_modal()
 scene.open_modal("privacy")
 scene._account_completed("lookup", true, "Email verified.")
 check(scene.modal_kind=="privacy","background verification cannot interrupt a different modal")
 scene.close_modal()
 scene.open_modal("account")
 auth._expires_at = int(Time.get_unix_time_from_system()) - 1
 auth._process(0.0)
 check(scene.modal_kind == "signin" and scene.buttons[3].text == "Sign In", "expiry updates open modal and title")
 scene.fields[0].text = "fixture@example.com"
 scene.fields[1].text = "fixture-only"
 scene._submit_preview()
 auth.respond("signin", {"localId":"fixture-user", "email":"fixture@example.com", "idToken":"fixture-token", "refreshToken":"fixture-refresh", "expiresIn":"3600"})
 scene.close_modal()
 scene.open_modal("signin")
 check(scene.modal_kind == "account", "signed entry resumes account")
 auth.sign_out()
 scene.close_modal()
 check(scene.buttons[3].text == "Sign In" and not auth.signed_in(), "logout clears UI identity")
 var after := FileAccess.get_file_as_bytes(guest) if FileAccess.file_exists(guest) else PackedByteArray()
 check(after == existing, "auth flows do not alter guest save bytes")
 if made_fixture:
  var reloaded = preload("res://src/bedroom_save.gd").new()
  reloaded.path=guest
  check(reloaded.load_saved() and not reloaded.equipped_weapon.is_empty(),"valid equipped guest reloads after auth flows")
  DirAccess.remove_absolute(guest)
 scene.queue_free()
 await process_frame
 print("FIREBASE ACCOUNT UI: %d checks; failures: %d" % [checks, failures])
 quit(1 if failures else 0)

func capture(name: String) -> void:
 if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var dir := OS.get_environment("AO_CAPTURE_DIR")
 if dir.is_empty(): dir = "res://screenshots"
 var result := root.get_texture().get_image().save_png(dir.path_join(name + ".png"))
 check(result == OK, "native account capture")

func button_texts(node: Node) -> Array:
 var result: Array = []
 if node is Button: result.append(node.text)
 for child in node.get_children(): result.append_array(button_texts(child))
 return result

func all_label_text(node: Node) -> String:
 var result: String = node.text if node is Label else ""
 for child in node.get_children(): result += all_label_text(child)
 return result
