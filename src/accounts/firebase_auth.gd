extends Node
# Firebase public-client REST adapter. No passwords/tokens are written to disk.
# This component never reads, uploads, changes or associates the guest save.
signal completed(operation: String, ok: bool, message: String)
signal session_changed
const PROJECT_ID := "adventure-odyssey-2aadf"
const IDENTITY_URL := "https://identitytoolkit.googleapis.com/v1/"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const MAX_RESPONSE := 65536
var api_key := ""
var busy := false
var operation := ""
var user_id := ""
var email := ""
var email_verified := false
var _id_token := ""
var _refresh_token := ""
var _expires_at := 0
var _generation := 0
var _http: HTTPRequest

func configured() -> bool:
 if not api_key.begins_with("AIza") or api_key.length() != 39: return false
 for letter in api_key:
  if not letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-": return false
 return true

func signed_in() -> bool:
 return not user_id.is_empty() and not _id_token.is_empty() and Time.get_unix_time_from_system() < _expires_at

func sign_in(address: String, password: String) -> bool:
 return _start("signin", "accounts:signInWithPassword", {"email":address.strip_edges(), "password":password, "returnSecureToken":true})

func create_account(address: String, password: String) -> bool:
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

func sign_out() -> void:
 cancel()
 _clear_session()
 session_changed.emit()

func cancel() -> void:
 _generation += 1
 if is_instance_valid(_http):
  _http.cancel_request()
  _http.queue_free()
 _http = null
 busy = false
 operation = ""

func _clear_session() -> void:
 user_id = ""
 email = ""
 email_verified = false
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
 var headers := PackedStringArray(["Content-Type: application/json"])
 var body := JSON.stringify(data)
 if op == "refresh":
  url = TOKEN_URL + "?key=" + api_key.uri_encode()
  headers = PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
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
 var parsed = JSON.parse_string(body.get_string_from_utf8())
 if not parsed is Dictionary:
  _reject(op, "The account service returned an unexpected response.")
  return
 if code < 200 or code >= 300:
  var failure := str(parsed.get("error", {}).get("message", "")) if parsed.get("error", {}) is Dictionary else ""
  if op == "reset" and failure in ["EMAIL_NOT_FOUND", "USER_NOT_FOUND"]:
   completed.emit(op, true, "If an account exists for that email, a reset link has been requested. Check your inbox and spam folder.")
   return
  if op in ["refresh", "lookup"] and failure in ["INVALID_REFRESH_TOKEN", "TOKEN_EXPIRED", "USER_DISABLED", "USER_NOT_FOUND", "INVALID_ID_TOKEN", "PROJECT_NUMBER_MISMATCH"]:
   _clear_session()
   session_changed.emit()
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
  if uid.is_empty() or token.is_empty() or refresh.is_empty() or duration <= 0 or duration > 86400 or (op == "refresh" and uid != user_id):
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
  session_changed.emit()
  completed.emit(op, true, "Account created. Verify your email before using online features." if op == "create" else "Signed in. Your adventure remains saved on this device.")
 elif op == "lookup":
  var users = parsed.get("users", [])
  if not users is Array or users.size() != 1 or not users[0] is Dictionary or str(users[0].get("localId", "")) != user_id:
   _reject(op, "Could not verify the current account.")
   return
  email_verified = users[0].get("emailVerified", false) == true
  email = str(users[0].get("email", email))
  session_changed.emit()
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
