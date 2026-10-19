extends SceneTree
const Auth = preload("res://src/accounts/firebase_auth.gd")
const Store = preload("res://src/accounts/android_session_store.gd")
class MemoryStore:
 extends RefCounted
 var record := {}
 var fail_write := false
 var fail_clear := false
 var fail_read := false
 var writes := 0
 func available(): return true
 func read(): return {"ok":not fail_read,"record":record.duplicate()}
 func write(value):
  writes += 1
  if fail_write: return false
  record = value.duplicate()
  return true
 func clear():
  if fail_clear: return false
  record.clear()
  return true
class ProbeStore:
 extends Store
 var files := {}
 var reads := 0
 func _initialize():
  _file=RefCounted.new(); _atomic=RefCounted.new()
  _classes={"file":RefCounted.new()}
  return true
 func _java(_target: Object, method: String, args: Array=[]):
  match method:
   "getAbsolutePath": return "fixture"
   "File":
    var file=RefCounted.new()
    file.set_meta("path",args[0])
    return file
   "exists": return files.has(_target.get_meta("path","fixture"))
   "length": return files.get(_target.get_meta("path","fixture"),0)
   "readFully":
    reads+=1
    return PackedByteArray() # Deliberately invalid; no mock crypto claim.
  return null
class MockAuth:
 extends Auth
 var requests: Array = []
 func configured(): return true
 func _start(op, _endpoint, _data):
  if busy: return false
  busy = true
  operation = op
  _generation += 1
  requests.append(op)
  return true
var checks := 0
var failures := 0
func check(value, label):
 checks += 1
 if not value:
  failures += 1
  push_error(label)
func respond(a, op, data, code=200, result=HTTPRequest.RESULT_SUCCESS):
 a.busy = true
 a.operation = op
 a._generation += 1
 a._response(result,code,PackedStringArray(),JSON.stringify(data).to_utf8_buffer(),a._generation,op)
func login(a, uid="one"):
 respond(a,"signin",{"localId":uid,"idToken":"dummy-id","refreshToken":"dummy-refresh-"+uid,"expiresIn":"3600","email":"test@example.com"})
func refresh(a, uid="one", token="rotated"):
 respond(a,"refresh",{"user_id":uid,"id_token":"dummy-new-id","refresh_token":token,"expires_in":"3600"})
