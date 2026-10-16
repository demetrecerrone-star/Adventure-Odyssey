extends SceneTree
# Native Godot screenshots of actual boutique GUI and installed furniture art.
func _initialize()->void:
    call_deferred("_run")

func _capture(file:String)->bool:
    for i in range(14):
        await process_frame
    var img:Image=root.get_texture().get_image()
    if img==null or img.get_width()<1000:
        return false
    return img.save_png("res://screenshots/"+file)==OK

func _run()->void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene._enter_world("bedroom",scene.BEDROOM_SPAWN)
    await process_frame
    scene._award_sigils(100)
    scene._open_home_decor()
    if not await _capture("cottage_sigil_boutique.png"):
        push_error("AO COTTAGE SCREENSHOT: boutique capture failed")
        quit(1)
        return
    scene._cottage_boutique_buy("Bed","royal_blue")
    scene._cottage_boutique_buy("Mirror","sunburst_gold")
    scene._cottage_boutique_buy("Chest","moonstone_trim")
    scene._dismiss_message()
    if not await _capture("cottage_premium_furniture.png"):
        push_error("AO COTTAGE SCREENSHOT: equipped room capture failed")
        quit(1)
        return
    scene._open_home_decor()
    if not await _capture("cottage_sigil_purchased.png"):
        push_error("AO COTTAGE SCREENSHOT: purchased style screen failed")
        quit(1)
        return
    print("AO COTTAGE BOUTIQUE SCREENSHOTS: PASS / boutique, furnished room, owned style")
    quit(0)
