extends SceneTree
# Persistent premium-style currency, actual AO icon and art-safe home ownership.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,what:String)->bool:
	if not ok:
		push_error("AO SIGILS CURRENCY TEST FAILED: "+what)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	if not _check(game._sigils_balance()==0,"new character has zero Sigils"):return
	var original_gold:int=int(game.data["gold"])
	game._enter_world("bedroom",game.BEDROOM_SPAWN)
	await process_frame
	if not _check(game.hud.get_node_or_null("OdysseySigilCoin")!=null,"AO coin visible on HUD"):return
	if not _check(game.sigils_hud_label!=null and game.sigils_hud_label.text.contains("Sigils"),"Sigil balance visible on HUD"):return
	game._award_sigils(7)
	if not _check(game._sigils_balance()==7 and int(game.data["gold"])==original_gold,"Sigils earned separately from gold"):return
	if not _check(not game._spend_sigils(8) and game._sigils_balance()==7,"cannot overspend Sigils"):return
	if not _check(game._spend_sigils(5) and game._sigils_balance()==2,"spending Sigils deducts exact amount"):return
	if not _check(not game._spend_sigils(-1) and game._sigils_balance()==2,"negative price cannot mint currency"):return
	game._save()
	if not _check(game._load_save() and game._sigils_balance()==2,"Sigil balance survives save/load"):return
	if not _check(int(game.data["gold"])==original_gold,"gold unchanged by Sigil spending"):return
	game._ensure_home_styles()
	for slot in ["Bed","Mirror","Chest"]:
		if not _check(game.data["home_owned"][slot].has(game.HOME_STARTER[slot]),"free starter furniture intact: "+slot):return
		if not _check(game.data["home_styles"][slot]==game.HOME_STARTER[slot],"starter furniture stays equipped: "+slot):return
	var balance:int=game._sigils_balance()
	if not _check(not game._buy_sigil_cottage_style("Bed","royal_blue"),"unreleased home style cannot charge for missing artwork"):return
	if not _check(game._sigils_balance()==balance,"unreleased cosmetic doesn't debit currency"):return
	if not _check(not game._buy_sigil_cottage_style("Bed","not_a_style"),"invalid cosmetic cannot be purchased"):return
	if not _check(not game._buy_sigil_cottage_style("Other","royal_blue"),"unregistered furniture slot rejected"):return
	if not _check(ResourceLoader.exists("res://assets/ui/odyssey_sigil.svg"),"AO currency icon asset exists"):return
	# Simulate an older save without the new currency key.
	game.data.erase("sigils")
	game._save()
	if not _check(game._load_save() and game._sigils_balance()==0,"old saves load with safe zero Sigils"):return
	game._open_home_decor()
	if not _check(game.popup.get_node_or_null("OdysseySigilCoin")!=null,"coin also appears in cottage styling"):return
	print("ADVENTURE ODYSSEY SIGILS CURRENCY TEST: PASS / AO coin, balances, save compatibility and free starter furniture")
	quit(0)
