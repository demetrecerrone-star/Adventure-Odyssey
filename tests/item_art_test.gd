extends SceneTree
# Original recovered gear artwork is integrated into the actual buy/equip/bag paths.
func _initialize()->void:
	call_deferred("_run")

func _ok(ok:bool,detail:String)->bool:
	if not ok:
		push_error("AO ITEM ART TEST FAILED: "+detail)
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
	var unique={}
	var all_names:Array=game.ITEM_CATALOG.keys()+game.GEAR_MATERIAL_NAMES
	if not _ok(all_names.size()==45,"18 weapons, 12 armor, 10 accessories and 5 materials"):return
	for entry in all_names:
		var name:String=str(entry)
		var slug:String=name.to_lower().replace("'","").replace(" ","_")
		var icon:String="res://assets/equipment_item_icons/%s.png" % slug if bool(game._gear_def(name).get("quest_reward",false)) else "res://assets/items/%s.svg" % slug
		if not _ok(ResourceLoader.exists(icon),"icon exists: "+name):return
		var tex:Texture2D=load(icon)
		if not _ok(tex!=null and tex.get_width()==96 and tex.get_height()==96,"valid sprite: "+name):return
		if not _ok(not unique.has(icon),"different file per illustrated item: "+name):return
		unique[icon]=true
	if not _ok(game._starter_skills().size()==3,"starter skills unchanged"):return
	game.data["gold"]=5000
	for klass in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
		game.data["class"]=klass
		for name in ["Iron Axe","Leather Hood","Forest Cloak","Padded Gloves","Steel Boots","Guard Sigil"]:
			game.data["inventory"][name]=1
			game._equip_item(name)
			var slot:String=str(game._gear_def(name)["slot"])
			if not _ok(game._equipped(slot)==name,klass+" equips "+name+" without class gates"):return
	if not _ok(game._gear_def("Traveler Robe")["slot"]=="armor","old save chest slot compatible"):return
	game._open_gear_menu()
	if not _ok(game.popup!=null and game.popup.get_node_or_null("ItemIcon_steel_boots")!=null,"equipment screen shows approved item artwork"):return
	game._open_shop("market")
	game._shop_page("market",1)
	if not _ok(game.gear_shop_page==1,"shop next page navigates"):return
	game._buy_item("market","Leather Vest")
	if not _ok(int(game.data["inventory"].get("Leather Vest",0))>=1,"new gear purchasable"):return
	game._award_gear_material("wolf")
	game._award_gear_material("fungus")
	game.data["quest_kills"]=2
	game._award_gear_material("slime")
	if not _ok(int(game.data["inventory"].get("Beast Hide",0))>=1 and int(game.data["inventory"].get("Enchanted Thread",0))>=1 and int(game.data["inventory"].get("Slime Gel",0))>=1,"new craft materials drop"):return
	game._open_item_inventory()
	if not _ok(game.popup!=null,"backpack renders"):return
	if not _ok(game._save() and game._load_save() and game._equipped("boots")=="Steel Boots","new equipment persists on saves"):return
	print("ADVENTURE ODYSSEY ITEM ART TEST: PASS")
	quit(0)