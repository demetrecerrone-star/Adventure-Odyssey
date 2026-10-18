extends RefCounted
# Device-local controls only. This file never contains character/account data.
# Use apply()/the setters for changes: callers only update their UI after true.
const VERSION := 1
const MODES := ["fixed", "floating"]
const MAX_FILE_BYTES := 4096
var path := "user://control_preferences_v1.json"
var mode := "fixed"
var left_handed := false
var error := ""

func load_saved() -> bool:
	error = ""
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "Couldn't read the local control preferences."
		return false
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return _invalid_file()
	var source := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return _invalid_file()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return _invalid_file()
	var data = parser.data
	if not data is Dictionary:
		return _invalid_file()
	var version = data.get("version")
	if not (version is int or version is float) or version != VERSION:
		return _invalid_file()
	if not data.get("mode") is String or data.mode not in MODES or not data.get("left_handed") is bool:
		return _invalid_file()
	# Commit both together only after every field has been validated. Unknown
	# fields can be ignored safely; these preferences never alter a guest save.
	mode = data.mode
	left_handed = data.left_handed
	return true

func apply(next_mode: String, next_left_handed: bool) -> bool:
	error = ""
	if next_mode not in MODES:
		error = "Choose fixed or floating controls."
		return false
	# Persist the candidate before changing the live settings, so any open,
	# write, flush or rename failure leaves both the old file and live state.
	if not _save_candidate(next_mode, next_left_handed):
		return false
	mode = next_mode
	left_handed = next_left_handed
	return true

func set_mode(next_mode: String) -> bool:
	return apply(next_mode, left_handed)

func set_left_handed(next_left_handed: bool) -> bool:
	return apply(mode, next_left_handed)

func _save_candidate(next_mode: String, next_left_handed: bool) -> bool:
	# Same-directory rename is the commit point. Never remove the old file
	# first, and never read an interrupted .tmp write as a saved preference.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "Couldn't save controls locally. Your previous settings are unchanged."
		return false
	file.store_string(JSON.stringify({"version":VERSION, "mode":next_mode, "left_handed":next_left_handed}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		error = "Couldn't finish saving controls. Your previous settings are unchanged."
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		error = "Couldn't finish saving controls. Your previous settings are unchanged."
		return false
	return true

func _invalid_file() -> bool:
	error = "Local control preferences could not be read. They have not been overwritten."
	return false
