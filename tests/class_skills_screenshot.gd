extends SceneTree
# Native Godot previews: existing mage mentor, class-skill unlock and skill hit.
func _initialize()->void:
	call_deferred("_run")
func _snap(name:String)->bool:
	var picture=root.get_viewport().get_texture().get_image()
	return picture.get_width()>=500 and picture.save_png("res://screenshots/"+name)==OK
func _frames()->void:
	for i in range(12):await process_frame
func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	scene._random_default()
	scene.data["class"]="Mage"
	scene.data["guild_training_completed"]=true
	scene.data["world_minutes"]=720.0
	scene._enter_world("town",Vector2(1030,980))
	await process_frame
	var mentor:Dictionary={}
	for resident in scene.npcs:
		if str(resident["name"])=="Neris Crowe":
			mentor=resident
			break
	if mentor.is_empty():
		push_error("CLASS SKILL SCREENSHOT FAILED: mage mentor missing")
		quit(1)
		return
	scene._interact_resident(mentor)
	await _frames()
	scene.popup._reveal_remaining()
	await process_frame
	if not _snap("skill_quest_offer.png"):
		push_error("CLASS SKILL SCREENSHOT FAILED: mentor offer")
		quit(1)
		return
	scene.popup._accept_quest_pressed()
	scene._dismiss_message()
	# Screenshot setup only: simulate the already-tested four successful hits.
	scene.data["skill_trial_hits"]=4
	scene._interact_resident(mentor)
	await _frames()
	scene.popup._reveal_remaining()
	await process_frame
	if not _snap("skill_unlock_journal.png"):
		push_error("CLASS SKILL SCREENSHOT FAILED: unlock journal")
		quit(1)
		return
	scene._dismiss_message()
	scene._enter_world("forest",Vector2(430,640))
	await process_frame
	scene._dismiss_message()
	scene.player.position=scene.mobs[0]["node"].position+Vector2(65,10)
	scene._use_class_skill()
	await _frames()
	if not _snap("mage_arcane_bolt.png"):
		push_error("CLASS SKILL SCREENSHOT FAILED: forest ability")
		quit(1)
		return
	print("CLASS SKILL SCREENSHOTS: PASS")
	quit(0)
