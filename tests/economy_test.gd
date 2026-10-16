extends SceneTree
func _initialize()->void:
	call_deferred("_run")
func _ok(v:bool,s:String)->bool:
	if not v:
		push_error("AO ECONOMY TEST FAILED: "+s)
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
	var initial_gold:int=int(game.data["gold"])
	game.data["gold"]=250
	game._buy_item("market","Traveler Robe")
	if not _ok(int(game.data["inventory"].get("Traveler Robe",0))==1,"purchased robe"):return
	if not _ok(int(game.data["gold"])==250-game._shop_price("Traveler Robe"),"gold charged"):return
	game._equip_item("Traveler Robe")
	if not _ok(game._equipped("armor")=="Traveler Robe","any class equips armor"):return
	game._sell_item("market","Traveler Robe")
	if not _ok(int(game.data["inventory"].get("Traveler Robe",0))==1,"equipped item cannot sell"):return
	game._dismiss_message()
	game._unequip_slot("armor")
	game._sell_item("market","Traveler Robe")
	if not _ok(int(game.data["inventory"].get("Traveler Robe",0))==0,"unequipped item sold"):return
	game._buy_item("blacksmith","Iron Axe")
	game._equip_item("Iron Axe")
	if not _ok(game._gear_attack()>=7,"axe adds attack bonus"):return
	game._record_weapon_proficiency()
	if not _ok(int(game.data["proficiency"]["axe"])==1,"weapon proficiency increases from use"):return
	game.data["inventory"]["Iron Ore"]=2
	game._forge_weapon()
	if not _ok(int(game.data["equipment_upgrades"].get("Iron Axe",0))==1,"forge improves the equipped weapon"):return
	if not _ok(game._save() and game._load_save() and game._equipped("weapon")=="Iron Axe","gear persists on saves"):return
	if not _ok(int(game.data["equipment_upgrades"]["Iron Axe"])==1 and int(game.data["proficiency"]["axe"])==1,"upgrades and skill persist"):return
	game.data["hp"]=21
	game._rest_at_inn()
	if not _ok(int(game.data["hp"])==int(game.data["max_hp"]),"inn heals player"):return
	for klass in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
		game.data["class"]=klass
		game._equip_item("Iron Axe")
		if not _ok(game._equipped("weapon")=="Iron Axe",klass+" gear unrestricted"):return
	print("ADVENTURE ODYSSEY ECONOMY TEST: PASS")
	quit(0)
