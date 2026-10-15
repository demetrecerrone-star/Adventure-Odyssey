extends SceneTree
# Capture the actual in-engine view of the approved cottage illustration.
func _initialize()->void:
    call_deferred("_run")

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene._enter_world("foyer",Vector2(1040,760))
    for i in range(14):await process_frame
    var image=root.get_viewport().get_texture().get_image()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
    if image.get_width()<500 or image.get_height()<300:
        push_error("FOYER SCREENSHOT FAILED: viewport too small")
        quit(1)
        return
    if image.save_png("res://screenshots/approved_cottage_foyer.png")!=OK:
        push_error("FOYER SCREENSHOT FAILED: PNG write error")
        quit(1)
        return
    print("FOYER SCREENSHOT: screenshots/approved_cottage_foyer.png")
    quit(0)
