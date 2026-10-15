extends SceneTree
# Approved art and building travel: NPCs and existing home tutorial remain intact.
func _initialize()->void:
    call_deferred("_run")

func _check(ok:bool, label:String)->bool:
    if not ok:
        push_error("ELMWATCH VISUAL TEST FAILED: "+label)
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
    var town_art=scene.world.get_node_or_null("MapArtwork") as Sprite2D
    if not _check(town_art!=null and town_art.texture!=null,"town background is an imported texture"):return
    if not _check(town_art.texture.resource_path.ends_with("elmwatch_village_new.jpg"),"new approved town picture is active"):return
    if not _check(town_art.scale.x>0.0 and town_art.scale.y>0.0,"art is scaled to game-space"):return
    if not _check(scene.npcs.size()==8,"existing NPC population preserved"):return
    if not _check(scene.world.get_node_or_null("BuildingMarkers")!=null,"town signposts generated"):return

    for building in ["guild","market","inn","blacksmith"]:
        if not _check(scene._walkable(scene.ELMWATCH_DOORS[building]),"building entry reachable: "+building):return
        scene.player.position=scene.ELMWATCH_DOORS[building]
        if not _check(scene._nearest_building_entry()==building,"entrance detects "+building):return
        scene._interact()
        await process_frame
        if not _check(scene.current_map==building and scene.npcs.size()==(2 if building=="guild" else 1),"entered "+building):return
        var interior=scene.world.get_node_or_null("MapArtwork") as Sprite2D
        if not _check(interior!=null and interior.texture!=null,"interior loaded: "+building):return
        if not _check(interior.texture.resource_path==str(scene.BUILDING_ART[building]),"correct interior image: "+building):return
        if not _check(scene._walkable(Vector2(1024,1090)),"exit area walkable: "+building):return
        scene.player.position=Vector2(1024,1090)
        scene._interact()
        await process_frame
        if not _check(scene.current_map=="town" and scene.npcs.size()==8,"returns to town and restores NPCs: "+building):return
        if not _check(scene.player.position==scene.ELMWATCH_DOORS[building],"returns to original door: "+building):return

    scene.player.position=Vector2(540,1095)
    scene._interact()
    await process_frame
    if not _check(scene.current_map=="cottage" and scene.cottage_art!=null,"starter cottage remains reachable"):return
    print("ADVENTURE ODYSSEY ELMWATCH VISUAL TEST: PASS")
    quit(0)
