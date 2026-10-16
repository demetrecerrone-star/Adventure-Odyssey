extends SceneTree
# First Guild training: voluntary quest offer, combat basics, one-time reward,
# save/load, level-up/free stats and backward-compatible pre-quest kills.
func _initialize()->void:
    call_deferred("_run")

func _ok(v:bool,what:String)->bool:
    if not v:
        push_error("GUILD TRAINING TEST FAILED: "+what)
        quit(1)
        return false
    return true

func _run()->void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    game._random_default()
    game.data["world_minutes"]=540.0
    game._enter_world("guild",Vector2(1030,980))
    await process_frame
    if not _ok(game.npcs.size()==2,"both established guild workers staffed"):return
    if not _ok(not bool(game.data.get("slime_training_accepted",false)),"quest not auto-accepted"):return
    var mentor=game.npcs[1]
    if not _ok(mentor["name"]=="Captain Elara Voss","mentor is Captain Elara"):return
    game._interact_resident(mentor)
    await process_frame
    if not _ok(game.popup!=null and game.popup.mode=="npc","quest offer is NPC dialogue"):return
    if not _ok(game.popup.quest_accept_callback.is_valid(),"explicit ACCEPT QUEST action appears"):return
    if not _ok(not bool(game.data.get("slime_training_accepted",false)),"talking alone does not accept task"):return
    game.popup._on_primary()
    await process_frame
    if not _ok(game.popup.quest_accept_callback.is_valid(),"quest acceptance remains on advice page"):return
    game.popup._on_secondary()
    await process_frame
    if not _ok(not bool(game.data.get("slime_training_accepted",false)),"declining offer has no side effects"):return
    game._interact_resident(mentor)
    game.popup._accept_quest_pressed()
    await process_frame
    if not _ok(bool(game.data.get("slime_training_accepted",false)),"offer acceptance saved"):return
    if not _ok(game.popup.mode=="tutorial" and game.popup.pages.size()==5,"accepted quest shows journal instructions"):return
    if not _ok(game.hint_label.text.contains("Field assignment"),"guild guidance reflects accepted quest"):return
    game._dismiss_message()
    game._enter_world("forest",Vector2(430,640))
    await process_frame
    if not _ok(game.mobs.size()==4,"existing four green slimes preserved"):return
    if not _ok(game.popup!=null and game.popup.mode=="tutorial","forest first-visit combat journal shown"):return
    if not _ok(game.popup.pages.size()==4 and game.popup.pages[0].contains("ATTACK"),"combat instructions explain attack"):return
    if not _ok(game.data.get("forest_combat_intro_seen",false),"combat intro once per save"):return
    game._dismiss_message()
    var gold_before:int=int(game.data["gold"])
    var potions_before:int=int(game.data["inventory"].get("Health Potion",0))
    for i in range(3):
        var slime=game.mobs[i]
        game.player.position=slime["node"].position+Vector2(43,12)
        if not _ok(slime["alive"] and int(slime["hp"])==35,"slime spawned at full HP"):return
        for strike in range(3):
            game.attack_cooldown=0.0
            var was_hp:int=int(slime["hp"])
            game._attack()
            if not _ok(int(slime["hp"])<was_hp,"ATTACK deals damage"):return
            if strike==0 and i==0:
                var after_hit:int=int(slime["hp"])
                game._attack()
                if not _ok(int(slime["hp"])==after_hit,"short attack cooldown prevents double hits"):return
        if not _ok(not slime["alive"],"slime can be defeated exactly once"):return
        if not _ok(int(game.data["quest_kills"])==i+1,"quest counts slain slimes"):return
        if i<2 and not _ok(game.popup==null,"normal slimes do not interrupt play"):return
    if not _ok(int(game.data["level"])>=2 and int(game.data["points"])>=5,"existing level-up and five free points preserved"):return
    if not _ok(game.popup!=null and game.popup.mode=="tutorial","third kill prompts return to Guild"):return
    if not _ok(game.popup.chapter.contains("ASSIGNMENT COMPLETE"),"mission completion is clear"):return
    if not _ok(game.hp_label.text.contains("Slimes: 3/3"),"quest HUD never exceeds three"):return
    game._dismiss_message()
    var gold_earned_from_slimes:int=int(game.data["gold"])
    var potions_after_slimes:int=int(game.data["inventory"].get("Health Potion",0))
    if not _ok(gold_earned_from_slimes>=gold_before+9 and gold_earned_from_slimes<=gold_before+15,"slimes retain base gold and optional coin bonuses"):return
    game._enter_world("guild",Vector2(1030,980))
    await process_frame
    mentor=game.npcs[1]
    game._interact_resident(mentor)
    await process_frame
    if not _ok(bool(game.data.get("guild_training_completed",false)),"Guild captain awards completion"):return
    if not _ok(game._sigils_balance()==5,"one-time Guild completion grants five Sigils"):return
    if not _ok(int(game.data["gold"])==gold_earned_from_slimes+20,"guild pays exactly 20 gold beyond all monster coins"):return
    if not _ok(int(game.data["inventory"].get("Health Potion",0))==potions_after_slimes+1,"one quest potion beyond potential monster drops"):return
    if not _ok(game.popup.mode=="npc" and game.popup.body_label.text.contains("training assignment is complete"),"completion uses established NPC dialogue"):return
    game._dismiss_message()
    game._interact_resident(mentor)
    if not _ok(int(game.data["gold"])==gold_earned_from_slimes+20 and int(game.data["inventory"].get("Health Potion",0))==potions_after_slimes+1,"repeated Captain conversation cannot duplicate rewards"):return
    if not _ok(game._sigils_balance()==5,"repeated Guild dialogue cannot repeat Sigil reward"):return
    if not _ok(game.hp_label.text.contains("Guild: DONE"),"completed mission visible on HUD"):return
    game._dismiss_message()
    game._save()
    if not _ok(game._load_save() and bool(game.data.get("slime_training_accepted",false)) and bool(game.data.get("guild_training_completed",false)),"quest state survives reload"):return
    game._random_default()
    game.data["quest_kills"]=3
    game._enter_world("guild",Vector2(1030,980))
    await process_frame
    if not _ok(not bool(game.data.get("slime_training_accepted",false)),"old saves can have kills without accepted flag"):return
    game._interact_resident(game.npcs[1])
    if not _ok(bool(game.data.get("guild_training_completed",false)),"legacy 3/3 save can still claim Guild reward"):return
    game._dismiss_message()
    game._enter_world("bedroom",game.BEDROOM_SPAWN)
    if not _ok(game.bedroom_art!=null and game.house_art==null,"single-bedroom cottage remains intact"):return
    print("ADVENTURE ODYSSEY GUILD TRAINING TEST: PASS")
    quit(0)
