extends RefCounted
# Android-only encrypted refresh-token storage. No password or ID token is accepted.
# Calls are serialized on the caller's Godot thread. Android latency remains a
# device-test gate; there is deliberately no plaintext or software-key fallback.
const PROJECT := "adventure-odyssey-2aadf"
const PACKAGE := "com.demetrecerrone.adventureodyssey"
const ALIAS := PACKAGE + "." + PROJECT + ".session.v1"
const FILE_NAME := "odyssey_session_v1.bin"
const AAD := PACKAGE + ":" + PROJECT + ":refresh:v1"
const MAX_BYTES := 24576
var error := ""
var _bridge: Object
var _classes := {}
var _context: Object
var _file: Object
var _atomic: Object
var _keystore: Object
var _failed := false
var _busy := false

func available() -> bool:
 return OS.has_feature("android") and Engine.has_singleton("AndroidRuntime") and Engine.has_singleton("JavaClassWrapper")

static func valid_record(record: Dictionary) -> bool:
 if record.size() != 3 or record.get("project") != PROJECT: return false
 for field in ["uid", "refresh_token"]:
  if not record.get(field) is String or record[field].is_empty(): return false
 return record.uid.length() <= 128 and record.refresh_token.length() <= 16384

func _java(target: Object, method: String, args: Array = []) -> Variant:
 if _failed or not is_instance_valid(target):
  _failed = true
  return null
 var result = target.callv(method, args)
 if is_instance_valid(_bridge) and _bridge.call("get_exception") != null: _failed = true
 return result

func _initialize() -> bool:
 error = ""
 _failed = false
 if not available():
  error = "Secure login storage is unavailable on this device."
  return false
 _bridge = Engine.get_singleton("JavaClassWrapper")
 if not _bridge.has_method("get_exception"):
  error = "Secure login storage requires supported Android exception handling."
  return false
 # get_exception retains the previous wrapped Java call's exception. A
 # benign wrapped call resets that slot before retrying a failed operation.
 var system = _bridge.call("wrap", "java.lang.System")
 var clock_value = _java(system, "nanoTime")
 if _failed or not clock_value is int: return _failure()
 for pair in [["store", "java.security.KeyStore"], ["generator", "javax.crypto.KeyGenerator"], ["builder", "android.security.keystore.KeyGenParameterSpec$Builder"], ["cipher", "javax.crypto.Cipher"], ["gcm", "javax.crypto.spec.GCMParameterSpec"], ["file", "java.io.File"], ["atomic", "android.util.AtomicFile"]]:
  _classes[pair[0]] = _bridge.call("wrap", pair[1])
  if not is_instance_valid(_classes[pair[0]]) or _bridge.call("get_exception") != null: _failed = true
 if _failed: return _failure()
 var runtime = Engine.get_singleton("AndroidRuntime")
 _context = _java(runtime, "getApplicationContext")
 if _java(_context, "getPackageName") != PACKAGE: return _failure()
 var directory = _java(_context, "getNoBackupFilesDir")
 _file = _java(_classes.file, "File", [directory, FILE_NAME])
 _atomic = _java(_classes.atomic, "AtomicFile", [_file])
 _keystore = _java(_classes.store, "getInstance", ["AndroidKeyStore"])
 _java(_keystore, "load", [null])
 if _failed: return _failure()
 return true

func _failure() -> bool:
 error = "Secure login storage failed. No unencrypted login was saved."
 return false

func _key(create: bool) -> Object:
 var exists = _java(_keystore, "containsAlias", [ALIAS])
 if _failed: return null
 if not exists:
  if not create: return null
  # The constructor name includes the inner-class suffix in Godot's JNI wrapper.
  var builder = _java(_classes.builder, "KeyGenParameterSpec$Builder", [ALIAS, 3]) # encrypt | decrypt
  _java(builder, "setBlockModes", [PackedStringArray(["GCM"])])
  _java(builder, "setEncryptionPaddings", [PackedStringArray(["NoPadding"])])
  _java(builder, "setKeySize", [256])
  _java(builder, "setRandomizedEncryptionRequired", [true])
  var spec = _java(builder, "build")
  var generator = _java(_classes.generator, "getInstance", ["AES", "AndroidKeyStore"])
  _java(generator, "init", [spec])
  _java(generator, "generateKey")
 var key = _java(_keystore, "getKey", [ALIAS, null])
 return null if _failed else key

