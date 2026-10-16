extends SceneTree
# Test visual readability without modifying the core combat/quest system.
func _initialize() -> void:
	call_deferred("_run")

func _check(condition:bool,desc:String)->bool:
	if not condition:
		push_error("COMBAT FEEDBACK TEST FAILED: "+desc)
		quit(1)
		return false
	return true

func _run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("forest",Vector2(120,655))
	await process_frame
	scene._dismiss_message()
	if not _check(scene.mobs.size()==4,"all four slimes remain"):return
	for mob in scene.mobs:
		var visual=mob.get("indicator",null)
		if not _check(visual!=null and is_instance_valid(visual),"slime owns health indicator"):return
		if not _check(visual.health==35 and visual.max_health==35,"starting health bar is full"):return
	scene.player.position=scene.mobs[0]["node"].position+Vector2(56,10)
	scene._process(0.02)
	if not _check(scene.mobs[0]["indicator"].targeted,"nearest opponent is highlighted"):return
	if not _check(scene.prompt.text.contains("Green Slime 35/35 HP"),"attack prompt reveals target health"):return
	scene.mobs[0]["state"]="windup"
	scene._update_slime_targeting()
	if not _check(scene.mobs[0]["indicator"].attack_warning,"nearby attack telegraph appears"):return
	scene.mobs[0]["state"]="pursue"
	scene._update_slime_targeting()
	if not _check(not scene.mobs[0]["indicator"].attack_warning,"warning resets with attack timer"):return
	var slime=scene.mobs[0]
	var hp_before=int(slime["hp"])
	scene._attack()
	if not _check(int(slime["hp"])<hp_before,"original attack still damages slime"):return
	if not _check(slime["indicator"].health==int(slime["hp"]),"health bar follows damage"):return
	var found_popup=false
	for child in scene.world.get_children():
		if child.name=="CombatFloat" and child is Label:
			found_popup=true
	if not _check(found_popup,"hit spawns readable floating damage number"):return
	var after_hit:int=int(slime["hp"])
	scene._attack()
	if not _check(int(slime["hp"])==after_hit,"attack cooldown stays enforced"):return
	scene._process(0.02)
	if not _check(scene.prompt.text.contains("%d/%d HP" % [after_hit,35]),"HUD target HP updates after attack"):return
	scene.player.position=Vector2(120,655)
	scene._process(0.02)
	if not _check(not slime["indicator"].targeted,"moving away clears target"):return
	if not _check(scene._nearest_attackable_slime().is_empty(),"out-of-range enemies cannot be targeted"):return
	scene._enter_world("town",Vector2(1030,980))
	if not _check(scene.current_map=="town" and scene.mobs.is_empty(),"forest visuals do not linger in town"):return
	print("ADVENTURE ODYSSEY COMBAT FEEDBACK TEST: PASS")
	quit(0)
