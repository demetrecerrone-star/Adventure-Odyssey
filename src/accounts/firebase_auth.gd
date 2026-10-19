extends Node
# Firebase public-client REST adapter. Optional encrypted refresh-token storage.
# Passwords and ID tokens are never persisted.
# This component never reads, uploads, changes or associates the guest save.
signal completed(operation: String, ok: bool, message: String)
signal session_changed
const SessionStore = preload("res://src/accounts/android_session_store.gd")
const PROJECT_ID := "adventure-odyssey-2aadf"
const IDENTITY_URL := "https://identitytoolkit.googleapis.com/v1/"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const MAX_RESPONSE := 65536
const ANDROID_PACKAGE := "com.demetrecerrone.adventureodyssey"
const RELEASE_CERT_SHA1 := "72C3D1BA6AF92423526F34B86A4F51898D135449"
var api_key := ""
var busy := false
var operation := ""
var user_id := ""
var email := ""
var email_verified := false
var verification_checked := false
var _id_token := ""
var _refresh_token := ""
var _expires_at := 0
var _generation := 0
var _was_signed_in := false
var _next_refresh_ms := 0
var _http: HTTPRequest
var session_store = SessionStore.new()
var remembered := false
var persistence_notice := ""
var _remember_requested := false
var _restoring := false

func remember_available() -> bool:
 return session_store != null and session_store.available()

func _forget_saved() -> bool:
 if not remember_available():
  if remembered or OS.has_feature("android"):
   persistence_notice = "Saved-login storage is unavailable. Removal could not be verified; do not share this device until it can be cleared."
   return false
  return true
 if not session_store.clear():
  persistence_notice = "Could not remove the saved login. Retry signing out before sharing this device."
  return false
 remembered = false
 _remember_requested = false
 persistence_notice = ""
 return true

func forget_saved_login() -> bool:
 cancel()
 var ok := _forget_saved()
 _emit_session()
 return ok

func restore_saved_login() -> bool:
 if busy or signed_in() or not configured() or not remember_available(): return false
 var saved: Dictionary = session_store.read()
 if not saved.get("ok", false):
  persistence_notice = "Saved login could not be opened. Sign out to remove it, or sign in again."
  return _reject("restore", persistence_notice)
 var record: Dictionary = saved.get("record", {})
 if record.is_empty(): return false
 if not SessionStore.valid_record(record): return _reject("restore", "Saved login is invalid. Sign out to remove it.")
 _clear_session()
 user_id = record.uid
 _refresh_token = record.refresh_token
 remembered = true
 _remember_requested = true
 _restoring = true
 persistence_notice = "Checking saved login…"
 return refresh_session()

func _prepare_login(remember: bool) -> bool:
 if busy: return false
 if remember and not remember_available(): return _reject("signin", "Secure Remember me is unavailable on this device.")
 if not _forget_saved(): return _reject("signin", persistence_notice)
 _clear_session()
 _restoring = false
 _next_refresh_ms = 0
 _remember_requested = remember
 return true

func _save_session() -> bool:
 if not _remember_requested: return true
 if session_store.write({"project":PROJECT_ID, "uid":user_id, "refresh_token":_refresh_token}):
  remembered = true
  persistence_notice = "Remember me is on for this device."
  return true
 # Never retain a stale durable token after rotation or a failed replacement.
 var cleared := _forget_saved()
 _remember_requested = false
 persistence_notice = "Signed in for this session only; secure login could not be saved." if cleared else "Signed in, but saved-login storage failed. Retry signing out before sharing this device."
 return false

func configured() -> bool:
 if not api_key.begins_with("AIza") or api_key.length() != 39: return false
 for letter in api_key:
  if not letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-": return false
 return true

func signed_in() -> bool:
 return not user_id.is_empty() and not _id_token.is_empty() and Time.get_unix_time_from_system() < _expires_at

func sign_in(address: String, password: String, remember: bool = false) -> bool:
 if not _prepare_login(remember): return false
 return _start("signin", "accounts:signInWithPassword", {"email":address.strip_edges(), "password":password, "returnSecureToken":true})

func create_account(address: String, password: String, remember: bool = false) -> bool:
 if not _prepare_login(remember): return false
 return _start("create", "accounts:signUp", {"email":address.strip_edges(), "password":password, "returnSecureToken":true})

func reset_password(address: String) -> bool:
 return _start("reset", "accounts:sendOobCode", {"email":address.strip_edges(), "requestType":"PASSWORD_RESET"})

