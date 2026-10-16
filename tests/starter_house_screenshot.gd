extends SceneTree
# Record actual Godot gameplay screenshots of the two cottage common rooms.
# This is a visual check only; Android export is not requested here.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene._random_default()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
    for room_name in ["foyer", "living"]:
        scene._enter_world(room_name, Vector2(1024, 735))
        for i in range(12):
            await process_frame
        var picture = root.get_viewport().get_texture().get_image()
        if picture.get_width() < 500 or picture.get_height() < 300:
            push_error("COTTAGE SCREENSHOT FAILED: tiny viewport")
            quit(1)
            return
        var path = "res://screenshots/starter_" + room_name + ".png"
        if picture.save_png(path) != OK:
            push_error("COTTAGE SCREENSHOT FAILED: could not save " + path)
            quit(1)
            return
        print("COTTAGE SCREENSHOT: " + path)
    quit(0)
