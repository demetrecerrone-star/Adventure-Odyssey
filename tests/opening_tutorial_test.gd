extends SceneTree
# Complete first-day path, one bedroom, NPC and saved milestones; no Android export.
func _initialize()->void:
    call_deferred("_run")

func _ok(value:bool,what:String)->bool:
    if not value:
        push_error("OPENING TUTORIAL TEST FAILED: "+what)
        quit(1)
        return false
    return true

func _run()->void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    game._open_creator()
    game.char_input.text="Tutorial Review"
    game._create_character()
    await process_frame
    if not _ok(game.current_map=="bedroom" and game.popup!=null and game.popup.mode=="tutorial","new game starts in bedroom with journal"):return
    if not _ok(game.popup.pages.size()==4 and game.popup.pages[3].contains("living room and kitchen"),"prologue introduces approved house"):return
    game._complete_intro_tutorial()
    if not _ok(game.hint_label.text.contains("chest"),"first contextual hint points to storage"):return
    game._open_home_chest()
    if not _ok(game.data["tutorial_actions"].get("chest_opened",false),"storage milestone"):return
    game._dismiss_message()
    game._open_home_mirror()
    if not _ok(game.data["tutorial_actions"].get("mirror_opened",false),"mirror milestone"):return
    game._mirror_cancel()
    if not _ok(game.hint_label.text.contains("bed"),"next hint suggests bedroom rest or doorway"):return
    game.player.position=Vector2(1024,996)
    game._interact()
    await process_frame
    if not _ok(game.current_map=="foyer" and game.data["tutorial_actions"].get("foyer_seen",false),"bedroom connects to foyer"):return
    game.player.position=Vector2(470,705)
    game._interact()
    await process_frame
    if not _ok(game.current_map=="living" and game.data["tutorial_actions"].get("living_seen",false),"living/kitchen reached"):return
    if not _ok(game._walkable(game.player.position),"living spawn reachable"):return
    game.player.position=Vector2(1513,846)
    if not _ok(game._house_target()=="Pantry","pantry marked against painted art"):return
    game._interact()
    if not _ok(game.data["tutorial_actions"].get("pantry_found",false),"pantry use remembered"):return
    game.player.position=Vector2(1024,1060)
    game._interact()
    await process_frame
    if not _ok(game.current_map=="foyer","living returns to foyer"):return
    game.player.position=Vector2(1024,1082)
    game._interact()
    await process_frame
    if not _ok(game.current_map=="town" and game.data["tutorial_actions"].get("elmwatch_seen",false),"front door reaches Elmwatch"):return
    game._dismiss_message()
    if not _ok(game.hint_label.text.contains("Guild"),"guild guidance visible"):return
    game.player.position=game.ELMWATCH_DOORS["guild"]
    game._interact()
    await process_frame
    if not _ok(game.current_map=="guild" and game.data["tutorial_actions"].get("guild_entered",false),"guild entrance recorded"):return
    if not _ok(game.npcs.size()==2,"two named guild workers already present"):return
    game._show_npc_chat(game.npcs[0])
    if not _ok(game.data["tutorial_actions"].get("registrar_spoken",false),"guild registrar conversation stored"):return
    game._dismiss_message()
    game._save()
    if not _ok(game._load_save() and game.data["tutorial_actions"].get("pantry_found",false),"milestones survive a reload"):return
    print("ADVENTURE ODYSSEY OPENING TUTORIAL TEST: PASS")
    quit(0)