func send_verification() -> bool:
 if not signed_in(): return _reject("verify", "Sign in again before requesting verification.")
 return _start("verify", "accounts:sendOobCode", {"idToken":_id_token, "requestType":"VERIFY_EMAIL"})

func check_account() -> bool:
 if not signed_in(): return _reject("lookup", "Sign in again to check your account.")
 return _start("lookup", "accounts:lookup", {"idToken":_id_token})

func refresh_session() -> bool:
 if _refresh_token.is_empty(): return _reject("refresh", "Sign in again to continue.")
 return _start("refresh", "", {"grant_type":"refresh_token", "refresh_token":_refresh_token})

func sign_out() -> bool:
 cancel()
 _clear_session()
 var forgotten := _forget_saved()
 _emit_session()
 return forgotten

func cancel() -> void:
 if _restoring:
  _restoring = false
  _clear_session()
 _generation += 1
 if is_instance_valid(_http):
  _http.cancel_request()
  _http.queue_free()
 _http = null
 busy = false
 operation = ""

func _clear_session() -> void:
 _was_signed_in = false
 user_id = ""
 email = ""
 email_verified = false
 verification_checked = false
 _id_token = ""
 _refresh_token = ""
 _expires_at = 0

func _reject(op: String, message: String) -> bool:
 completed.emit(op, false, message)
 return false

func _start(op: String, endpoint: String, data: Dictionary) -> bool:
 if busy: return false
 if not configured(): return _reject(op, "Account connection is not configured. You can still play as Guest.")
 if op in ["signin", "create", "reset"]:
  var address := str(data.get("email", ""))
  if address.length() > 254 or not "@" in address or " " in address or "\n" in address:
   return _reject(op, "Enter a valid email address.")
 if op in ["signin", "create"] and str(data.get("password", "")).is_empty():
  return _reject(op, "Enter your password.")
 busy = true
 operation = op
 _generation += 1
 var ticket := _generation
 _http = HTTPRequest.new()
 _http.timeout = 20
 _http.body_size_limit = MAX_RESPONSE
 _http.max_redirects = 0 # Credentials must never follow a cross-origin redirect.
 add_child(_http)
 _http.request_completed.connect(_response.bind(ticket, op))
 var url := IDENTITY_URL + endpoint + "?key=" + api_key.uri_encode()
 var headers := request_headers("application/json")
 var body := JSON.stringify(data)
 if op == "refresh":
  url = TOKEN_URL + "?key=" + api_key.uri_encode()
  headers = request_headers("application/x-www-form-urlencoded")
  body = "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode()
 var result := _http.request(url, headers, HTTPClient.METHOD_POST, body)
 # HTTPRequest owns the temporary request body; no retry queue or logging.
 if result != OK:
  cancel()
  return _reject(op, "Could not connect. Your local adventure is still available.")
 return true

