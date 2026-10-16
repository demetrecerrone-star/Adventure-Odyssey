extends SceneTree
# All three gender-neutral choices (Queen, King and Unisex) belong to ONE tier purchase.
func _initialize()->void:
    call_deferred("_run")

func _ok(value:bool,detail:String)->bool:
    if not value:
        push_error("COTTAGE COLLECTIONS TEST FAILED: "+detail)
        quit(1)
        return false
    return true

func _has_button(root_node:Node,title:String)->bool:
    for n in root_node.find_children("*","Button",true,false):
        if str(n.text)==title:return true
    return false

func _run()->void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    game._random_default()
    game._enter_world("bedroom",game.BEDROOM_SPAWN)
    await process_frame
    if not _ok(_has_button(game.hud,"DECOR"),"bedroom-only AO Decor control"):return
    if not _ok(game._cottage_collection_owned("starter"),"starter is free and permanent"):return
    if not _ok(game.data["cottage_active_tier"]=="starter","original furniture remains equipped"):return
    for slot in ["Bed","Mirror","Chest"]:
        if not _ok(game.data["home_styles"][slot]==game.HOME_STARTER[slot],"preserved original sprite: "+slot):return
    game._open_cottage_collections("noble","feminine")
    if not _ok(game.popup.name=="CottageDecorMenu" and game.popup.get_node_or_null("OdysseySigilCoin")!=null,"AO coin opens decorated menu"):return
    # UI regression: furniture thumbnails and Sigil coin must stay inside compact
    # phone-scale rectangles, not expand to full imported SVG dimensions.
    var previews:int=0
    for node in game.popup.find_children("*","TextureRect",true,false):
        var image:=node as TextureRect
        if image==null:continue
        if not _ok(image.size.x<=150.0 and image.size.y<=150.0,"art/coin remains inside its menu slot: "+image.name):return
        if image.name!="OdysseySigilCoin":previews+=1
    if not _ok(previews>=7,"four tiers plus three matching furniture previews render"):return
    if not _ok(_has_button(game.popup,"GOLD FURNITURE"),"Sigil store links to independent earned-gold store"):return
    for key in ["noble","castle","royal"]:
        if not _ok(game._cottage_tier_art_ready(key),"all 9 real transparent illustrated sprites present in "+key):return
    if not _ok(game.COTTAGE_COLLECTION_TIERS["noble"]["price"]==30 and game.COTTAGE_COLLECTION_TIERS["castle"]["price"]==60 and game.COTTAGE_COLLECTION_TIERS["royal"]["price"]==120,"three progressively priced whole-set bundles"):return
    game._award_sigils(29)
    if not _ok(not game._cottage_buy_tier("noble") and game._sigils_balance()==29,"insufficient funds never unlock or charge"):return
    game._award_sigils(1)
    var gold_before:int=int(game.data["gold"])
    if not _ok(game._cottage_buy_tier("noble"),"30-Sigil first set purchased with quest reward amount"):return
    if not _ok(game._sigils_balance()==0 and int(game.data["gold"])==gold_before,"single bundle cost, gold unaffected"):return
    if not _ok(game._cottage_collection_owned("noble") and game.data["cottage_active_tier"]=="noble","bundle owned and initially equipped"):return
    if not _ok(not game._cottage_buy_tier("noble") and game._sigils_balance()==0,"no repeat charge on already-owned set"):return
    # Three distinct appearance styles are freely selectable under the one purchased icon.
    for style in ["feminine","masculine","unisex"]:
        if not _ok(game._cottage_equip("noble",style),"owned set style equips: "+style):return
        for slot in ["Bed","Mirror","Chest"]:
            var variant:String="collection_noble_"+style
            if not _ok(game.data["home_styles"][slot]==variant and game.data["home_owned"][slot].has(variant),"entire matching trio equipped: "+style+"/"+slot):return
            var node=game.bedroom_art.get_node(slot) as Sprite2D
            if not _ok(node.texture!=null and node.texture.resource_path.contains("/collections/noble/"+style+"/"+slot.to_lower()+".svg"),"real sprite rendered: "+slot):return
        if not _ok(game._sigils_balance()==0,"switching styles always free"):return
    game._open_cottage_collections("castle","masculine")
    if not _ok(_has_button(game.popup,"BUY"),"unowned complete tier displays BUY"):return
    if not _ok(game._cottage_equip("castle","masculine")==false,"locked set cannot equip"):return
    game._award_sigils(60)
    if not _ok(game._cottage_buy_tier("castle") and game._sigils_balance()==0,"castle tier costs 60 once for all three styles"):return
    if not _ok(game._cottage_equip("castle","masculine"),"castle's King's Hall theme is included"):return
    game._award_sigils(120)
    if not _ok(game._cottage_buy_tier("royal") and game._sigils_balance()==0,"royal tier costs 120 for all three styles"):return
    if not _ok(game._cottage_equip("royal","feminine"),"spectacular Queen's Chamber available"):return
    game._open_cottage_collections("royal","feminine")
    if not _ok(not _has_button(game.popup,"BUY") and _has_button(game.popup,"EQUIP"),"owned set buttons change from BUY to EQUIP"):return
    if not _ok(game._save() and game._load_save(),"bundle state persisted"):return
    if not _ok(game.data["cottage_tiers_owned"].has("noble") and game.data["cottage_tiers_owned"].has("castle") and game.data["cottage_tiers_owned"].has("royal"),"three bundles survive load"):return
    if not _ok(game.data["cottage_active_tier"]=="royal" and game.data["cottage_style_choices"]["royal"]=="feminine","selection survives load"):return
    if not _ok(game._cottage_equip("starter") and game.data["home_styles"]["Bed"]=="oak_green","original starter furniture always re-equippable"):return
    if not _ok(game._cottage_equip("noble","masculine") and game._sigils_balance()==0,"already-purchased bundles are permanently free to switch"):return
    game._enter_world("town",Vector2(1030,980))
    await process_frame
    if not _ok(not _has_button(game.hud,"DECOR"),"AO Decor control hidden outside bedroom"):return
    if not _ok(not game._cottage_buy_tier("noble") and not game._cottage_equip("royal","unisex"),"bedroom-only actions enforced"):return
    print("ADVENTURE ODYSSEY COTTAGE COLLECTIONS TEST: PASS / 3 tiers x 3 real styles / 30 60 120 / one buy then free equip / saved")
    quit(0)
