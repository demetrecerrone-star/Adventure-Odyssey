extends SceneTree
const Progress = preload("res://src/tutorial_progress.gd")
const Dialogue = preload("res://src/tutorial_dialogue.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func run() -> void:
	var state := Progress.initial_state()
	var context := {"character_class":"Warrior","item_id":"warrior_01_weapon","from_level":0,"to_level":1,"supplies_consumed":true,"encounter_id":"south_meadow_slimes"}
	for i in 12:
		var step: Dictionary = Progress.STEPS[i]
		var result := Progress.plan_event(state,step.id,"legacy_%d"%i,context) if step.kind == "event" else Progress.plan_action(state,step.id,"legacy_%d"%i,context)
		check(result.ok,"Old quest progression step "+step.id)
		state = result.next_state
	check(state.stage == "tutorial_complete" and Progress.validate_state(state),"Existing completed tutorial remains valid unchanged")
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(state))
	check(Progress.validate_state(legacy),"Old serialized completion reloads with appended quest")
	check(not Progress.plan_event(state,"forest_patrol_completed","early",{"encounter_id":"west_forest_patrol"}).ok,"No forest victory before assignment")
	check(not Progress.plan_action(state,"guild_complete_forest_patrol","early_reward").ok,"No forest reward before completion")
	var view := Dialogue.describe("guild_receptionist",state)
	check(view.choices.filter(func(choice): return choice.kind == "action").size() == 1 and view.choices[0].id == "guild_assign_forest_patrol","Follow-up offered only after tutorial")
	var accepted := Progress.plan_action(state,"guild_assign_forest_patrol","forest_accept")
	check(accepted.ok and accepted.rewards.is_empty(),"Assignment grants no reward")
	state = accepted.next_state
	check(Progress.plan_action(state,"guild_assign_forest_patrol","forest_accept").duplicate,"Repeated acceptance idempotent")
	check(Dialogue.describe("guild_receptionist",state).choices.filter(func(choice): return choice.kind == "action").is_empty(),"Active patrol has no claim button")
	check(not Progress.plan_event(state,"forest_patrol_completed","wrong",{"encounter_id":"south_meadow_slimes"}).ok,"Old slimes cannot finish wolf patrol")
	var victory := Progress.plan_event(state,"forest_patrol_completed","forest_clear",{"encounter_id":"west_forest_patrol"})
	check(victory.ok and victory.rewards.is_empty(),"Forest victory awaits guild payment")
	state = victory.next_state
	check(Progress.plan_event(state,"forest_patrol_completed","forest_clear",{"encounter_id":"west_forest_patrol"}).duplicate,"Repeated forest victory idempotent")
	view = Dialogue.describe("guild_receptionist",state)
	check(view.choices.filter(func(choice): return choice.kind == "action").size() == 1 and view.choices[0].id == "guild_complete_forest_patrol","Earned turn-in available")
	var paid := Progress.plan_action(state,"guild_complete_forest_patrol","forest_paid")
	check(paid.ok and paid.rewards.size() == 1 and paid.rewards[0].count == 40 and paid.rewards[0].binding == "character","Exactly40 character-bound gold")
	state = paid.next_state
	check(Progress.validate_state(state) and state.stage == "forest_patrol_complete","New quest ends in valid completed state")
	var again := Progress.plan_action(state,"guild_complete_forest_patrol","forest_paid")
	check(again.ok and again.duplicate and again.rewards.is_empty() and again.next_state == state,"No repeated payout")
	check(Dialogue.describe("guild_receptionist",state).choices.filter(func(choice): return choice.kind == "action").is_empty(),"Completed patrol offers no further payment")
	var broken := state.duplicate(true); broken.reward_receipts.erase("guild.west_forest_patrol.gold")
	check(not Progress.validate_state(broken),"Missing forest payment receipt rejected")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/starter-region/forest_patrol.json"))
	check(data.id == "west_forest_patrol" and data.spawns.size() == 2 and data.max_enemy_hp == 48,"Bounded encounter contract")
	var w = load("res://src/starter_world.gd").new()
	var d = load("res://src/creator/character_draft.gd").new(); d.username = "ForestContentQA"
	w.state.path = "user://forest_content_%d.json"%Time.get_ticks_usec()
	check(w.state.create(d.payload()),"Create world fixture")
	root.add_child(w); w.set_process(false); await process_frame
	for item in data.placements:
		check(ResourceLoader.exists("res://assets/starter-region/"+item.file),"Approved scenery exists")
		if item.has("collision"):
			var r: Array = item.collision
			w.wilderness_footprints.append(Rect2(r[0],r[1],r[2],r[3]))
	for route in w.world_layout.routes:
		for i in range(route.points.size()-1):
			var a := Vector2(route.points[i][0],route.points[i][1])
			var b := Vector2(route.points[i+1][0],route.points[i+1][1])
			for tick in range(int(a.distance_to(b)/8.0)+1):
				var center := a.lerp(b,float(tick)/maxf(1,int(a.distance_to(b)/8.0)))
				var side := (b-a).normalized().orthogonal()*20
				for offset in [Vector2.ZERO,side,-side]: check(w.can_stand(center+offset),"Protected72px route remains clear: "+route.id)
	for point in data.spawns+[data.retry_point]:
		var p := Vector2(point[0],point[1])
		check(w.can_stand(p),"Clear spawn/retry "+str(p))
		for angle in range(0,360,45): check(w.can_stand(p+Vector2.from_angle(deg_to_rad(angle))*60),"Combat approach room "+str(p))
	for backwards in [false,true]:
		var route: Array = data.route_points.duplicate()
		if backwards: route.reverse()
		w.player = Vector2(route[0][0],route[0][1])
		for point in route:
			var target := Vector2(point[0],point[1])
			for tick in 150:
				if w.player.distance_to(target) < 2: break
				w.move_player((target-w.player).limit_length(7.75))
			check(w.player.distance_to(target) < 2,"Swept patrol/retry path "+str(target))
	var wolf = load(data.renderer).new()
	w.stage.add_child(wolf)
	var enemy := {"position":Vector2(660,950),"hp":48,"max_hp":48,"facing":0,"mode":"idle","phase":0.0,"hit_flash":0.0,"timer":0.5}
	for facing in 4:
		enemy.facing = facing
		for mode in ["idle","chase","windup","recover"]:
			enemy.mode = mode; wolf.sync(enemy)
			check(wolf.visible and wolf.sprite.frame_coords.x in range(4) and wolf.sprite.frame_coords.y in range(6),"Directional wolf animation "+mode)
			check(wolf.sprite.flip_h == (facing == 1),"Left mirroring only")
	enemy.hp = 0; wolf.sync(enemy); check(not wolf.visible,"Defeated wolf hidden")
	DirAccess.remove_absolute(w.state.path)
	w.queue_free(); await process_frame
	print("FOREST CONTENT: %d checks; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
