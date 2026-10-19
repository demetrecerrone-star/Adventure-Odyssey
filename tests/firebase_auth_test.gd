extends SceneTree
const Auth = preload("res://src/accounts/firebase_auth.gd")
var checks := 0
var failures := 0
var events: Array = []
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)
func respond(auth, op: String, code: int, data, result: int = HTTPRequest.RESULT_SUCCESS) -> void:
 auth.busy = true
 auth.operation = op
 auth._generation += 1
 auth._response(result, code, PackedStringArray(), JSON.stringify(data).to_utf8_buffer(), auth._generation, op)
func _initialize() -> void:
 var a = Auth.new()
 root.add_child(a)
 a.completed.connect(func(op, ok, message): events.append([op, ok, message]))
 check(not a.configured(), "unconfigured by default")
 check("X-Android-Package: com.demetrecerrone.adventureodyssey" in a.request_headers("application/json"), "correct public Android package header")
 check("X-Android-Cert: 72C3D1BA6AF92423526F34B86A4F51898D135449" in a.request_headers("application/json"), "verified permanent certificate header")
 check(not a.sign_in("test@example.com", "not-real"), "disabled client makes no request")
 check(a._http == null and not a.signed_in(), "no offline fake login")
 for key in ["AIza" + "a".repeat(35), "AIza" + "-".repeat(35), "AIza" + "_".repeat(35)]:
  a.api_key = key
  check(a.configured(), "public key allowed characters")
 a.api_key = "AIza" + "?".repeat(35)
 check(not a.configured(), "query injection forbidden")
 a.api_key = ""
 var session := {"localId":"uid-one", "idToken":"dummy-token", "refreshToken":"dummy-refresh", "expiresIn":"3600", "email":"test@example.com"}
 respond(a, "signin", 200, session)
 check(a.signed_in() and a.user_id == "uid-one", "server session installed")
 check(not a.email_verified and not a.verification_checked, "verification starts unknown after sign-in")
 respond(a, "lookup", 200, {"users":[{"localId":"uid-other", "emailVerified":true}]})
 check(not a.email_verified, "other identity cannot verify session")
 respond(a, "lookup", 200, {"users":[{"localId":"uid-one", "emailVerified":false}]})
 check(a.verification_checked and not a.email_verified, "server-confirmed unverified differs from unchecked")
 respond(a, "lookup", 200, {"users":[{"localId":"uid-one", "emailVerified":true}]})
 check(a.email_verified and a.verification_checked, "server lookup verifies email")
 respond(a, "refresh", 200, {"user_id":"uid-one", "id_token":"refreshed-token", "refresh_token":"refreshed-token-two", "expires_in":"3600"})
 check(a.email_verified and a.verification_checked, "same-user refresh preserves verified lookup status")
 var ticket = a._generation
 a.sign_out()
 a._response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(session).to_utf8_buffer(), ticket, "signin")
 check(not a.signed_in() and a._refresh_token.is_empty() and not a.verification_checked, "logout clears verification state and blocks stale callbacks")
 respond(a, "signin", 200, {"localId":"incomplete"})
 check(not a.signed_in(), "incomplete success never authenticates")
 respond(a, "signin", 200, session)
 respond(a, "refresh", 200, {"user_id":"uid-one", "id_token":"next-token", "refresh_token":"next-refresh", "expires_in":"3600", "project_id":Auth.PROJECT_ID})
 check(a.signed_in() and a._id_token == "next-token", "refresh rotates session")
 respond(a, "refresh", 400, {"error":{"message":"PROJECT_NUMBER_MISMATCH"}})
 check(not a.signed_in(), "wrong project clears session")
 respond(a, "signin", 200, session)
 respond(a, "refresh", 400, {"error":{"message":"INVALID_REFRESH_TOKEN"}})
 check(not a.signed_in(), "revoked session clears identity")
 for code in ["EMAIL_NOT_FOUND", "USER_NOT_FOUND"]:
  respond(a, "reset", 400, {"error":{"message":code}})
  check(events[-1][1] and "If an account exists" in events[-1][2], "recovery does not expose account existence")
 for error in ["INVALID_LOGIN_CREDENTIALS", "USER_DISABLED", "SECRET_RAW_SERVER_ERROR", "WEAK_PASSWORD : secret"]:
  respond(a, "signin", 400, {"error":{"message":error}})
  check(not events[-1][1] and not error in events[-1][2], "raw errors never exposed")
 respond(a, "signin", 200, session, HTTPRequest.RESULT_CANT_CONNECT)
 check(not a.signed_in(), "connection failure is not success")
 var short_session := session.duplicate()
 short_session.expiresIn = "1"
 respond(a, "signin", 200, short_session)
 check(not events[-1][1] and not a.signed_in(), "already-expiring session rejected")
 a.busy = true
 a.operation = "signin"
 a._generation += 1
 a._response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{"secret-response-marker":'.to_utf8_buffer(), a._generation, "signin")
 check(not events[-1][1] and not "secret-response-marker" in events[-1][2], "malformed response sanitized without raw parser logging")
 respond(a, "signin", 200, session)
 a._expires_at = int(Time.get_unix_time_from_system()) - 1
 a._process(0.0)
 check(a.user_id.is_empty() and a._refresh_token.is_empty(), "expired session clears identity and tokens")
 respond(a, "signin", 200, session)
 respond(a, "refresh", 200, {"user_id":"other-user", "id_token":"other-token", "refresh_token":"other-refresh", "expires_in":"3600", "project_id":"123"})
 check(not a.signed_in(), "mismatched refresh invalidates old session")
 a.busy = true
 check(not a.create_account("test@example.com", "not-real"), "duplicate request ignored")
 a.sign_out()
 check(not a.busy and a.operation.is_empty() and a.email.is_empty(), "logout resets request and personal state")
 a.queue_free()
 print("FIREBASE AUTH: %d checks; failures: %d" % [checks, failures])
 quit(1 if failures else 0)