func _response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, ticket: int, op: String) -> void:
 if ticket != _generation or not busy or operation != op: return
 if is_instance_valid(_http): _http.queue_free()
 _http = null
 busy = false
 operation = ""
 if result != HTTPRequest.RESULT_SUCCESS or body.size() > MAX_RESPONSE:
  _reject(op, "Connection interrupted. Try again when you are online.")
  return
 var parser := JSON.new()
 var parse_result := parser.parse(body.get_string_from_utf8())
 var parsed = parser.data
 if parse_result != OK or not parsed is Dictionary:
  _reject(op, "The account service returned an unexpected response.")
  return
 if code < 200 or code >= 300:
  var failure := str(parsed.get("error", {}).get("message", "")) if parsed.get("error", {}) is Dictionary else ""
  if op == "reset" and failure in ["EMAIL_NOT_FOUND", "USER_NOT_FOUND"]:
   completed.emit(op, true, "If an account exists for that email, a reset link has been requested. Check your inbox and spam folder.")
   return
  if op in ["refresh", "lookup"] and failure in ["INVALID_REFRESH_TOKEN", "TOKEN_EXPIRED", "USER_DISABLED", "USER_NOT_FOUND", "INVALID_ID_TOKEN", "PROJECT_NUMBER_MISMATCH"]:
   _clear_session()
   _restoring = false
   _forget_saved()
   _emit_session()
  _reject(op, _safe_error(failure))
  return
 if op in ["signin", "create", "refresh"]:
  for field in (["user_id", "id_token", "refresh_token", "expires_in"] if op == "refresh" else ["localId", "idToken", "refreshToken", "expiresIn", "email"]):
   if not parsed.get(field) is String:
    _reject(op, "The account service returned an incomplete session. Please sign in again.")
    return
  var uid := str(parsed.get("user_id" if op == "refresh" else "localId", ""))
  var token := str(parsed.get("id_token" if op == "refresh" else "idToken", ""))
  var refresh := str(parsed.get("refresh_token" if op == "refresh" else "refreshToken", ""))
  var duration := int(str(parsed.get("expires_in" if op == "refresh" else "expiresIn", "0")))
  if uid.is_empty() or token.is_empty() or refresh.is_empty() or duration <= 30 or duration > 86400 or (op == "refresh" and uid != user_id):
   if op == "refresh":
    _clear_session()
    _restoring = false
    _forget_saved()
    _emit_session()
   _reject(op, "The account service returned an incomplete session. Please sign in again.")
   return
  # Firebase validates refresh-token project number against the API key.
  # Its project_id response is numeric, not the human-readable project ID.
  user_id = uid
  _id_token = token
  _refresh_token = refresh
  _expires_at = int(Time.get_unix_time_from_system()) + duration - 30
  if op != "refresh":
   email = str(parsed.get("email", ""))
   email_verified = false # Only accounts:lookup establishes verification.
   verification_checked = false
  var restored := _restoring
  _restoring = false
  _save_session()
  _emit_session()
  if restored:
   completed.emit("restore", true, "Saved login checked. Your adventure remains on this device.")
   _queue_verification()
   return
  completed.emit(op, true, "Account created. Verify your email before using online features." if op == "create" else "Signed in. Your adventure remains saved on this device.")
  _queue_verification()
 elif op == "lookup":
  var users = parsed.get("users", [])
  if not users is Array or users.size() != 1 or not users[0] is Dictionary or str(users[0].get("localId", "")) != user_id:
   _reject(op, "Could not verify the current account.")
   return
  if not users[0].get("emailVerified") is bool:
   _reject(op, "Verification status is unavailable. Try checking again when online.")
   return
  email_verified = users[0].emailVerified
  verification_checked = true
  email = str(users[0].get("email", email))
  _emit_session()
  completed.emit(op, true, "Email verified." if email_verified else "Email is not verified yet. Check your inbox.")
 elif op == "reset":
  completed.emit(op, true, "If an account exists for that email, a reset link has been requested. Check your inbox and spam folder.")
 else:
  completed.emit(op, true, "Verification email requested. Check your inbox and spam folder.")

func _safe_error(failure: String) -> String:
 if failure in ["INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "USER_DISABLED"]:
  return "Could not sign in with those details. Check them or request a password reset."
 if failure == "EMAIL_EXISTS": return "An account may already use that email. Try signing in or resetting your password."
 if failure.begins_with("WEAK_PASSWORD") or failure == "PASSWORD_DOES_NOT_MEET_REQUIREMENTS": return "Choose a stronger password that meets the account service requirements."
 if failure in ["TOO_MANY_ATTEMPTS_TRY_LATER", "QUOTA_EXCEEDED"]: return "Too many requests. Please wait before trying again."
 if failure == "INVALID_EMAIL": return "Enter a valid email address."
 return "Account request could not be completed. Please try again later."

func _emit_session() -> void:
 _was_signed_in = signed_in()
 session_changed.emit()

func _process(_delta: float) -> void:
 if _was_signed_in and not signed_in():
  cancel()
  _clear_session()
  _emit_session()
  return
 if signed_in() and configured() and not busy and not _refresh_token.is_empty() and _expires_at - Time.get_unix_time_from_system() < 60 and Time.get_ticks_msec() >= _next_refresh_ms:
  _next_refresh_ms = Time.get_ticks_msec() + 60000
  refresh_session()

func request_headers(content_type: String) -> PackedStringArray:
 # Public Android identity headers support app-restricted Firebase keys.
 # These headers are not attestation or a substitute for backend authorization.
 return PackedStringArray(["Content-Type: " + content_type, "X-Android-Package: " + ANDROID_PACKAGE, "X-Android-Cert: " + RELEASE_CERT_SHA1])

func _queue_verification() -> void:
 # Queue after UI success handlers, which may close the old form and cancel it.
 # Later user cancellation/signout must invalidate this queued request too.
 if configured(): _hydrate_verification.call_deferred(_generation, user_id)

func _hydrate_verification(ticket: int, expected_uid: String) -> void:
 if ticket != _generation or expected_uid != user_id or busy or not signed_in(): return
 check_account()
