extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const IDS = ["guild_interior", "blacksmith_interior", "apothecary_interior", "general_store_interior"]
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func snapshot(s) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"character":s.character.duplicate(true), "bag":s.bag.duplicate(true), "chest":s.chest.duplicate(true), "weapon":s.equipped_weapon, "armor":s.equipped_armor, "awake":s.awake}))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://interior_regression_%s.json" % Time.get_ticks_usec()
	var state = Save.new()
	state.path = path
	var draft = Draft.new()
	draft.set_base("female")
	draft.character_class = "Ranger"
	draft.username = "InteriorQA"
	check(state.create(draft.payload()), "Create isolated save fixture")
	check(state.transfer("healing_potion", false), "Withdraw potion before transitions")
	check(state.transfer("ranger_01_weapon", false) and state.equip("ranger_01_weapon"), "Equip before transitions")
	var inventory := snapshot(state)
	for id in IDS:
		for p in [[0,0], [1536,1024], [1536,0], [0,1024], [768.25,700.5]]:
			check(state.valid_location({"scene":id,"position":p}), id + " accepts finite in-bounds " + str(p))
			check(state.set_location(id,Vector2(p[0],p[1])), id + " persists " + str(p))
			var reloaded = Save.new()
			reloaded.path = path
			check(reloaded.load_saved(), id + " reload succeeds")
			check(reloaded.location == state.location, id + " exact location round trip")
			check(snapshot(reloaded) == inventory, id + " inventory and appearance unchanged on load")
		for p in [[-0.01,0], [0,-0.01], [1536.01,0], [0,1024.01], [4608,3072], [NAN,0], [0,NAN], [INF,0], [0,INF], [-INF,0], [0,-INF], ["1",2], [true,2], [null,2], [], [1], [1,2,3]]:
			check(not state.valid_location({"scene":id,"position":p}), id + " rejects invalid " + str(p))
		var before: Dictionary = state.location.duplicate(true)
		var bytes := FileAccess.get_file_as_string(path)
		for p in [Vector2(-1,0),Vector2(1537,0),Vector2(0,1025),Vector2(NAN,0),Vector2(INF,0)]:
			check(not state.set_location(id,p), id + " setter rejects " + str(p))
			check(state.location == before and snapshot(state) == inventory, id + " invalid setter preserves all memory")
			check(FileAccess.get_file_as_string(path) == bytes, id + " invalid setter preserves disk bytes")
		state.path = path + "/missing/save.json"
		check(not state.set_location(id,Vector2(700,700)), id + " failed save returns false")
		check(state.location == before and snapshot(state) == inventory, id + " failed save rolls back memory")
		check(not state.error.is_empty(), id + " failed save reports error")
		check(FileAccess.get_file_as_string(path) == bytes, id + " failed save preserves disk")
		state.path = path
		# Structurally valid JSON with a malicious location must not alter the loaded session.
		var data: Dictionary = JSON.parse_string(bytes)
		for invalid in [{"scene":id,"position":[1537,500]}, {"scene":id,"position":[500,1025]}, {"scene":id,"position":["NaN",500]}]:
			data.location = invalid
			var corrupt_path := path + ".invalid"
			var file := FileAccess.open(corrupt_path,FileAccess.WRITE)
			file.store_string(JSON.stringify(data)); file.close()
			var corrupt_bytes := FileAccess.get_file_as_string(corrupt_path)
			state.path = corrupt_path
			check(not state.load_saved(), id + " malformed location load fails")
			check(state.location == before and snapshot(state) == inventory, id + " invalid load leaves session intact")
			check(FileAccess.get_file_as_string(corrupt_path) == corrupt_bytes, id + " invalid load leaves file intact")
			DirAccess.remove_absolute(corrupt_path)
		state.path = path
	for bad in [null, [], {}, {"scene":"unknown","position":[0,0]}, {"scene":"guild","position":[0,0]}, {"scene":"guild_interior","position":Vector2.ZERO}]:
		check(not state.valid_location(bad), "Reject malformed location " + str(bad))
	check(state.valid_location({"scene":"starter_region","position":[4608,3072]}),"World retains full map bounds")
	check(not state.valid_location({"scene":"starter_region","position":[4609,3072]}),"World rejects beyond map bounds")
	check(state.valid_location({"scene":"bedroom","position":[1536,1024]}),"Bedroom accepts inclusive room edge")
	check(not state.valid_location({"scene":"bedroom","position":[1537,500]}),"Bedroom rejects beyond horizontal room edge")
	check(not state.valid_location({"scene":"bedroom","position":[500,1025]}),"Bedroom rejects beyond vertical room edge")
	check(state.set_location("bedroom",Vector2(780,440)), "Existing bedroom save remains valid")
	check(state.set_location("starter_region",Vector2(1644,1333)), "Existing world save remains valid")
	check(snapshot(state) == inventory, "All transitions preserve inventory and equipment")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	print("INTERIOR SAVE CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
