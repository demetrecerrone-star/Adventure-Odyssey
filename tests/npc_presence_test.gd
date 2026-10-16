extends SceneTree
# Milestone 4: shopkeepers must never be duplicated indoors and outdoors.
func _initialize()->void:
    call_deferred("_run")

func _ok(condition:bool,label:String)->bool:
    if not condition:
        push_error("NPC PRESENCE TEST FAILED: "+label)
        quit(1)
        return false
    return true

func _names(scene:Node)->Array[String]:
    var names:Array[String]=[]
    for npc in scene.npcs:names.append(str(npc["name"]))
    return names

func _run()->void:
    var scene=load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    await process_frame
    scene._random_default()
    scene.data["world_minutes"]=540.0
    scene._enter_world("town",Vector2(1030,980))
    await process_frame
    var outdoor:Array[String]=_names(scene)
    if not _ok(outdoor.size()==5,"only three outdoor residents in morning"):return
    if not _ok(outdoor.has("Sister Sera Vale") and outdoor.has("Garrick Thorn") and outdoor.has("Neris Crowe"),"outdoor mentors available during shop hours"):return
    if not _ok(not outdoor.has("Ilyan Crest"),"registrar is not duplicated outdoors"):return
    scene._enter_world("guild",Vector2(1030,980))
    await process_frame
    var guild:Array[String]=_names(scene)
    if not _ok(guild.size()==2 and guild.has("Ilyan Crest") and guild.has("Captain Elara Voss"),"guild has two working staff"):return

    # Noon: staff leave their counters and appear in the streets.
    scene.data["world_minutes"]=720.0
    scene._tick_world_time(0.0)
    if not _ok(scene.npcs.size()==0,"no staff duplicated in indoor guild during lunch"):return
    scene._enter_world("town",Vector2(1030,980))
    await process_frame
    if not _ok(scene.npcs.size()==10,"all ten residents can be met outdoors at lunch"):return
    var all_names:Array[String]=_names(scene)
    var unique:Dictionary={}
    for name in all_names:
        if not _ok(not unique.has(name),"no duplicate town resident "+name):return
        unique[name]=true
    scene.player.position=scene.NPC_ROUTINES["mara_fenwick"][1]
    scene._tick_town_residents(0.25)
    if not _ok(scene.npcs.size()==10,"daytime roaming retains roster"):return

    # The same shopkeeper is not both inside and outside in the evening.
    scene.data["world_minutes"]=1260.0
    scene._tick_world_time(0.0)
    if not _ok(scene.npcs.size()==10,"ten residents attend the evening town"):return
    scene._enter_world("market",Vector2(1030,980))
    await process_frame
    if not _ok(scene.npcs.is_empty(),"market is unattended after closing"):return

    # At night everyone sleeps off-screen until morning.
    scene.data["world_minutes"]=1380.0
    scene._tick_world_time(0.0)
    scene._enter_world("town",Vector2(1030,980))
    await process_frame
    if not _ok(scene.npcs.is_empty(),"no resident stands outside all night"):return
    scene._save()
    if not _ok(scene._load_save() and scene._world_clock_text()=="11:00 PM","night schedule survives save and load"):return

    scene.data["world_minutes"]=540.0
    scene._tick_world_time(0.0)
    if not _ok(scene.npcs.size()==5,"morning residents return automatically without loading the map"):return
    scene._enter_world("market",Vector2(1030,980))
    await process_frame
    if not _ok(scene.npcs.size()==1 and scene.npcs[0]["name"]=="Mara Fenwick","shopkeeper returns to counter at opening"):return

    # Walk frame and idle frame: frame resets to 0 when walking ends.
    scene._enter_world("town",Vector2(1030,980))
    await process_frame
    scene.data["world_minutes"]=765.0
    scene._tick_world_time(0.0)
    if not _ok(scene.npcs.size()==10,"lunch transition adds villagers without map reload"):return
    var resident:Dictionary=scene.npcs[0]
    scene._tick_town_residents(0.4)
    var tex:Texture2D=resident["sprite"].texture
    if not _ok(tex!=null and tex.resource_path.contains("/npcs/"),"movement uses a resident animation sprite"):return
    scene._pose_resident(resident,false,0.5)
    if not _ok(resident["sprite"].texture.resource_path.ends_with("_00.png"),"idle resets to first frame"):return
    print("ADVENTURE ODYSSEY NPC PRESENCE TEST: PASS")
    quit(0)
