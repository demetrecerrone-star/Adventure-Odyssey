extends SceneTree
# Verify derived opaque base and three independent starter layers, in-engine.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("AO APPEARANCE LAYERS TEST FAILED: "+message)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game.use_layered_appearance=true
	game._random_default()
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	if not _check(game.starter_appearance_sprites.size()==3,"3 starter clothing layers constructed"):return
	for variant in range(8):
		game.data["body"]=variant
		for facing in ["down","left","up","right"]:
			for frame in range(3):
				game.facing=facing
				game.anim_frame=frame
				game._set_player_frame()
				var relative="base_variant_%02d/%s_%02d.png" % [variant+1,facing,frame]
				var texture:Texture2D=game.base_sprite.texture
				if not _check(texture!=null and texture.get_height()==128,"opaque source-derived base: "+relative):return
				for layer in ["shirt","pants","shoes"]:
					var node:Sprite2D=game.starter_appearance_sprites[layer]
					if not _check(node.texture!=null and node.texture.get_width()==texture.get_width() and node.texture.get_height()==128,"matching starter "+layer+" "+relative):return
					if not _check(node.position==game.base_sprite.position,"aligned layer "+layer):return
	if not _check(game.hair_sprite.texture!=null,"independent hair maintained"):return
	# Default gameplay remains original until reconstructed underwear art is approved.
	game.use_layered_appearance=false
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	if not _check(game.starter_appearance_sprites.is_empty(),"original appearance remains default"):return
	if not _check(game.base_sprite.texture!=null,"original character texture restored"):return
	print("ADVENTURE ODYSSEY APPEARANCE LAYERS TEST: PASS")
	quit(0)
