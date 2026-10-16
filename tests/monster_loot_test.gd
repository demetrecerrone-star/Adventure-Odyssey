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
	# Independent, first-kill RNG for rare equipment; NOT currency from field mobs.
	var before_sigils:int=game._sigils_balance()
	var rare_slime:Dictionary={"species":"slime","drop":"","loot_claimed":false}
	var rare_reward:Dictionary=game._award_monster_loot(rare_slime,{"sigil_roll":0.0,"Slime Core Charm":0.0,"Slime Gel":1.0,"Health Potion":1.0})
	if not _check(int(rare_reward["sigils"])==0 and game._sigils_balance()==before_sigils,"slimes cannot give Sigils, even with a perfect roll"):return
	if not _check(int(rare_reward["items"].get("Slime Core Charm",0))==1,"0.25-percent charm can drop on first roll"):return
	if not _check(game._gear_def("Slime Core Charm").get("slot","")=="accessory","rare drop uses existing equippable item"):return
	var rare_repeat:Dictionary=game._award_monster_loot(rare_slime,{"sigil_roll":0.0,"Slime Core Charm":0.0})
	if not _check(int(rare_repeat["sigils"])==0 and rare_repeat["items"].is_empty() and game._sigils_balance()==before_sigils,"rare equipment cannot be duplicated"):return
	var no_luck:Dictionary=game._award_monster_loot({"species":"slime","drop":"","loot_claimed":false},{"sigil_roll":1.0,"Slime Core Charm":1.0,"Slime Gel":1.0,"Health Potion":1.0})
	if not _check(int(no_luck["sigils"])==0 and no_luck["items"].is_empty(),"no hidden guaranteed rare reward or pity threshold"):return
	# Boss Sigils can roll on first clear but are never automatic.
	var boss_winner:Dictionary={"species":"guardian","drop":"","loot_claimed":false}
	var boss_lucky:Dictionary=game._award_monster_loot(boss_winner,{"sigil_roll":0.0,"Ember Pendant":1.0})
	if not _check(int(boss_lucky["sigils"])==5 and game._sigils_balance()==before_sigils+5,"boss-only 10-percent roll awards five Sigils"):return
	var repeat_reward:Dictionary=game._award_monster_loot(boss_winner,{"sigil_roll":0.0})
	if not _check(int(repeat_reward["sigils"])==0 and game._sigils_balance()==before_sigils+5,"same guardian cannot issue currency twice"):return
	var boss_unlucky:Dictionary=game._award_monster_loot({"species":"guardian","drop":"","loot_claimed":false},{"sigil_roll":1.0,"Ember Pendant":1.0})
	if not _check(int(boss_unlucky["sigils"])==0 and game._sigils_balance()==before_sigils+5,"boss Sigils are not guaranteed"):return
	for normal_species in ["slime","wolf","goblin","fungus"]:
		if not _check(float(game.MONSTER_LOOT_PROFILES[normal_species]["sigil_chance"])==0.0,"no ordinary monster Sigil chance: "+normal_species):return

	# Check each existing enemy's tiny probability produces real catalog loot.
	var rare_items:Dictionary={"slime":"Slime Core Charm","wolf":"Forest Fang","goblin":"Guard Sigil","fungus":"Wisdom Bead","guardian":"Ember Pendant"}
	for species in rare_items.keys():
		var rare_item:String=str(rare_items[species])
		var table:Dictionary=game.MONSTER_LOOT_PROFILES[species]
		var probability:float=0.0
		for entry in table["rolls"]:
			if str(entry[0])==rare_item:probability=float(entry[1])
		if not _check(probability>0.0 and probability<=0.03,"rare item has nonzero small per-kill chance: "+str(species)):return
		if not _check(not game._gear_def(rare_item).is_empty(),"rare drop matches existing catalog: "+rare_item):return
		var fixed_rolls:Dictionary={"sigil_roll":1.0}
		fixed_rolls[rare_item]=0.0
		var forced_rare:Dictionary=game._award_monster_loot({"species":species,"loot_claimed":false,"drop":""},fixed_rolls)
		if not _check(int(forced_rare["items"].get(rare_item,0))==1,"rare reward reachable with winning roll: "+str(species)):return


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
