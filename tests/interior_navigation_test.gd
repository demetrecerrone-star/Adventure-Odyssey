extends SceneTree
# Painted building interiors must have real gameplay collisions and talkable staff.
func _initialize()->void:
    call_deferred("_run")

func _verify(ok:bool,reason:String)->bool:
    if not ok:
        push_error("INTERIOR NAVIGATION TEST FAILED: "+reason)
        quit(1)
        return false
    return true

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene.data["world_minutes"]=540.0
    var blocked={
        "guild":Vector2(1010,650),
        "market":Vector2(1040,495),
        "inn":Vector2(1475,600),
        "blacksmith":Vector2(1430,765)
    }
    var expected={"guild":2,"market":1,"inn":1,"blacksmith":1}
    for building in ["guild","market","inn","blacksmith"]:
        scene._enter_world(building,Vector2(1024,980))
        await process_frame
        if not _verify(scene.npcs.size()==expected[building],"staff on shift: "+building):return
        if not _verify(scene._walkable(Vector2(1024,980)) and scene._walkable(Vector2(1024,1090)),"entry and exit unobstructed: "+building):return
        if not _verify(not scene._walkable(blocked[building]),"painted counter obstructs walking: "+building):return
        var person=scene.npcs[0]
        if not _verify(scene._walkable(person["node"].position),"NPC stands in reachable walkable area: "+building):return
        var spot:Vector2=person["node"].position+Vector2(24,20)
        if not _verify(scene._walkable(spot),"approach to staff not blocked: "+building):return
        scene.player.position=spot
        scene._interact()
        await process_frame
        if not _verify(scene.popup!=null and scene.popup.mode=="npc","staff conversation accessible: "+building):return
        scene._dismiss_message()
        scene.player.position=Vector2(1024,1090)
        scene._interact()
        await process_frame
        if not _verify(scene.current_map=="town" and scene.npcs.size()==3,"building returns to scheduled town: "+building):return
    scene._enter_world("bedroom",scene.BEDROOM_SPAWN)
    await process_frame
    if not _verify(scene.bedroom_art!=null,"starter bedroom unaffected"):return
    print("ADVENTURE ODYSSEY INTERIOR NAVIGATION TEST: PASS")
    quit(0)
