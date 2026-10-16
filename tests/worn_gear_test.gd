extends SceneTree
# Real Godot verification for original-icon-derived wearable equipment previews.
func _initialize()->void:
	call_deferred("_run")

func _ok(valid:bool,detail:String)->bool:
	if not valid:
		push_error("AO WORN GEAR TEST FAILED: "+detail)
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
	if not _ok(game.worn_equipment_sprites.size()==7,"seven ordered equipment layers are attached"):return
	game._ensure_gear()
	var count:int=0
	for item in game.ITEM_CATALOG.keys():
		var name:String=str(item)
		var def:Dictionary=game._gear_def(name)
		var slot:String=str(def["slot"])
		game.data["inventory"][name]=1
		game._equip_item(name)
		var sprite:Sprite2D=game.worn_equipment_sprites[slot]
		if not _ok(sprite.visible and sprite.texture!=null,"equipped item appears: "+name):return
		if not _ok(sprite.texture.get_size()==game.base_sprite.texture.get_size(),"item matches body sprite alignment: "+name):return
		if slot=="head" and not _ok(not game.hair_sprite.visible,"hood covers hair"):return
		game._unequip_slot(slot)
		if not _ok(not sprite.visible,"remove item clears visual: "+name):return
		count+=1
	if not _ok(count==34,"12 weapons + 12 armor/clothes + 10 accessories"):return
	for body in range(8):
		game.data["body"]=body
		for face in ["down","left","up","right"]:
			game.facing=face
			for frame in range(3):
				game.anim_frame=frame
				game._set_player_frame()
				for name in ["Iron Axe","Iron Plate","Leather Hood","Forest Cloak","Padded Gloves","Steel Boots","Copper Ring"]:
					var path:String=game._worn_gear_path(name)
					if not _ok(ResourceLoader.exists(path),"aligned worn art exists: "+name+" "+path):return
	game.data["body"]=2
	game.facing="down"
	game.anim_frame=0
	game._set_player_frame()
	game.data["inventory"]["Iron Axe"]=1
	game._equip_item("Iron Axe")
	if not _ok(game._save() and game._load_save() and game._equipped("weapon")=="Iron Axe","wearable equipment save/load retained"):return
	game._enter_world("forest",Vector2(480,650))
	await process_frame
	if not _ok(game.worn_equipment_sprites["weapon"].visible,"equipped weapon survives map transition"):return
	print("ADVENTURE ODYSSEY WORN GEAR TEST: PASS")
	quit(0)
