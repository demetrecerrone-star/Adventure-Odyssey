extends SceneTree
# Headwear, hair visibility, tint and restore checks on the real equipment renderer.
# Validates every available hairstyle, eight original bodies and all walk poses.
func _initialize() -> void:
	call_deferred("_run")

func _ok(value:bool, detail:String) -> bool:
	if not value:
		push_error("AO HEADGEAR HAIRSTYLES TEST FAILED: "+detail)
		quit(1)
		return false
	return true

func _run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	game._ensure_gear()
	game.data["inventory"]["Leather Hood"]=1
	game._equip_item("Leather Hood")
	if not _ok(game._equipped("head")=="Leather Hood","headgear equips regardless of class"):return
	var checked:int=0
	for body in range(8):
		game.data["body"]=body
		for hair in range(game.HAIR.size()):
			game.data["hair"]=hair
			game.data["hair_tint"]=hair%game.HAIR_TINTS.size()
			for face in ["down","left","up","right"]:
				game.facing=face
				for frame in range(3):
					game.anim_frame=frame
					game._set_player_frame()
					var hood:Sprite2D=game.worn_equipment_sprites["head"]
					var hair_sprite:Sprite2D=game.hair_sprite
					var label:String="body "+str(body+1)+" hair "+str(hair)+" "+face+"/"+str(frame)
					if not _ok(hood.visible and hood.texture!=null,label+" hood present"):return
					if not _ok(hood.texture.get_size()==game.base_sprite.texture.get_size(),label+" head alignment"):return
					if not _ok(hood.z_index>hair_sprite.z_index,label+" hood in front of hair"):return
					if not _ok(hair_sprite.texture!=null,label+" hair asset loaded"):return
					if not _ok(hair_sprite.visible==(face!="up"),label+" hair occlusion"):return
					var wanted:Color=game.HAIR_TINTS[hair%game.HAIR_TINTS.size()]
					if not _ok(hair_sprite.modulate.is_equal_approx(wanted),label+" hair tint preserved"):return
					checked+=1
	if not _ok(checked==8*game.HAIR.size()*4*3,"all bodies, hairstyles, facings and walk frames checked"):return
	game._unequip_slot("head")
	for hair in range(game.HAIR.size()):
		game.data["hair"]=hair
		for face in ["down","left","up","right"]:
			game.facing=face
			for frame in range(3):
				game.anim_frame=frame
				game._set_player_frame()
				if not _ok(game.hair_sprite.visible,"unequipped hood restores hair "+str(hair)+" "+face+"/"+str(frame)):return
				if not _ok(not game.worn_equipment_sprites["head"].visible,"unequipped hood hides overlay"):return
	game._equip_item("Leather Hood")
	if not _ok(game._save() and game._load_save() and game._equipped("head")=="Leather Hood","saved hood item restored"):return
	print("ADVENTURE ODYSSEY HEADGEAR HAIRSTYLES TEST: PASS / "+str(checked)+" equipped combinations + uncovered hair restore")
	quit(0)
