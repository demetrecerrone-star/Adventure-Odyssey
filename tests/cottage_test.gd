extends SceneTree
# Cottage tutorial progression: bedroom -> house -> Elmwatch -> house -> bedroom.
func _initialize()->void:
	call_deferred("_run")

func _check(ok:bool,label:String)->bool:
	if not ok:
		push_error("COTTAGE TEST FAILED: "+label)
		quit(1)
		return false
	return true

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("bedroom",scene.BEDROOM_SPAWN)
	await process_frame
	if not _check(scene.bedroom_art!=null,"starter bedroom remains"):return
	scene.player.position=Vector2(1024,1050)
	if not _check(scene._bedroom_target()=="Door","bedroom doorway reachable"):return
	scene._interact_bedroom()
	await process_frame
	if not _check(scene.current_map=="cottage" and scene.cottage_art!=null,"bedroom opens the cottage"):return
	if not _check(scene.data.get("tutorial_stage","")=="cottage","first cottage tutorial stage saved"):return
	if not _check(scene._walkable(Vector2(1024,720)) and not scene._walkable(Vector2(700,730)),"open hallway and furniture collision"):return
	scene._dismiss_message()
	var before=int(scene.data["inventory"].get("Health Potion",0))
	scene.player.position=Vector2(1580,772)
	if not _check(scene._cottage_target()=="Pantry","pantry can be reached"):return
	scene._interact_cottage()
	if not _check(int(scene.data["inventory"].get("Health Potion",0))==before+1,"pantry grants a starter potion"):return
	scene._dismiss_message()
	scene._interact_cottage()
	if not _check(int(scene.data["inventory"].get("Health Potion",0))==before+1,"pantry cannot be farmed"):return
	scene._dismiss_message()
	if not _check(scene._save() and scene._load_save() and bool(scene.data.get("cottage_pantry_claimed",false)),"pantry persists after save reload"):return
	scene.player.position=Vector2(1024,1050)
	if not _check(scene._cottage_target()=="Front Door","front door detectable"):return
	scene._interact_cottage()
	await process_frame
	if not _check(scene.current_map=="foyer" and scene.foyer_art!=null,"kitchen and living room open approved foyer"):return
	if not _check(scene._walkable(Vector2(1000,700)) and not scene._walkable(Vector2(110,700)),"illustrated foyer has walkable floor and solid boundary"):return
	scene.player.position=Vector2(1024,1080)
	if not _check(scene._foyer_target()=="Front Door","foyer front door reachable"):return
	scene._interact_foyer()
	await process_frame
	if not _check(scene.current_map=="town" and scene.npcs.size()==3,"foyer leads to Elmwatch NPC town"):return
	if not _check(scene.data["tutorial_stage"]=="elmwatch" and bool(scene.data.get("elmwatch_intro_seen",false)),"Elmwatch first visit remembered"):return
	scene._dismiss_message()
	if not _check(scene._near_cottage_entry(),"town cottage entrance works"):return
	scene._interact()
	await process_frame
	if not _check(scene.current_map=="foyer" and scene.foyer_art!=null,"town returns to approved cottage foyer"):return
	scene.player.position=Vector2(470,735)
	if not _check(scene._foyer_target()=="Living Room","foyer connects to living room"):return
	scene._interact_foyer()
	await process_frame
	if not _check(scene.current_map=="cottage" and scene.player.position==Vector2(1024,984),"foyer returns to kitchen and living room"):return
	scene.player.position=Vector2(1024,418)
	if not _check(scene._cottage_target()=="Bedroom Door","bedroom return door detectable"):return
	scene._interact_cottage()
	await process_frame
	if not _check(scene.current_map=="bedroom" and scene.bedroom_art!=null,"cottage returns to functional bedroom"):return
	if not _check(int(scene.data["inventory"].get("Health Potion",0))==before+1,"inventory survives transitions"):return
	print("ADVENTURE ODYSSEY COTTAGE TEST: PASS")
	quit(0)
