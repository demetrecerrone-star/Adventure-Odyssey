extends SceneTree
# Test the actual Godot bedroom sprites and no-double-charge gold unlocks.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,message:String)->bool:
	if not ok:
		push_error("AO GOLD COTTAGE SHOP TEST FAILED: "+message)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("bedroom",game.BEDROOM_SPAWN)
	await process_frame
	for slot in ["Bed","Mirror","Chest"]:
		if not _check(game.data["home_styles"][slot]==game.HOME_STARTER[slot],"starter furnished: "+slot):return
		if not _check(game.data["home_owned"][slot].has(game.HOME_STARTER[slot]),"starter permanently owned: "+slot):return
		if not _check(ResourceLoader.exists(game._cottage_gold_asset(slot)),"new pixel style exists: "+slot):return
	game._open_cottage_collections()
	if not _check(game.popup.find_children("*","Button",true,false).size()>0,"existing Sigil collections remain accessible"):return
	game._open_cottage_gold_shop()
	if not _check(game.popup.name=="CottageGoldShop","gold furnishing menu opened from existing cottage"):return
	var gold_before:int=int(game.data["gold"])
	if not _check(not game._cottage_gold_buy("Bed") and int(game.data["gold"])==gold_before,"insufficient gold never charges"):return
	if not _check(not game._cottage_gold_buy("Paint") and not game._cottage_gold_equip("Paint"),"invalid decor category rejected"):return
	game.data["gold"]=100
	var total_price:int=0
	for slot in ["Bed","Mirror","Chest"]:
		var price:int=int(game.COTTAGE_GOLD_ITEMS[slot]["price"])
		total_price+=price
		if not _check(game._cottage_gold_buy(slot),"first purchase works: "+slot):return
		if not _check(game._cottage_gold_owned(slot),"purchased piece owned: "+slot):return
		var sprite=game.bedroom_art.get_node(slot) as Sprite2D
		if not _check(sprite!=null and sprite.texture!=null and sprite.texture.resource_path==game._cottage_gold_asset(slot),"actual equipped transparent sprite visible: "+slot):return
		if not _check(game._cottage_gold_buy(slot),"already-owned piece re-equips for free: "+slot):return
	if not _check(int(game.data["gold"])==100-total_price,"all three charged exactly once"):return
	if not _check(str(game.data["cottage_active_tier"])=="custom","mixed gold room mode active"):return
	if not _check(game._save() and game._load_save(),"save reload succeeded"):return
	if not _check(str(game.data["cottage_active_tier"])=="custom","custom mode persists after load"):return
	for slot in ["Bed","Mirror","Chest"]:
		if not _check(game._cottage_gold_owned(slot),"ownership persists after load: "+slot):return
		if not _check(game.data["home_styles"][slot]==game.COTTAGE_GOLD_ITEMS[slot]["variant"],"selection persists after load: "+slot):return
	game._enter_world("bedroom",game.BEDROOM_SPAWN)
	await process_frame
	for slot in ["Bed","Mirror","Chest"]:
		var sprite=game.bedroom_art.get_node(slot) as Sprite2D
		if not _check(sprite.texture.resource_path==game._cottage_gold_asset(slot),"recreated room uses saved sprite: "+slot):return
	game._ensure_cosmetic_categories()
	if not _check(game.data["cosmetic_owned"].has("outfits") and game.data["cosmetic_owned"].has("accessories"),"future non-combat cosmetic slots reserved"):return
	game._save()
	if not _check(game._load_save() and game.data["cosmetic_equipped"].has("outfits"),"future cosmetics scaffold survives save"):return
	if not _check(game._cottage_equip("starter"),"starter set can always be restored"):return
	if not _check(game._cottage_gold_equip("Chest"),"already-owned chest can be restored separately"):return
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	if not _check(not game._cottage_gold_buy("Bed") and not game._cottage_gold_equip("Mirror"),"home-only purchase and equip enforced"):return
	print("ADVENTURE ODYSSEY COTTAGE GOLD SHOP TEST: PASS / 3 unique art pieces / buy-equip / no double charge / persistence")
	quit(0)
