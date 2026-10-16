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
    if not _check(scene.house_art.background != null and scene.house_art.background.texture != null, "approved foyer painting loads"): return
    if not _check(scene._walkable(Vector2(1024, 750)), "foyer can be traversed"): return
    scene.player.position = Vector2(470, 705)
    if not _check(scene._house_target() == "Living Room", "living room doorway detected"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "living" and scene.house_art != null, "foyer opens living room/kitchen"): return
    if not _check(scene.house_art.background != null and scene.house_art.background.texture != null, "approved living room painting loads"): return
    if not _check(scene.house_art.background.texture.resource_path.ends_with("living_room_kitchen.png"), "approved PNG, not the procedural fallback"): return
    if not _check(scene._walkable(scene.player.position), "living arrival is walkable"): return
    if not _check(not scene._walkable(Vector2(700,600)), "living sofa blocks passage"): return
    if not _check(not scene._walkable(Vector2(1550,520)), "kitchen counter blocks passage"): return
    if not _check(not scene._walkable(Vector2(1200, 710)), "living dining table collision"): return
    scene.player.position = Vector2(1513, 846)
    if not _check(scene._house_target() == "Pantry", "kitchen pantry proximity"): return
    var potions_before:int = int(scene.data["inventory"].get("Health Potion",0))
    scene._interact()
    if not _check(int(scene.data["inventory"].get("Health Potion",0)) == potions_before+1, "one starter potion collected"): return
    scene._interact()
    if not _check(int(scene.data["inventory"].get("Health Potion",0)) == potions_before+1, "pantry reward cannot repeat"): return
    scene.player.position = Vector2(1024, 1060)
    if not _check(scene._house_target() == "Foyer", "living room can return to foyer"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "foyer", "return to foyer"): return
    if not _check(scene._walkable(scene.player.position), "return spawn is walkable"): return
    scene.player.position = Vector2(1024, 1070)
    if not _check(scene._house_target() == "Front Door", "front door can be used"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "town" and scene.npcs.size() == 3, "outside opens Elmwatch and existing NPCs"): return
    if not _check(scene.data.get("tutorial_stage", "") == "elmwatch", "exit tutorial stage saved"): return
    scene.player.position = Vector2(540, 1095)
    if not _check(scene._near_cottage_entry(), "town cottage doorway nearby"): return
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "foyer" and scene.house_art != null, "player can reenter cottage from Elmwatch"): return
    scene.player.position = Vector2(1024, 400)
    scene._interact()
    await process_frame
    if not _check(scene.current_map == "bedroom" and scene.bedroom_art != null, "foyer returns to the only bedroom"): return
    print("ADVENTURE ODYSSEY STARTER HOUSE TEST: PASS")
    quit(0)
