extends SceneTree
const Config = preload("res://src/accounts/account_config.gd")
func _initialize() -> void:
 var enabled := "--expect-enabled" in OS.get_cmdline_user_args()
 var valid := Config.PROJECT_ID == "adventure-odyssey-2aadf" and Config.ENABLED == enabled
 if enabled:
  var pattern := RegEx.new()
  pattern.compile("^AIza[A-Za-z0-9_-]{35}$")
  valid = valid and pattern.search(Config.WEB_API_KEY) != null
 else:
  valid = valid and Config.WEB_API_KEY.is_empty()
 # No request object, account or email is created; never print client values.
 print("PACKAGED ACCOUNT CONFIG: PASS" if valid else "PACKAGED ACCOUNT CONFIG: FAIL")
 quit(0 if valid else 1)
