extends SceneTree
# Collision detours, named cues, and registered equipment combat-pose QA.
func _initialize()->void:
	call_deferred("_run")

func _check(value:bool,detail:String)->bool:
	if not value:
		push_error("COMBAT POLISH TEST FAILED: "+detail)
		quit(1)
		return false
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game.data["guild_training_completed"]=true
	game._enter_world("forest",Vector2(430,640))
	await process_frame
	game._dismiss_message()
	game.set_process(false)
	if not _check(game.mobs.size()==7,"starter creatures and wildlife exist"):return
	var mob:Dictionary=game.mobs[4]
	if not _check(str(mob["species"])=="wolf","wolf uses common movement controller"):return
	for other in game.mobs:
		if other["node"]!=mob["node"]:other["alive"]=false
	var actor:Node2D=mob["node"]
	mob["home"]=Vector2(821,462)
	actor.position=mob["home"]
	game.player.position=Vector2(950,660)
	if not _check(game._walkable(actor.position) and not game._walkable(Vector2(835,462)),"approved forest rock has a solid edge"):return
	game._slime_move(mob,Vector2.RIGHT,150.0,0.1)
	if not _check(actor.position.distance_to(mob["home"])>0.1,"blocked first step steers instead of freezing"):return
	if not _check(game._walkable(actor.position),"first detour stays within walkable forest"):return
	for i in range(70):
		game._slime_move(mob,(game.player.position-actor.position).normalized(),135.0,0.1)
		if not _check(game._walkable(actor.position),"wolf never clips through a forest obstruction"):return
		if not _check(actor.position.distance_to(mob["home"])<=400.1,"enemy stays in leash"):return
	if not _check(actor.position.y>=500.0 and actor.position.x>840.0,"wolf can get around rock corner"):return
	var stationary:Vector2=actor.position
	game.player.position=stationary+Vector2(5,0)
	game._slime_move(mob,Vector2.RIGHT,130.0,0.1)
	if not _check(actor.position==stationary,"enemy cannot overlap player hitbox"):return

	var all_styles:Dictionary={
		"Power Slash":"slash","Shield Bash":"impact","Battle Cry":"aura",
		"Aimed Shot":"projectile","Quick Volley":"volley","Snare Trap":"trap",
		"Firebolt":"projectile","Frost Nova":"nova","Arcane Barrier":"ward",
		"Raise Skeleton":"summon","Soul Bolt":"projectile","Life Drain":"drain",
		"Backstab":"slash","Shadowstep":"dash","Poison Blade":"slash",
		"Holy Strike":"impact","Divine Heal":"heal","Sacred Shield":"ward",
		"Earthshaker":"impact","Hunter's Mark":"mark","Meteor Burst":"nova",
		"Death Echo":"drain","Smoke Veil":"smoke","Consecration":"heal"
	}
	var seen:Dictionary={}
	for name in all_styles.keys():
		var fx=Node2D.new()
		fx.set_script(load("res://scripts/skill_effect.gd"))
		game.world.add_child(fx)
		fx.call("configure",name,Vector2(430,640),Vector2(580,660),Color.WHITE,"advanced")
		if not _check(str(fx.get("pattern"))==str(all_styles[name]),"named pattern: "+name):return
		seen[str(fx.get("pattern"))]=true
		fx.queue_free()
	if not _check(all_styles.size()==24 and seen.size()>=12,"all 24 skills resolve to distinct semantic families"):return

	game.data["inventory"]["Iron Sword"]=1
	game._equip_item("Iron Sword")
	game.facing="down"
	game.anim_frame=0
	game._play_ability_fx("Power Slash","cleave")
	if not _check(game.combat_pose_timer>0.0 and game.combat_pose_kind=="strike" and game.anim_frame==2,"successful strike holds a registered frame"):return
	if not _check(game.worn_equipment_sprites["weapon"].visible and game.worn_equipment_sprites["weapon"].texture!=null,"sword remains aligned to strike frame"):return
	game._play_ability_fx("Firebolt","burn")
	if not _check(game.combat_pose_kind=="cast" and game.anim_frame==1,"casting uses a separate registered pose"):return
	game.combat_pose_timer=0.0
	game.anim_frame=0
	game._set_player_frame()
	if not _check(game.anim_frame==0 and game.worn_equipment_sprites["weapon"].visible,"idle and gear alignment resume after casting"):return
	print("ADVENTURE ODYSSEY COMBAT POLISH TEST: PASS / collision detours, 24 named cues, aligned attack and cast poses")
	quit(0)
