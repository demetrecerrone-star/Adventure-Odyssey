extends SceneTree
# Regression test for original approved house entrance illustration.
func _initialize()->void:
    call_deferred("_run")

func _check(ok:bool,label:String)->bool:
    if not ok:
        push_error("COTTAGE FOYER TEST FAILED: "+label)
        quit(1)
        return false
    return true

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene._enter_world("foyer",Vector2(1024,880))
    await process_frame
    if not _check(scene.foyer_art!=null,"foyer node created"):return
    var image=scene.foyer_art.get_node_or_null("ApprovedFoyerBackground") as Sprite2D
    if not _check(image!=null and image.texture!=null,"approved painting is visible"):return
    if not _check(image.texture.resource_path=="res://assets/home/approved_cottage_foyer.jpg","loads the exact approved image asset"):return
    if not _check(is_equal_approx(image.scale.x,image.scale.y),"painting preserves original aspect ratio"):return
    if not _check(scene._walkable(Vector2(500,735)) and scene._walkable(Vector2(1024,1080)),"both foyer doors accessible"):return
    if not _check(not scene._walkable(Vector2(140,780)) and not scene._walkable(Vector2(1024,290)),"walls block walking outside painting"):return
    scene.player.position=Vector2(500,735)
    if not _check(scene._foyer_target()=="Living Room","living room passage detects player"):return
    scene._interact_foyer()
    await process_frame
    if not _check(scene.current_map=="cottage" and scene.cottage_art!=null,"existing living room and kitchen preserved"):return
    scene.player.position=Vector2(1580,772)
    if not _check(scene._cottage_target()=="Pantry","pantry still interactive"):return
    scene.player.position=Vector2(1024,1070)
    scene._interact_cottage()
    await process_frame
    if not _check(scene.current_map=="foyer","cottage front passage returns to foyer"):return
    scene.player.position=Vector2(1024,1080)
    scene._interact_foyer()
    await process_frame
    if not _check(scene.current_map=="town","foyer exterior doorway leads to Elmwatch"):return
    if scene.popup!=null:scene._dismiss_message()
    if not _check(scene._near_cottage_entry(),"outside house entrance is detectable"):return
    scene._interact()
    await process_frame
    if not _check(scene.current_map=="foyer","return from Elmwatch enters correct room"):return
    scene._save()
    if not _check(scene._load_save() and scene.data["map"]=="foyer","foyer state survives save and load"):return
    print("ADVENTURE ODYSSEY FOYER TEST: PASS")
    quit(0)
