extends SceneTree
# Deliberately inspect each of 96 original-frame registrations. Refinement
# covers shirt artwork beneath underwear and narrows bulky removed boots.
func _initialize()->void:
	call_deferred("_test")
func _expect(ok:bool,reason:String)->bool:
	if not ok:
		push_error("AO CHARACTER POLISH TEST FAILED: "+reason)
		quit(1)
		return false
	return true
func _test()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	var checked:int=0
	for body in range(8):
		game.data["body"]=body
		for face in ["down","left","up","right"]:
			game.facing=face
			for frame in range(3):
				game.anim_frame=frame
				game._set_player_frame()
				var image:Image=game.base_sprite.texture.get_image()
				if not _expect(image!=null and image.get_height()==128,"preserved 128px body alignment"):return
				var mid:int=int(image.get_width()/2)
				var undershirt:Color=image.get_pixel(mid,70)
				var shorts:Color=image.get_pixel(mid,90)
				if not _expect(undershirt.a>.85 and undershirt.b>undershirt.r,"modest opaque underlayer covers torso"):return
				if not _expect(shorts.a>.85 and shorts.b>shorts.r,"modest opaque underwear shorts"):return
				for layer in ["starter_top","starter_pants","starter_shoes"]:
					if not _expect(game.starter_clothes_sprites.has(layer),"starter garment exists: "+layer):return
					if not _expect(game.starter_clothes_sprites[layer].texture.get_size()==game.base_sprite.texture.get_size(),"garment matches registered body: "+layer):return
				checked+=1
	if not _expect(checked==96,"eight variants times four facings times three original frames"):return
	for klass in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
		game.data["class"]=klass
		game._ensure_gear()
		for item in ["Iron Sword","Guard Breastplate","Leather Hood","Forest Cloak","Padded Gloves","Steel Boots","Copper Ring"]:
			game.data["inventory"][item]=1
			game._equip_item(item)
			var slot:String=str(game._gear_def(item)["slot"])
			if not _expect(game._equipped(slot)==item,"unrestricted " + klass + " " + item):return
			if not _expect(game.worn_equipment_sprites[slot].visible,"visible worn art " + klass + " " + item):return
	if not _expect(game._save() and game._load_save(),"saved character gear compatibility"):return
	print("ADVENTURE ODYSSEY CHARACTER POLISH TEST: PASS")
	quit(0)