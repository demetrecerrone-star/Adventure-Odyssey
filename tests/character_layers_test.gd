extends SceneTree
# Tests the actual Godot scene after character sprite layer generation.
func _initialize()->void:
	call_deferred("_run")

func _ok(value:bool,detail:String)->bool:
	if not value:
		push_error("AO CHARACTER LAYERS TEST FAILED: "+detail)
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
	if not _ok(game.starter_clothes_sprites.size()==3,"three separate starting-outfit sprite layers"):return
	if not _ok(game.base_sprite.texture!=null,"underwear base texture imported"):return
	for body in range(8):
		game.data["body"]=body
		for facing in ["down","left","up","right"]:
			game.facing=facing
			for frame in range(3):
				game.anim_frame=frame
				game._set_player_frame()
				var base_path:String=game._layer_sprite_path("underwear_base",facing,frame)
				if not _ok(ResourceLoader.exists(base_path),"underwear sprite %d %s %d" % [body,facing,frame]):return
				var base_tex:Texture2D=game.base_sprite.texture
				if not _ok(base_tex!=null and base_tex.get_height()==128,"base size and alignment"):return
				for layer in game.STARTER_CLOTHES_LAYERS:
					var sprite:Sprite2D=game.starter_clothes_sprites[layer]
					if not _ok(sprite.texture!=null and sprite.visible and sprite.texture.get_size()==base_tex.get_size(),"aligned art: "+layer):return
					if not _ok(sprite.position==game.base_sprite.position,"identical pivots: "+layer):return
	game.data["body"]=5
	game.facing="down"
	game.anim_frame=0
	game._set_player_frame()
	game._ensure_gear()
	game.data["inventory"]["Iron Plate"]=1
	game._equip_item("Iron Plate")
	if not _ok(game._equipped("armor")=="Iron Plate","game equipment remains independent of clothing art"):return
	game._save()
	if not _ok(game._load_save() and game._equipped("armor")=="Iron Plate","equipment save/load compatible"):return
	game._enter_world("forest",Vector2(480,650))
	await process_frame
	if not _ok(game.starter_clothes_sprites.size()==3 and game.base_sprite.texture!=null,"layers follow world transitions"):return
	print("ADVENTURE ODYSSEY CHARACTER LAYERS TEST: PASS")
	quit(0)