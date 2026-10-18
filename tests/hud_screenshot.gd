extends SceneTree
const Draft = preload("res://src/creator/character_draft.gd")
const PAGES = ["character","inventory","stats","quest_log","settings"]
var stamp := str(Time.get_ticks_usec())
func _initialize()->void: call_deferred("run")
func snap(filename:String)->void:
	for tick in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+filename)==OK)
func make_room(id:String):
	var script_path := "res://src/bedroom.gd" if id == "bedroom" else ("res://src/starter_world.gd" if id == "starter_region" else "res://src/town_interior.gd")
	var room = load(script_path).new()
	if id.ends_with("_interior"): room.room_id = id
	room.state.path = "user://hud_capture_"+stamp+"_"+id+".json"
	room.control_preferences.path = "user://hud_capture_preferences_"+stamp+"_"+id+".json"
	var draft = Draft.new(); draft.set_base("female"); draft.character_class = "Ranger"; draft.username = "Aeloria"
	draft.skin = "warm"
	assert(room.state.create(draft.payload()))
	assert(room.state.transfer("ranger_01_weapon",false) and room.state.equip("ranger_01_weapon"))
	assert(room.state.transfer("healing_potion",false))
	var spawn := Vector2(780,650)
	if id == "starter_region": spawn = Vector2(2433.3,1002.45)
	elif id.ends_with("_interior"): spawn = room.entry_point(id)
	assert(room.state.set_location(id,spawn))
	assert(room.control_preferences.apply("fixed",false))
	root.add_child(room); room.set_process(false)
	return room
func run()->void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for id in ["bedroom","starter_region","guild_interior"]:
		root.size = Vector2i(1280,720)
		var room = make_room(id)
		for dimensions in [Vector2i(1280,720),Vector2i(844,390)]:
			root.size = dimensions
			for left in [false,true]:
				for mode in ["fixed","floating"]:
					assert(room.control_preferences.apply(mode,left))
					room._apply_control_layout()
					var prefix := "hud_%s_%dx%d_%s_%s" % [id,dimensions.x,dimensions.y,"left" if left else "right",mode]
					await snap(prefix+"_gameplay.png")
					if id == "starter_region" and dimensions == Vector2i(1280,720) and not left and mode == "fixed":
						await snap("hud_world_right.png")
					if mode == "fixed" and id == "bedroom":
						room.open_menu()
						await snap(prefix+"_dropdown.png")
						for page in PAGES:
							room.overlay.show_page(page)
							await snap(prefix+"_"+page+".png")
						room._close_overlay()
		var save_path:String = room.state.path; var prefs_path:String = room.control_preferences.path
		room.free(); await process_frame
		DirAccess.remove_absolute(save_path); DirAccess.remove_absolute(prefs_path)
	print("HUD SCREENSHOTS: 49 native frames saved")
	quit()
