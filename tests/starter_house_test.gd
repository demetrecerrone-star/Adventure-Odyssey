extends SceneTree
# Validate one bedroom, two common areas, and travel to Elmwatch.
func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, detail: String) -> bool:
    if not value:
        push_error("STARTER HOUSE TEST FAILED: " + detail)
        quit(1)
        return false
    return true

func _run() -> void:
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene._random_default()
    scene._enter_world("bedroom", scene.BEDROOM_SPAWN)
    await process_frame
    if not _check(scene.bedroom_art != null, "bedroom remains available"): return
    scene.player.position = Vector2(1024, 1080)
    if not _check(scene._bedroom_target() == "Door", "bedroom doorway detects player"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "foyer" and scene.house_art != null, "bedroom door opens foyer"): return
    if not _check(scene._walkable(Vector2(1024, 750)), "foyer can be traversed"): return
    scene.player.position = Vector2(1540, 705)
    if not _check(scene._house_target() == "Living Room", "living room doorway detected"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "living" and scene.house_art != null, "foyer opens living room/kitchen"): return
    if not _check(not scene._walkable(Vector2(1000, 750)), "living table collision"): return
    scene.player.position = Vector2(423, 710)
    if not _check(scene._house_target() == "Foyer", "living room can return to foyer"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "foyer", "return to foyer"): return
    scene.player.position = Vector2(1024, 1070)
    if not _check(scene._house_target() == "Front Door", "front door can be used"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "town" and scene.npcs.size() == 8, "outside opens Elmwatch and existing NPCs"): return
    if not _check(scene.data.get("tutorial_stage", "") == "outside", "exit tutorial stage saved"): return
    print("ADVENTURE ODYSSEY STARTER HOUSE TEST: PASS")
    quit(0)
