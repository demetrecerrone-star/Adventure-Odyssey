extends SceneTree
const Main = preload("res://src/main.gd")
const Auth = preload("res://src/accounts/firebase_auth.gd")
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
 scene.accounts = auth
 scene.add_child(auth)
 auth.completed.connect(scene._account_completed)
 auth.session_changed.connect(scene._account_session_changed)
 var guest := "user://bedroom_guest_v1.json"
 var existing := FileAccess.get_file_as_bytes(guest) if FileAccess.file_exists(guest) else PackedByteArray()
 for kind in ["signin", "create", "reset"]:
  scene.open_modal(kind)
  await process_frame
  await capture("account_" + kind + "_phone")
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
 scene.open_modal("signin")
 scene.fields[0].text = "fixture@example.com"
 scene.fields[1].text = "fixture-only"
 scene._submit_preview()
 auth.respond("signin", {"localId":"fixture-user", "email":"fixture@example.com", "idToken":"fixture-token", "refreshToken":"fixture-refresh", "expiresIn":"3600"})
 await capture("account_signed_in_phone")
 check(scene.modal_kind == "account" and auth.signed_in(), "real-response hook displays account")
 check("No cloud backup" in scene.notice.text, "honest local progress disclosure")
 check(scene.buttons[3].text == "Your Account", "signed title account entry")
 scene.close_modal()
 scene.open_modal("signin")
 check(scene.modal_kind == "account", "signed entry resumes account")
 auth.sign_out()
 scene.close_modal()
 check(scene.buttons[3].text == "Sign In" and not auth.signed_in(), "logout clears UI identity")
 var after := FileAccess.get_file_as_bytes(guest) if FileAccess.file_exists(guest) else PackedByteArray()
 check(after == existing, "auth flows do not alter guest save bytes")
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
