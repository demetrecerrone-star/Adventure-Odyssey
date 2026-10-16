extends SceneTree
# Real kill-flow integration, species drops, optional rolls, saving and trade.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,reason:String)->bool:
	if not ok:
		push_error("AO MONSTER LOOT TEST FAILED: "+reason)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("forest",Vector2(430,640))
	await process_frame
	game._dismiss_message()
	if not _check(game.mobs.size()==4,"four starting slimes kept"):return
	var starting_gold:int=int(game.data["gold"])
	var starting_xp:int=int(game.data["xp"])
	var slime:Dictionary=game.mobs[0]
	game._apply_slime_damage(slime,999,true)
	if not _check(not bool(slime["alive"]),"slime defeated"):return
	if not _check(int(game.data["gold"])>=starting_gold+3 and int(game.data["gold"])<=starting_gold+5,"slime grants base 3 gold plus 0-2"):return
	if not _check(int(game.data["xp"])==starting_xp+25,"slime experience unchanged"):return
	if not _check(int(game.data["quest_kills"])==1,"starter quest still advances"):return
	var once_gold:int=int(game.data["gold"])
	var once_inventory:Dictionary=game.data["inventory"].duplicate(true)
	game._apply_slime_damage(slime,999,false)
	if not _check(int(game.data["gold"])==once_gold and game.data["inventory"]==once_inventory,"dead enemy cannot grant duplicate loot"):return
	# The award helper also protects callers; forced rolls test rare branches
	# deterministically while the production kill path uses actual random rolls.
	var sample:Dictionary={"species":"slime","drop":"","loot_claimed":false}
	var before_gel:int=int(game.data["inventory"].get("Slime Gel",0))
	var forced:Dictionary=game._award_monster_loot(sample,{"bonus_gold":2,"Slime Gel":0.0,"Health Potion":1.0})
	if not _check(int(forced["bonus_gold"])==2 and int(forced["items"].get("Slime Gel",0))==1,"forced slime bonus and gel drop"):return
	if not _check(int(game.data["inventory"].get("Slime Gel",0))==before_gel+1,"rolled slime gel reaches backpack"):return
	if not _check(game._award_monster_loot(sample,{"Slime Gel":0.0})["items"].is_empty(),"reward claims are single-use"):return

	game.data["guild_training_completed"]=true
	game.data["level"]=3
	game._enter_world("forest",Vector2(430,640))
	await process_frame
	game._dismiss_message()
	if not _check(game.mobs.size()==7,"three existing advanced forest monsters kept"):return
	var expected:Dictionary={"wolf":"Wolf Pelt","goblin":"Iron Ore","fungus":"Herb"}
	for index in range(4,7):
		var mob:Dictionary=game.mobs[index]
		var kind:String=str(mob["species"])
		var material:String=str(expected.get(kind,""))
		if not _check(material!="","known creature species "+kind):return
		var before:int=int(game.data["inventory"].get(material,0))
		var gold_before:int=int(game.data["gold"])
		game._apply_slime_damage(mob,999,true)
		if not _check(int(game.data["inventory"].get(material,0))>=before+1,kind+" guaranteed material drop"):return
		if not _check(int(game.data["gold"])>=gold_before+int(mob["gold"]),kind+" awards gold"):return
	if not _check(int(game.data["quest_kills"])==1,"advanced monsters do not count for slime quest"):return

	var ore_before:int=int(game.data["inventory"].get("Iron Ore",0))
	var trade_gold:int=int(game.data["gold"])
	game._sell_monster_material("Iron Ore")
	if not _check(int(game.data["inventory"].get("Iron Ore",0))==ore_before-1,"sells exactly one iron ore"):return
	if not _check(int(game.data["gold"])==trade_gold+7,"receives the documented iron ore sale price"):return
	game._sell_monster_material("Training Sword")
	if not _check(int(game.data["gold"])==trade_gold+7,"equipment cannot be sold through material trade-in"):return
	if not _check(game._save() and game._load_save(),"gold and materials survive save/reload"):return
	if not _check(int(game.data["gold"])==trade_gold+7,"saved gold persists"):return

	game._enter_world("sanctum",Vector2(175,650))
	await process_frame
	game._dismiss_message()
	if not _check(game.mobs.size()==1,"existing guardian spawns"):return
	var guardian:Dictionary=game.mobs[0]
	game._apply_slime_damage(guardian,999,true)
	if not _check(bool(game.data.get("guardian_defeated",false)),"one-time guardian progress preserved"):return
	if not _check(int(game.data["inventory"].get("Guardian Relic",0))==1,"unique guardian relic retained"):return
	if not _check(int(game.data["inventory"].get("Ember Shard",0))>=1,"guardian grants ember shard"):return
	game._enter_world("ruins",Vector2(1900,655))
	game._enter_world("sanctum",Vector2(175,650))
	if not _check(game.mobs.is_empty(),"guardian cannot be farmed after completion"):return
	print("ADVENTURE ODYSSEY MONSTER LOOT TEST: PASS / coins, creature items, trade, persistence and unique boss")
	quit(0)
