extends SceneTree
# Capture actual Godot Guild assignment and forest combat screens (not mockups).
func _initialize()->void:
    call_deferred("_run")

func _snap(file_name:String)->bool:
    var img=root.get_viewport().get_texture().get_image()
    if img.get_width()<500 or img.get_height()<300:return false
    return img.save_png("res://screenshots/"+file_name)==OK

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene.data["world_minutes"]=540.0
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
    scene._enter_world("guild",Vector2(1280,910))
    scene._interact_resident(scene.npcs[1])
    for i in range(15):await process_frame
    if not _snap("guild_quest_offer.png"):
        push_error("GUILD SCREENSHOT FAILED: quest offer")
        quit(1)
        return
    scene._accept_slime_training()
    scene._dismiss_message()
    scene._enter_world("forest",Vector2(450,650))
    scene._dismiss_message()
    scene.player.position=Vector2(550,500)
    for i in range(15):await process_frame
    if not _snap("thornbrook_combat.png"):
        push_error("GUILD SCREENSHOT FAILED: forest combat")
        quit(1)
        return
    print("GUILD TRAINING SCREENSHOTS: PASS")
    quit(0)
