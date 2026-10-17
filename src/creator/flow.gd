extends RefCounted
signal creator_requested
signal existing_character_ready(character_id: String)
# The future authenticated application coordinator calls this AFTER its backend
# verifies the session and fetches the account's authoritative character state.
# No token, password or simulated account is stored by this UI module.
var account_id := ""
var awaiting_save := false
var request_generation := 0
func authenticated_profile_loaded(profile: Dictionary) -> bool:
	if str(profile.get("account_id", "")).is_empty():
		return false
	if profile.get("character_status", "") not in ["incomplete", "complete"]:
		return false
	if profile.character_status == "complete" and str(profile.get("character_id", "")).is_empty():
		return false
	request_generation += 1
	awaiting_save = false
	account_id = profile.account_id
	if profile.character_status == "complete":
		existing_character_ready.emit(profile.character_id)
	else:
		creator_requested.emit()
	return true
func begin_save(draft) -> Dictionary:
	if account_id.is_empty() or awaiting_save or not draft.validate().is_empty():
		return {}
	awaiting_save = true
	request_generation += 1
	return {"account_id":account_id, "generation":request_generation, "character":draft.payload()}
func save_result(generation: int, success: bool, character_id: String = "") -> bool:
	if not awaiting_save or generation != request_generation:
		return false
	awaiting_save = false
	if success and not character_id.is_empty():
		existing_character_ready.emit(character_id)
		return true
	return false
func sign_out() -> void:
	request_generation += 1
	awaiting_save = false
	account_id = ""
