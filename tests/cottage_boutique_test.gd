extends SceneTree
# End-to-end working cottage boutique regression on actual rendered art.
func _initialize()->void:
    call_deferred("_run")

func _ok(value:bool,what:String)->bool:
    if not value:
        push_error("AO COTTAGE BOUTIQUE TEST FAILED: "+what)
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
    var room=game.bedroom_art
    var gold:int=int(game.data["gold"])
    for slot in ["Bed","Mirror","Chest"]:
        if not _ok(game.data["home_styles"][slot]==game.HOME_STARTER[slot],"free starter visible "+slot):return
        if not _ok(room.get_node(slot).texture!=null,"original furniture visible "+slot):return
    game._open_home_decor()
    await process_frame
    if not _ok(game.popup!=null and game.popup.name=="CottageDecorMenu","existing collection menu preserved"):return
    game._open_cottage_piece_boutique()
    await process_frame
    if not _ok(game.popup!=null and game.popup.get_node_or_null("StylePreview_Bed")!=null,"shop accessible through chest"):return
    for slot in ["Bed","Mirror","Chest"]:
        var preview=game.popup.get_node_or_null("StylePreview_"+slot) as TextureRect
        if not _ok(preview!=null and preview.texture!=null,"real new transparent sprite preview "+slot):return
    game._cottage_boutique_buy("Bed","royal_blue")
    if not _ok(game._sigils_balance()==0 and game.data["home_styles"]["Bed"]=="oak_green","shop refuses purchase with zero Sigils"):return
    game._award_sigils(100)
    var expected:Dictionary={"Bed":["royal_blue",30],"Mirror":["sunburst_gold",20],"Chest":["moonstone_trim",25]}
    for slot in ["Bed","Mirror","Chest"]:
        var variant:String=str(expected[slot][0])
        var price:int=int(expected[slot][1])
        var before:int=game._sigils_balance()
        game._cottage_boutique_buy(slot,variant)
        if not _ok(game._sigils_balance()==before-price,"exact purchase amount "+slot):return
        if not _ok(game.data["home_owned"][slot].has(variant),"cosmetic owned permanently "+slot):return
        if not _ok(game.data["home_styles"][slot]==variant,"cosmetic equipped "+slot):return
        if not _ok(room.get_node(slot).texture.resource_path.ends_with(variant+".png"),"actual furniture displays selected art "+slot):return
    if not _ok(int(game.data["gold"])==gold,"cosmetic purchases never deduct gold"):return
    if not _ok(game._sigils_balance()==25,"75 Sigils spent on three styles"):return
    game._cottage_boutique_starter("Bed")
    if not _ok(game.data["home_styles"]["Bed"]=="oak_green" and game.data["home_owned"]["Bed"].has("royal_blue"),"starter bed can be restored without losing purchase"):return
    var balance:int=game._sigils_balance()
    game._cottage_boutique_buy("Bed","royal_blue")
    if not _ok(game._sigils_balance()==balance and game.data["home_styles"]["Bed"]=="royal_blue","owned cosmetics equip for free"):return
    game._cottage_boutique_buy("Chest","not_owned")
    if not _ok(game._sigils_balance()==balance,"unknown catalog entry cannot spend"):return
    game._save()
    if not _ok(game._load_save(),"cottage styles survive save/load"):return
    if not _ok(game._sigils_balance()==25 and game.data["home_styles"]["Mirror"]=="sunburst_gold","saved ownership and chosen styles persist"):return
    game._enter_world("bedroom",game.BEDROOM_SPAWN)
    await process_frame
    if not _ok(game.bedroom_art.get_node("Chest").texture.resource_path.ends_with("moonstone_trim.png"),"cottage cosmetic art reapplied on room reentry"):return
    game._open_home_chest()
    if not _ok(game.popup!=null,"storage chest remains operational"):return
    game._dismiss_message()
    game._open_home_mirror()
    if not _ok(game.popup!=null,"mirror appearance editor remains operational"):return
    for slot in ["Bed","Mirror","Chest"]:
        if not _ok(game.data["home_owned"][slot].has(game.HOME_STARTER[slot]),"permanent free starter "+slot):return
    print("ADVENTURE ODYSSEY COTTAGE BOUTIQUE TEST: PASS / 3 transparent variants, buy, equip, restore, storage, mirror, saves")
    quit(0)
