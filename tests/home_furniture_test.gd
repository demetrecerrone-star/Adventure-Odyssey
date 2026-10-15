extends SceneTree
# Validate the source-based home art installation and keep all three furniture uses intact.
func _initialize()->void:
    call_deferred("_run")

func _check(ok:bool, what:String)->bool:
    if not ok:
        push_error("HOME FURNITURE TEST FAILED: "+what)
        quit(1)
        return false
    return true

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene._enter_world("bedroom",scene.BEDROOM_SPAWN)
    await process_frame
    if not _check(scene.bedroom_art!=null,"bedroom loads"):return
    var room=scene.bedroom_art
    var bg=room.get_node_or_null("EmptyRoomBackground") as Sprite2D
    if not _check(bg!=null and bg.texture!=null,"new empty room background loads"):return
    for name in ["Bed","Mirror","Chest"]:
        var sprite=room.get_node_or_null(name) as Sprite2D
        if not _check(sprite!=null and sprite.texture!=null,"starter "+name+" transparent art loads"):return
        if not _check(str(scene.data["home_styles"][name])==str(scene.HOME_STARTER[name]),name+" is equipped for free"):return
        if not _check(scene.data["home_owned"][name].has(scene.HOME_STARTER[name]),name+" is permanently owned"):return
    if not _check(scene._walkable(Vector2(1010,870)) and not scene._walkable(Vector2(700,600)),"modular collision geometry"):return
    scene._open_home_chest()
    await process_frame
    if not _check(scene.popup!=null,"working storage chest remains available"):return
    scene._open_home_decor()
    await process_frame
    if not _check(scene.popup!=null,"room style preview opens"):return
    scene._dismiss_message()
    scene.data["home_styles"]["Bed"]="missing_locked_item"
    scene._ensure_home_styles()
    if not _check(scene.data["home_styles"]["Bed"]=="oak_green","unowned styles cannot be equipped"):return
    scene._save()
    if not _check(scene._load_save(),"saved home decor can reload"):return
    if not _check(scene.data["home_styles"]["Chest"]=="plain_wood","starter chest persisted"):return
    print("ADVENTURE ODYSSEY HOME FURNITURE TEST: PASS")
    quit(0)
