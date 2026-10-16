extends SceneTree
# Seven attachment nodes prepared; no fake giant inventory sprites on player.
func _initialize()->void:call_deferred("_run")
func _ok(value:bool,detail:String)->bool:
	if not value:
		push_error("AO EQUIPMENT VISUALS TEST FAILED: "+detail)
		quit(1)
		return false
	return true
func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	var slots=["cloak","armor","gloves","boots","weapon","head","accessory"]
	if not _ok(game.worn_equipment_sprites.size()==7,"all seven overlay slots exist"):return
	for slot in slots:
		var node:Sprite2D=game.worn_equipment_sprites[slot]
		if not _ok(node!=null and node.position==game.base_sprite.position,"registered aligned slot: "+slot):return
		if not _ok(not node.visible,"unavailable art is invisible: "+slot):return
	game._ensure_gear()
	for item in ["Iron Sword","Guard Breastplate","Padded Gloves","Steel Boots","Leather Hood","Forest Cloak","Copper Ring"]:
		game.data["inventory"][item]=1
		game._equip_item(item)
		var slot:String=game._gear_def(item)["slot"]
		if not _ok(game._equipped(slot)==item,"unrestricted item equipped: "+item):return
		if not _ok(not game.worn_equipment_sprites[slot].visible,"missing on-character art never silently faked: "+item):return
	if not _ok(game.starter_clothes_sprites["starter_top"].visible and game.starter_clothes_sprites["starter_shoes"].visible,"safe starter clothing fallback"):return
	game._save()
	if not _ok(game._load_save() and game._equipped("armor")=="Guard Breastplate","save compatible"):return
	for direction in ["down","left","up","right"]:
		game.facing=direction
		for frame in range(3):
			game.anim_frame=frame
			game._set_player_frame()
			if not _ok(game.worn_equipment_sprites.size()==7 and game.starter_clothes_sprites["starter_top"].visible,"safe for all directions/frames"):return
	print("ADVENTURE ODYSSEY EQUIPMENT VISUALS TEST: PASS")
	quit(0)