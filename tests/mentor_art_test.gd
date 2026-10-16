extends SceneTree
func _initialize()->void:
	call_deferred("_run")
func _ok(v:bool,why:String)->bool:
	if not v:
		push_error("MENTOR ART TEST FAILED: "+why)
		quit(1)
		return false
	return true
func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("town",Vector2(1030,980))
	await process_frame
	for name in ["Mira Ashwood","Kael Rook"]:
		var found:Dictionary={}
		for npc in scene.npcs:
			if str(npc["name"])==name:found=npc
		if not _ok(not found.is_empty(),name+" is present in Elmwatch"):return
		for face in ["up","down","left","right"]:
			found["facing"]=face
			scene._pose_resident(found,true,0.2)
			var tex:Texture2D=found["sprite"].texture
			if not _ok(tex!=null and tex.resource_path.contains("/npc_custom/"),name+" custom sprite "+face):return
			if not _ok(tex.get_size()==Vector2(160,192),name+" full-length SVG sprite"):return
		scene._show_npc_chat(found)
		if not _ok(scene.popup.npc_portrait_path.contains("/npc_custom/"),name+" custom conversation portrait"):return
		scene._dismiss_message()
	print("ADVENTURE ODYSSEY MENTOR ART TEST: PASS")
	quit(0)
