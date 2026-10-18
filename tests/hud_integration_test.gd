extends SceneTree
const Save = preload("res://src/bedroom_save.gd")
const Preferences = preload("res://src/control_preferences.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const SCENES = ["bedroom", "starter_region", "guild_interior", "blacksmith_interior", "apothecary_interior", "general_store_interior"]
const PAGES = ["character", "inventory", "stats", "quest_log", "settings"]
class SafeBedroom:
	extends "res://src/bedroom.gd"
	func _control_safe_rect()->Rect2:
		return Rect2(Vector2(24,10),size-Vector2(48,20))
var checks := 0
var failures := 0
var stamp := str(Time.get_ticks_usec())
func check(ok:bool,description:String)->void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
func _initialize()->void: call_deferred("run")
func settle()->void:
	for tick in range(3): await process_frame
func controls(node:Node)->Array[Control]:
	var result:Array[Control] = []
	for child in node.get_children():
		if child is Control: result.append(child)
		result.append_array(controls(child))
	return result
func viewport_contains(control:Control)->bool:
	var r := control.get_global_rect()
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(r)
func snapshot(state)->String:
	return JSON.stringify([state.character,state.bag,state.chest,state.equipped_weapon,state.equipped_armor,state.location])
func create_room(id:String,inset:bool=false):
	var script_path := "res://src/bedroom.gd" if id == "bedroom" else ("res://src/starter_world.gd" if id == "starter_region" else "res://src/town_interior.gd")
	var room = SafeBedroom.new() if inset else load(script_path).new()
	if id.ends_with("_interior"): room.room_id = id
	room.state.path = "user://hud_test_"+stamp+"_"+id+".json"
	room.control_preferences.path = "user://hud_preferences_"+stamp+"_"+id+".json"
	var draft = Draft.new(); draft.set_base("female"); draft.character_class = "Ranger"; draft.username = "HUDTester"
	check(room.state.create(draft.payload()),id+" create isolated fixture")
	check(room.state.transfer("ranger_01_weapon",false),id+" put class bow in bag")
	var spawn := Vector2(625,700)
	if id == "starter_region": spawn = Vector2(1644,1333)
	elif id.ends_with("_interior"): spawn = room.entry_point(id)
	check(room.state.set_location(id,spawn),id+" save scene fixture")
	check(room.control_preferences.apply("floating",true),id+" save initial preferences")
	root.add_child(room); room.set_process(false)
	return room
func run()->void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,720)
	for id in SCENES:
		var room = create_room(id)
		await settle()
		room._sync_modal_input()
		check(room.hud.get_script().resource_path == "res://src/ui/adventure_hud.gd",id+" uses shared HUD")
		check(room.hud.coordinates_label.text == "X %d  ·  Y %d" % [roundi(room.player.x),roundi(room.player.y)], id+" first frame coordinates match actual player")
		check(room.control_preferences.mode == "floating" and room.control_preferences.left_handed and room.joystick.mode == "floating",id+" saved preferences applied on scene load")
		for resolution in [Vector2i(1280,720),Vector2i(844,390)]:
			root.size = resolution; await settle()
			for mode in ["fixed","floating"]:
				for left in [false,true]:
					var context := "%s %s %s left=%s" % [id,resolution,mode,left]
					room.open_menu(); var menu = room.overlay
					menu.show_page("settings")
					var unchanged := snapshot(room.state)
					menu.settings_changed.emit(mode,left)
					await settle()
					check(room.control_preferences.mode == mode and room.control_preferences.left_handed == left and room.joystick.mode == mode,context+" settings signal applies controls")
					var reload = Preferences.new(); reload.path = room.control_preferences.path
					check(reload.load_saved() and reload.mode == mode and reload.left_handed == left,context+" settings persisted")
					check(snapshot(room.state) == unchanged,context+" controls never alter guest state")
					var pref_path:String = room.control_preferences.path
					var pref_bytes := FileAccess.get_file_as_string(pref_path)
					var pad_before:Rect2 = room.joystick.get_global_rect()
					room.control_preferences.path = pref_path+"/missing/settings.json"
					menu.settings_changed.emit("floating" if mode == "fixed" else "fixed",not left)
					check(room.control_preferences.mode == mode and room.control_preferences.left_handed == left and room.joystick.mode == mode and room.joystick.get_global_rect() == pad_before,context+" failed settings save rolls back live controls")
					check(FileAccess.get_file_as_string(pref_path) == pref_bytes,context+" failed settings save preserves disk")
					room.control_preferences.path = pref_path
					menu.dismissed.emit(); await settle()
					check(room.overlay == null and room.joystick.input_enabled,context+" close reenables joystick")
					check(viewport_contains(room.joystick),context+" thumb zone within screen")
					if mode == "floating":
						room.joystick.owner_index = 0
						room.joystick._begin_pointer(Vector2(90,90))
						var first_origin:Vector2 = room.joystick.get_origin()
						room.joystick._begin_pointer(Vector2(room.joystick.size.x-90,90))
						check(room.joystick.get_origin().x-first_origin.x >= 40,context+" floating origin moves across bounded zone")
						room.joystick.reset()

					check((room.joystick.position.x > room.size.x/2) == left,context+" thumb side matches handedness")
					for key in ["identity_panel","map_panel","quest_panel","vitals_panel","action_cluster","interaction_panel","message"]:
						check(viewport_contains(room.hud.get(key)),context+" HUD panel within viewport "+key)
					for control in controls(room.hud):
						if control is BaseButton and control.is_visible_in_tree():
							check(viewport_contains(control),context+" HUD button inside screen "+control.name)
							check(not control.get_global_rect().intersects(room.joystick.get_global_rect()),context+" HUD button clears thumb "+control.name)
					room.joystick.set_position_input(room.joystick.size*0.5+Vector2(60,0))
					room.moving_to_target = true
					check(room.touch_direction.length() > 0,context+" held input fixture active")
					room.hud.menu_requested.emit(); menu = room.overlay
					check(menu.page == "menu" and menu.dropdown.visible and not menu.panel.visible,context+" opens dropdown first")
					check(viewport_contains(menu.dropdown),context+" dropdown within viewport")
					check(is_instance_valid(menu) and room.touch_direction == Vector2.ZERO and not room.moving_to_target and not room.joystick.input_enabled,context+" open menu clears and blocks held input")
					room.open_menu()
					check(room.overlay == menu,context+" repeated menu never stacks")
					var before:Vector2 = room.player
					room.joystick.set_position_input(room.joystick.size*0.5+Vector2(60,0))
					room._process(0.05)
					check(room.player == before and room.touch_direction == Vector2.ZERO,context+" modal blocks movement")
					for page in PAGES:
						menu.show_page(page); await settle()
						check(is_instance_valid(room.overlay) and menu.page == page,context+" page available "+page)
						for key in ["panel","sidebar","body_scroll","close_button"]:
							check(viewport_contains(menu.get(key)),context+" menu control inside viewport "+page+" "+key)
						for nav in menu.page_buttons.values():
							check(viewport_contains(nav),context+" navigation inside viewport "+page)
					menu.dismissed.emit()
					check(room.overlay == null and room.touch_direction == Vector2.ZERO and not room.moving_to_target,context+" dismissal resets input")
		room.open_menu(); await settle()
		var outside := InputEventScreenTouch.new()
		outside.index = 8; outside.pressed = true; outside.position = Vector2(room.size.x-5,room.size.y-5)
		Input.parse_input_event(outside)
		await settle()
		check(room.overlay == null and room.touch_direction == Vector2.ZERO and not room.moving_to_target and room.joystick.input_enabled,id+" actual outside tap dismisses dropdown and resets input")
		outside = outside.duplicate(); outside.pressed = false; Input.parse_input_event(outside)
		room.open_menu(); var equipment_menu = room.overlay
		equipment_menu.show_page("inventory")
		var equip_path:String = room.state.path
		var equip_bytes := FileAccess.get_file_as_string(equip_path)
		room.state.path = equip_path+"/missing/save.json"
		equipment_menu.equip_requested.emit("ranger_01_weapon")
		check(room.state.equipped_weapon == "" and room.actor.equipped_weapon == "" and room.state.bag.ranger_01_weapon == 1,id+" failed equip preserves actor and bag")
		check(FileAccess.get_file_as_string(equip_path) == equip_bytes,id+" failed equip preserves disk")
		room.state.path = equip_path
		equipment_menu.equip_requested.emit("ranger_01_weapon")
		check(room.state.equipped_weapon == "ranger_01_weapon" and room.actor.equipped_weapon == "ranger_01_weapon",id+" equip refreshes actor")
		var saved = Save.new(); saved.path = room.state.path
		check(saved.load_saved() and saved.equipped_weapon == "ranger_01_weapon" and saved.bag.ranger_01_weapon == 0,id+" equip persisted once")
		equip_bytes = FileAccess.get_file_as_string(equip_path)
		room.state.path = equip_path+"/missing/save.json"
		equipment_menu.unequip_requested.emit()
		check(room.state.equipped_weapon == "ranger_01_weapon" and room.actor.equipped_weapon == "ranger_01_weapon" and room.state.bag.ranger_01_weapon == 0,id+" failed unequip preserves actor and bag")
		check(FileAccess.get_file_as_string(equip_path) == equip_bytes,id+" failed unequip preserves disk")
		room.state.path = equip_path
		equipment_menu.unequip_requested.emit()
		check(room.state.equipped_weapon == "" and room.actor.equipped_weapon == "" and room.state.bag.ranger_01_weapon == 1,id+" unequip refreshes actor and returns one item")
		check(saved.load_saved() and saved.equipped_weapon == "" and saved.bag.ranger_01_weapon == 1,id+" unequip persisted")
		room._close_overlay()
		var save_path:String = room.state.path; var prefs_path:String = room.control_preferences.path
		room.free(); await process_frame
		DirAccess.remove_absolute(save_path); DirAccess.remove_absolute(prefs_path)
	root.size = Vector2i(844,390)
	var inset_room = create_room("bedroom",true)
	await settle()
	for mode in ["fixed","floating"]:
		for left in [false,true]:
			check(inset_room.control_preferences.apply(mode,left),"Inset fixture settings saved")
			inset_room._apply_control_layout(); await settle()
			var safe:Rect2 = inset_room._control_safe_rect()
			check(safe.encloses(inset_room.joystick.get_global_rect()),"Inset safe rectangle contains thumb zone "+mode+str(left))
			for key in ["identity_panel","map_panel","quest_panel","vitals_panel","action_cluster","interaction_panel","message"]:
				check(safe.encloses(inset_room.hud.get(key).get_global_rect()),"Inset safe rectangle contains HUD "+key)
			for control in controls(inset_room.hud):
				if control is BaseButton and control.is_visible_in_tree():
					check(not control.get_global_rect().intersects(inset_room.joystick.get_global_rect()),"Inset HUD clears thumb "+control.name)
	var inset_save:String = inset_room.state.path; var inset_preferences:String = inset_room.control_preferences.path
	inset_room.free(); await process_frame
	DirAccess.remove_absolute(inset_save); DirAccess.remove_absolute(inset_preferences)
	print("HUD INTEGRATION CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
