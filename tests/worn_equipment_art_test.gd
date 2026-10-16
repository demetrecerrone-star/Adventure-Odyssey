extends SceneTree
# Distinct worn art and matching icons for every equippable catalog item.
func _initialize()->void:call_deferred("_run")
func _check(value:bool,label:String)->bool:
	if not value:
		push_error("AO WORN EQUIPMENT ART TEST FAILED: "+label)
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
	game._ensure_gear()
	if not _check(game.ITEM_CATALOG.size()==40,"34 original items plus 6 Guardian quest heirlooms"):return
	var seen_icons:Dictionary={}
	var all_names:Array=game.ITEM_CATALOG.keys()
	for entry in all_names:
		var item:String=str(entry)
		var slug:String=item.to_lower().replace("'","").replace(" ","_")
		var icon_path:String="res://assets/equipment_item_icons/"+slug+".png"
		if not _check(ResourceLoader.exists(icon_path),"matching icon: "+item):return
		var tex:Texture2D=load(icon_path)
		if not _check(tex!=null and tex.get_size()==Vector2(96,96),"icon imported at 96x96: "+item):return
		if not _check(not seen_icons.has(icon_path),"distinct file: "+item):return
		seen_icons[icon_path]=true
		game.data["inventory"][item]=1
		game._equip_item(item)
		var slot:String=str(game._gear_def(item)["slot"])
		var node:Sprite2D=game.worn_equipment_sprites[slot]
		if not _check(node.visible and node.texture!=null,"equipped artwork visible: "+item):return
		var worn_path:String=game._worn_gear_texture_path(slot,item,"down",0)
		if not _check(worn_path.begins_with("res://assets/equipment_worn/"),"bespoke sprite takes priority: "+item):return
		game._unequip_slot(slot)
		if not _check(not node.visible,"removing item hides artwork: "+item):return
	if not _check(seen_icons.size()==40,"unique matching icons for 40 wearable items"):return
	for klass in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
		game.data["class"]=klass
		for item in ["Iron Sword","Guard Breastplate","Leather Hood","Forest Cloak","Padded Gloves","Steel Boots","Copper Ring"]:
			game.data["inventory"][item]=1
			game._equip_item(item)
		for body in range(8):
			game.data["body"]=body
			for face in ["down","left","up","right"]:
				game.facing=face
				for frame in range(3):
					game.anim_frame=frame
					game._set_player_frame()
					for slot in game.WORN_EQUIPMENT_SLOTS:
						var node:Sprite2D=game.worn_equipment_sprites[slot]
						if not _check(node.visible and node.texture!=null and node.texture.get_size()==game.base_sprite.texture.get_size(),klass+" "+slot+" body "+str(body+1)+" "+face+"/"+str(frame)):return
	if not _check(game._save() and game._load_save() and game._equipped("weapon")=="Iron Sword","existing save compatible"):return
	print("ADVENTURE ODYSSEY WORN EQUIPMENT ART TEST: PASS")
	quit(0)