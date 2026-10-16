extends SceneTree
# Regression test for exact rendered map art, encounter clearings, and safe exits.
func _initialize()->void:
    call_deferred("_run")

func _check(ok:bool,label:String)->bool:
    if not ok:
        push_error("FOREST BACKGROUND TEST FAILED: "+label)
        quit(1)
        return false
    return true

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene._enter_world("forest",Vector2(120,655))
    await process_frame
    var art=scene.world.get_node_or_null("MapArtwork") as Sprite2D
    if not _check(art!=null and art.texture!=null,"painted forest map loads"):return
    if not _check(art.texture.resource_path=="res://assets/world/thornbrook_forest_approved.jpg","game uses the approved new forest art"):return
    if not _check(art.texture.get_size()==Vector2(1586,992),"approved original aspect ratio preserved"):return
    if not _check(absf(art.scale.x*1586.0-2048.0)<0.5 and absf(art.scale.y*992.0-1280.0)<0.5,"painting fits the entire game world"):return
    if not _check(scene._walkable(Vector2(120,655)),"west entrance is open"):return
    if not _check(scene._walkable(Vector2(50,650)),"player can leave via west path"):return
    if not _check(scene._walkable(Vector2(1970,665)),"east trail stays open"):return
    if not _check(not scene._walkable(Vector2(40,270)),"western woods are solid outside trail"):return
    if not _check(not scene._walkable(Vector2(940,300)),"large central trees block walking"):return
    if not _check(not scene._walkable(Vector2(1300,890)),"large lower tree is solid"):return
    if not _check(not scene._walkable(Vector2(1050,100)),"top tree border prevents exit"):return
    if not _check(scene.mobs.size()==4,"original four slimes retained"):return
    for slime in scene.mobs:
        if not _check(slime["alive"] and int(slime["hp"])==35,"original slime combat intact"):return
        if not _check(scene._walkable(slime["node"].position),"slime spawns in accessible clearing"):return
        if not _check(scene._walkable(slime["node"].position+Vector2(43,12)),"player can approach each slime from attack range"):return
    scene._dismiss_message()
    scene.player.position=Vector2(50,650)
    scene._process(0.016)
    await process_frame
    if not _check(scene.current_map=="town","west trail returns to Elmwatch"):return
    print("ADVENTURE ODYSSEY FOREST BACKGROUND TEST: PASS")
    quit(0)
