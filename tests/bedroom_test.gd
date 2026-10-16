extends SceneTree
# Starter-home regression tests; do not require Android export.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool, description:String)->bool:
	if not ok:
		push_error("BEDROOM TEST FAILED: "+description)
		quit(1)
		return false
	return true

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._open_creator()
	scene.char_input.text="Home Tester"
	scene._create_character()
	await process_frame
	if not _check(scene.current_map=="bedroom" and scene.bedroom_art!=null,"start in playable bedroom"):return
	if not _check(scene.player!=null and scene.hud!=null and scene.npcs.is_empty() and scene.mobs.is_empty(),"player exists; no wilderness enemies"):return
	if not _check(not scene._walkable(Vector2(670,470)) and scene._walkable(Vector2(1010,870)),"bed blocks movement, center is walkable"):return
	if not _check(scene.data.get("tutorial_stage","")=="wake","tutorial first stage present"):return
	scene.player.position=Vector2(1340,877)
	if not _check(scene._bedroom_target()=="Chest","chest nearby detection"):return
	scene._interact()
	await process_frame
	if not _check(scene.popup!=null,"chest interaction opens storage"):return
	scene._move_chest_item("Training Sword",true)
	if not _check(int(scene.data["storage"].get("Training Sword",0))==1 and int(scene.data["inventory"].get("Training Sword",0))==0,"chest stores one item"):return
	scene._move_chest_item("Training Sword",false)
	if not _check(int(scene.data["storage"].get("Training Sword",0))==0 and int(scene.data["inventory"].get("Training Sword",0))==1,"chest retrieves one item"):return
	scene._dismiss_message()
	scene.player.position=Vector2(1393,676)
	if not _check(scene._bedroom_target()=="Mirror","mirror proximity"):return
	scene._interact()
	var original=int(scene.data["hair"])
	scene._mirror_adjust("hair",1)
	if not _check(int(scene.data["hair"])!=original,"mirror changes hairstyle"):return
	scene._mirror_cancel()
	if not _check(int(scene.data["hair"])==original,"cancel mirror restores appearance"):return
	scene._open_home_mirror()
	scene._mirror_adjust("hair_tint",1)
	scene._mirror_accept()
	if not _check(int(scene.data["hair_tint"])==1 and scene._load_save(),"mirror accepts and saves"):return
	if not _check(int(scene.data["hair_tint"])==1 and scene.data["map"]=="bedroom","bedroom choices persist in saved game"):return
	scene._enter_world("town",Vector2(1030,980))
	await process_frame
	if not _check(scene.npcs.size()==3 and scene.current_map=="town","old town remains accessible"):return
	print("ADVENTURE ODYSSEY BEDROOM TEST: PASS")
	quit(0)
