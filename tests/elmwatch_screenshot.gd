extends SceneTree
# Actual Godot renderer snapshots for approved Elmwatch art + NPC staging.
func _initialize()->void:
    call_deferred("_run")

func _capture(where:String)->bool:
    var img=root.get_viewport().get_texture().get_image()
    if img.get_width()<500 or img.get_height()<300:return false
    return img.save_png("res://screenshots/"+where+".png")==OK

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
    scene._enter_world("town",Vector2(1050,780))
    for i in range(16):await process_frame
    if not _capture("elmwatch_town"):
        push_error("ELMWATCH SCREENSHOT FAILED: town")
        quit(1)
        return
    for building in ["guild","market","inn","blacksmith"]:
        scene._enter_world(building,Vector2(1030,730))
        for i in range(10):await process_frame
        if not _capture("elmwatch_"+building):
            push_error("ELMWATCH SCREENSHOT FAILED: "+building)
            quit(1)
            return
    print("ELMWATCH SCREENSHOTS: 5 new visual previews")
    quit(0)