func _initialize(): call_deferred("run")
func run():
 var probe=ProbeStore.new()
 probe.files={"fixture.bak":100}
 check(not probe.read().ok and probe.reads==1,"backup-only file reaches AtomicFile recovery before envelope validation")
 probe.files={"fixture.bak":Store.MAX_BYTES+1}; probe.reads=0
 check(not probe.read().ok and probe.reads==0,"oversized backup rejected before allocation")
 probe.files={}; probe.reads=0
 check(probe.read().ok and probe.reads==0,"absent saved record makes no decrypt attempt")
 check(not Store.valid_record({"project":Store.PROJECT,"uid":"one","refresh_token":"dummy","password":"forbidden"}),"extra secret fields rejected")
 check(not Store.valid_record({"project":Store.PROJECT,"uid":"one","refresh_token":""}),"empty token rejected")
 var a = MockAuth.new()
 var store = MemoryStore.new()
 a.session_store = store
 root.add_child(a)
 check(not a.remembered and not a._remember_requested,"default off")
 check(a.sign_in("test@example.com","dummy"),"memory-only signin starts")
 login(a)
 check(a.signed_in() and store.record.is_empty() and store.writes==0,"default never persists")
 await process_frame
 check(a.requests[-1]=="lookup","automatic lookup after login")
 respond(a,"lookup",{"users":[{"localId":"one","emailVerified":true}]})
 check(a.email_verified and a.verification_checked,"automatic lookup hydrates verification")
 check(a.sign_out(),"logout default")
 check(a.sign_in("test@example.com","dummy",true),"opt-in starts")
 login(a)
 check(a.remembered and Store.valid_record(store.record),"only strict refresh record saved")
 check(not store.record.has("password") and not store.record.has("id_token") and not store.record.has("email"),"no password ID token or email persisted")
 a.cancel()
 a._clear_session()
 check(a.restore_saved_login() and not a.signed_in(),"restore requires server response")
 refresh(a)
 check(a.signed_in() and store.record.refresh_token=="rotated","restore rotates durable token")
 await process_frame
 check(a.requests[-1]=="lookup","restored session also hydrates verification")
 a.cancel()
 var stale=a._generation
 check(a.sign_out() and store.record.is_empty(),"logout removes durable record")
 a._response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),'{}'.to_utf8_buffer(),stale,"refresh")
 check(not a.signed_in() and store.record.is_empty(),"late callback cannot resurrect login")
 a.sign_in("test@example.com","dummy",true); login(a); a.cancel(); a._clear_session()
 a.restore_saved_login()
 respond(a,"refresh",{},200,HTTPRequest.RESULT_CANT_CONNECT)
 check(not a.signed_in() and not store.record.is_empty(),"offline restore retains encrypted record while unsigned")
 check(a.sign_in("test@example.com","dummy",false),"manual login after failed restoration")
 check(not a._restoring and store.record.is_empty(),"new login clears restoration and saved account")
 login(a,"two")
 check(a.user_id=="two" and not a.remembered,"account switch isolated")
 a.cancel(); a.sign_out()
 a.sign_in("test@example.com","dummy",true); login(a); a.cancel()
 store.fail_write=true
 refresh(a)
 check(a.signed_in() and not a.remembered and store.record.is_empty(),"failed rotation removes stale durable token; memory session remains")
 check("session only" in a.persistence_notice,"persistence failure is honest")
 store.fail_write=false; a.cancel(); a.sign_out()
 a.sign_in("test@example.com","dummy",true); login(a); a.cancel()
 store.fail_clear=true
 check(not a.sign_out() and not a.signed_in(),"failed deletion signs out memory but reports failure")
 check(not store.record.is_empty() and "Retry" in a.persistence_notice,"failed clear cannot claim forgotten")
 check(not a.sign_in("test@example.com","dummy",true),"replacement blocked while old durable record cannot clear")
 store.fail_clear=false
 check(a.sign_out() and store.record.is_empty(),"clear retry succeeds")
 a.sign_in("test@example.com","dummy",true); login(a); a.cancel()
 store.fail_clear=true
 var before_forget_writes=store.writes
 check(not a.forget_saved_login(),"explicit forget honestly reports deletion failure")
 check(not a._remember_requested,"explicit forget disables future saves even when deletion fails")
 var removal_warning=a.persistence_notice
 refresh(a)
 check(store.writes==before_forget_writes,"refresh cannot resave after an unsuccessful forget")
 check(a.persistence_notice==removal_warning and "remove" in removal_warning,"refresh retains unresolved deletion warning")
 check(a.remembered and not store.record.is_empty(),"uncleared durable record remains truthfully marked")
 a.cancel(); store.fail_clear=false
 check(a.forget_saved_login() and not a.remembered and store.record.is_empty(),"explicit forget retry verifies durable removal")
 a.sign_in("test@example.com","dummy",true); login(a); a.cancel()
 refresh(a,"different")
 check(not a.signed_in() and store.record.is_empty(),"wrong refresh UID clears durable session")
 a.sign_in("test@example.com","dummy",true); login(a); a.cancel()
 respond(a,"refresh",{"error":{"message":"INVALID_REFRESH_TOKEN"}},400)
 check(not a.signed_in() and store.record.is_empty(),"revoked refresh removes saved login")
 store.record={"project":"wrong","uid":"one","refresh_token":"dummy"}
 check(not a.restore_saved_login() and not a.signed_in(),"wrong project rejected before request")
 store.record={}; store.fail_read=true
 check(not a.restore_saved_login(),"corrupted or unavailable keystore fails closed")
 store.fail_read=false
 a.sign_in("test@example.com","dummy"); login(a)
 var count=a.requests.size()
 a.cancel()
 await process_frame
 check(a.requests.size()==count,"cancel prevents deferred verification lookup")
 a.sign_out()
 login(a)
 a.sign_out()
 await process_frame
 check(not a.signed_in() and store.record.is_empty(),"signout before queued lookup remains signed out")
 check(not Store.new().available(),"desktop cannot silently use plaintext fallback")
 a.queue_free()
 print("FIREBASE REMEMBER ME: %d checks; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
