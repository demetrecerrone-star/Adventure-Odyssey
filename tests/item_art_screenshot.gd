extends SceneTree
# Actual rendered equipment, vendor and backpack screens from recovered art.
func _initialize()->void:
	call_deferred("_run")

func _snapshot(file:String)->bool:
	for frame in range(18):await process_frame
	var capture=root.get_viewport().get_texture().get_image()
	return capture.get_width()>=500 and capture.save_png("res://screenshots/"+file)==OK

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	game._random_default()
	game.data["gold"]=500
	game.data["inventory"]["Iron Axe"]=1
	game.data["inventory"]["Leather Hood"]=1
	game.data["inventory"]["Forest Cloak"]=1
	game.data["inventory"]["Padded Gloves"]=1
	game.data["inventory"]["Steel Boots"]=1
	game.data["inventory"]["Copper Ring"]=1
	game.data["inventory"]["Iron Ore"]=3
	game.data["inventory"]["Slime Gel"]=2
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	game._dismiss_message()
	for item in ["Iron Axe","Leather Hood","Forest Cloak","Padded Gloves","Steel Boots","Copper Ring"]:
		game._equip_item(item)
	game._open_gear_menu()
	if not await _snapshot("equipment_original_art.png"):
		push_error("EQUIPMENT ART SCREENSHOT FAILED")
		quit(1)
		return
	game._open_shop("market")
	if not await _snapshot("market_original_art.png"):
		push_error("MARKET ART SCREENSHOT FAILED")
		quit(1)
		return
	game._open_item_inventory()
	if not await _snapshot("backpack_original_art.png"):
		push_error("BACKPACK ART SCREENSHOT FAILED")
		quit(1)
		return
	print("ADVENTURE ODYSSEY ITEM ART SCREENSHOTS: PASS")
	quit(0)