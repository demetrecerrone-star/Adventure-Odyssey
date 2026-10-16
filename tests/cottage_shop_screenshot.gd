extends SceneTree
# Captures live gameplay pixels, never a replacement drawing or mockup.
func _initialize()->void:
	call_deferred("_run")

func _capture(file_name:String)->bool:
	for n in range(8):
		await process_frame
	var img=root.get_viewport().get_texture().get_image()
	if img.get_width()<500 or img.get_height()<300:
		push_error("COTTAGE SCREENSHOT: small viewport")
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var err=img.save_png("res://screenshots/"+file_name)
	if err!=OK:
		push_error("COTTAGE SCREENSHOT: could not write "+file_name)
		return false
	print("COTTAGE SCREENSHOT: screenshots/"+file_name)
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("bedroom",game.BEDROOM_SPAWN)
	if not await _capture("cottage_free_starter.png"):
		quit(1)
		return
	game._award_sigils(210)
	if not game._cottage_buy_tier("noble"):
		quit(1)
		return
	game._cottage_equip("noble","feminine")
	if not await _capture("cottage_noble_queen_room.png"):
		quit(1)
		return
	game._award_sigils(0)
	if not game._cottage_buy_tier("castle"):
		quit(1)
		return
	game._cottage_equip("castle","masculine")
	if not await _capture("cottage_castle_king_room.png"):
		quit(1)
		return
	if not game._cottage_buy_tier("royal"):
		quit(1)
		return
	game._cottage_equip("royal","unisex")
	if not await _capture("cottage_royal_unisex_room.png"):
		quit(1)
		return
	game.data["gold"]=100
	for slot in ["Bed","Mirror","Chest"]:
		if not game._cottage_gold_buy(slot):
			quit(1)
			return
	if not await _capture("cottage_gold_furniture_room.png"):
		quit(1)
		return
	game._open_cottage_gold_shop()
	if not await _capture("cottage_gold_shop_menu.png"):
		quit(1)
		return
	game._open_cottage_collections("noble","unisex")
	if not await _capture("cottage_sigil_shop_menu.png"):
		quit(1)
		return
	print("ADVENTURE ODYSSEY COTTAGE SCREENSHOTS: PASS")
	quit(0)