func write(record: Dictionary) -> bool:
 if _busy or not valid_record(record): return _failure()
 _busy = true
 var ok := _write(record)
 _busy = false
 return ok

func _write(record: Dictionary) -> bool:
 if not _initialize(): return false
 var key := _key(true)
 if key == null: return _failure()
 var cipher = _java(_classes.cipher, "getInstance", ["AES/GCM/NoPadding"])
 _java(cipher, "init", [1, key]) # Cipher generates a fresh IV.
 _java(cipher, "updateAAD", [AAD.to_utf8_buffer()])
 var plain := JSON.stringify(record).to_utf8_buffer()
 var encrypted = _java(cipher, "doFinal", [plain])
 plain.fill(0)
 var iv = _java(cipher, "getIV")
 if _failed or not encrypted is PackedByteArray or not iv is PackedByteArray or iv.size() != 12: return _failure()
 var envelope := "AOS1".to_utf8_buffer()
 envelope.append_array(iv)
 envelope.append_array(encrypted)
 if envelope.size() > MAX_BYTES: return _failure()
 var stream = _java(_atomic, "startWrite")
 _java(stream, "write", [envelope])
 if _failed:
  # AtomicFile restores its previous ciphertext on failure. No plaintext file.
  _failed = false
  _java(_atomic, "failWrite", [stream])
  return _failure()
 _java(_atomic, "finishWrite", [stream])
 if _failed: return _failure()
 var committed = _java(_atomic, "readFully")
 if _failed or not committed is PackedByteArray or committed != envelope: return _failure()
 return true

func read() -> Dictionary:
 if _busy: return {"ok":false, "record":{}}
 _busy = true
 var result := _read()
 _busy = false
 return result

func _read() -> Dictionary:
 if not _initialize(): return {"ok":false, "record":{}}
 # AtomicFile may need to recover a previous .bak-only interrupted write.
 var path = _java(_file, "getAbsolutePath")
 if _failed or not path is String: return {"ok":_failure(), "record":{}}
 var found := false
 for suffix in ["", ".bak"]:
  var candidate = _java(_classes.file, "File", [path + suffix])
  if _java(candidate, "exists"):
   found = true
   var length = _java(candidate, "length")
   if _failed or not length is int or length > MAX_BYTES: return {"ok":_failure(), "record":{}}
 if _failed: return {"ok":_failure(), "record":{}}
 if not found: return {"ok":true, "record":{}}
 var envelope = _java(_atomic, "readFully")
 if _failed or not envelope is PackedByteArray or envelope.size() < 33 or envelope.size() > MAX_BYTES or envelope.slice(0,4).get_string_from_utf8() != "AOS1": return {"ok":_failure(), "record":{}}
 var key := _key(false)
 if key == null: return {"ok":_failure(), "record":{}}
 var params = _java(_classes.gcm, "GCMParameterSpec", [128, envelope.slice(4,16)])
 var cipher = _java(_classes.cipher, "getInstance", ["AES/GCM/NoPadding"])
 _java(cipher, "init", [2, key, params])
 _java(cipher, "updateAAD", [AAD.to_utf8_buffer()])
 var plain = _java(cipher, "doFinal", [envelope.slice(16)])
 if _failed or not plain is PackedByteArray: return {"ok":_failure(), "record":{}}
 var parser := JSON.new()
 var parsed := parser.parse(plain.get_string_from_utf8())
 plain.fill(0)
 if parsed != OK or not parser.data is Dictionary or not valid_record(parser.data): return {"ok":_failure(), "record":{}}
 return {"ok":true, "record":parser.data}

func clear() -> bool:
 if _busy: return _failure()
 _busy = true
 var ok := _clear()
 _busy = false
 return ok

func _clear() -> bool:
 if not _initialize(): return false
 _java(_keystore, "deleteEntry", [ALIAS])
 var key_failed := _failed
 _failed = false # Still attempt ciphertext deletion if key deletion failed.
 _java(_atomic, "delete")
 var file_failed := _failed
 _failed = false
 var still_key = _java(_keystore, "containsAlias", [ALIAS])
 var path = _java(_file, "getAbsolutePath")
 if _failed or not path is String: return _failure()
 var still_file := false
 for suffix in ["", ".bak", ".new"]:
  var candidate = _java(_classes.file, "File", [path + suffix])
  still_file = bool(_java(candidate, "exists")) or still_file
 if key_failed or file_failed or _failed or still_key or still_file: return _failure()
 return true
