extends SceneTree
# Town-life milestone: persistent game clock, morning/break/evening NPC routines,
# and interactable shopkeepers in four building interiors.
func _initialize()->void:
    call_deferred("_run")

func _check(ok:bool,reason:String)->bool:
    if not ok:
        push_error("NPC LIFE TEST FAILED: "+reason)
        quit(1)
        return false
    return true

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene._enter_world("town",Vector2(1030,980))
    await process_frame
    if not _check(scene.npcs.size()==3,"only residents not staffed in businesses appear at 9 AM"):return
    if not _check(scene._world_clock_text()=="9:00 AM","new game starts at nine in the morning"):return
    if not _check(scene.clock_label!=null,"in-game clock visible on phone HUD"):return
    if not _check(scene._routine_slot()==0,"morning is working schedule"):return
    scene.data["world_minutes"]=720.0
    scene._tick_town_residents(0.4)
    if not _check(scene.npcs.size()==8,"all eight residents are outside for lunch"):return
    if not _check(scene._routine_slot()==1,"midday routine stage"):return
    if not _check(str(scene.npcs[0]["routine_state"])=="On Break","registrar enters a break state"):return
    var before:Vector2=scene.npcs[0]["node"].position
    for i in range(20):
        scene._tick_town_residents(0.3)
    var after:Vector2=scene.npcs[0]["node"].position
    if not _check(before.distance_to(after)>10.0,"NPC walks along its approved route"):return
    if not _check(scene._walkable(after),"NPC stops on walkable ground"):return
    scene._show_npc_chat(scene.npcs[0])
    await process_frame
    if not _check(scene.popup.mode=="npc" and scene.popup.npc_role.contains("ON BREAK"),"conversation indicates break status"):return
    scene._dismiss_message()
    scene.data["world_minutes"]=1260.0
    scene._tick_town_residents(0.4)
    if not _check(scene._routine_slot()==2 and str(scene.npcs[0]["routine_state"])=="Evening Stroll","evening routine stage"):return
    scene.data["world_minutes"]=600.0
    scene._tick_town_residents(0.4)
    if not _check(scene.npcs.size()==3,"working staff absent from streets"):return
    if not _check(scene._routine_slot()==0 and scene.npcs[0]["routine_state"]=="Working","morning work resumes"):return
    scene._tick_world_time(60.0)
    if not _check(scene._world_clock_text()=="11:30 AM","time advances at the intended rate"):return
    scene._save()
    if not _check(scene._load_save() and scene._world_clock_text()=="11:30 AM","world time survives save/load"):return

    var expected={"guild":2,"market":1,"inn":1,"blacksmith":1}
    for building in expected.keys():
        scene._enter_world(building,Vector2(1030,980))
        await process_frame
        if not _check(scene.npcs.size()==int(expected[building]),"building staffed: "+building):return
        var resident=scene.npcs[0]
        scene.player.position=resident["node"].position+Vector2(25,12)
        scene._interact()
        await process_frame
        if not _check(scene.popup!=null and scene.popup.mode=="npc","shopkeeper conversation accessible: "+building):return
        if not _check(scene.popup.npc_name==resident["name"],"correct named worker: "+building):return
        scene._dismiss_message()
        if building=="guild":
            # Captain Elara should register training inside the Guild, too.
            scene.data["quest_kills"]=3
            scene.player.position=scene.npcs[1]["node"].position+Vector2(28,12)
            scene._interact()
            await process_frame
            if not _check(bool(scene.data.get("guild_training_completed",false)),"guild training can complete inside"):return
            if not _check(scene.popup.mode=="npc" and scene.popup.body_label.text.contains("training assignment is complete"),"completion dialogue appears"):return
            scene._dismiss_message()
            scene._save()
            if not _check(scene._load_save() and bool(scene.data.get("guild_training_completed",false)),"guild quest completion persists"):return
        scene.player.position=Vector2(1024,1090)
        scene._interact()
        await process_frame
        if not _check(scene.current_map=="town" and scene.npcs.size()==3,"return from "+building+" restores town"):return

    # The village healer still restores HP and speaks with the player.
    scene.data["hp"]=32
    scene.player.position=scene.npcs[1]["node"].position+Vector2(28,12)
    scene._interact()
    await process_frame
    if not _check(int(scene.data["hp"])==int(scene.data["max_hp"]),"town healer restores health"):return
    if not _check(scene.popup.mode=="npc","healer conversation appears"):return
    scene._dismiss_message()
    scene._enter_world("bedroom",scene.BEDROOM_SPAWN)
    await process_frame
    if not _check(scene.bedroom_art!=null,"starter bedroom and interactable furniture unaffected"):return
    print("ADVENTURE ODYSSEY NPC LIFE TEST: PASS")
    quit(0)
