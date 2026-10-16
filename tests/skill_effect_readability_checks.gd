extends RefCounted
# Executed by combat_polish_test.gd in both existing validation paths.
func _check(ok:bool,detail:String)->bool:
	if not ok:push_error("READABLE FX TEST FAILED: "+detail)
	return ok

func _effect(game,ability:String,origin:Vector2,destination:Vector2,kind:String="",facing:Vector2=Vector2.RIGHT):
	var fx=Node2D.new()
	fx.set_script(load("res://scripts/skill_effect.gd"))
	game.world.add_child(fx)
	fx.call("configure",ability,origin,destination,Color.WHITE,kind,facing)
	fx.set_process(false)
	return fx

func run(game)->bool:
	var origin:Vector2=Vector2(430,640)
	var destination:Vector2=origin+Vector2(180,0)
	var fire=_effect(game,"Firebolt",origin,destination,"burn")
	if not _check(fire.glow.r>fire.glow.b,"Firebolt is fire-colored, not class ice blue"):return false
	if not _check(fire.visual_alpha(0.5)>0.95 and fire.visual_alpha(1.0)==0.0,"readable hold then complete fade"):return false
	if not _check(fire.projectile_point(0.0,Vector2(400,0))==Vector2.ZERO,"projectile begins at cast origin"):return false
	if not _check(fire.projectile_point(0.64,Vector2(400,0))==Vector2(400,0),"projectile arrives before impact phase"):return false
	if not _check(fire.trail_length(Vector2(1000,0))<=52.0,"long shot does not draw a full-screen beam"):return false
	if not _check(fire.trail_length(Vector2(20,0))<=20.0,"close shot trail remains bounded"):return false
	fire._process(-10.0)
	if not _check(fire.age==0.0,"negative frame time cannot reverse animation"):return false
	if not _check(fire.get_child_count()==0 and fire.get_canvas()==game.world.get_canvas(),"effect adds no labels or input controls and stays on world canvas"):return false
	fire._process(fire.duration+0.01)
	if not _check(fire.is_queued_for_deletion(),"expired effect cleans itself up"):return false

	var left=_effect(game,"Aimed Shot",origin,origin,"ranged",Vector2.LEFT)
	if not _check(left.direction.x<0.0,"untargeted directional cue respects facing"):return false
	left.queue_free()
	for ability in ["Snare Trap","Raise Skeleton","Hunter's Mark","Shield Bash","Holy Strike"]:
		var fx=_effect(game,ability,origin,destination)
		if not _check(fx.position==destination,"correct placement: "+ability):return false
		fx.queue_free()
	for ability in ["Frost Nova","Arcane Barrier","Sacred Shield","Divine Heal","Consecration","Earthshaker"]:
		var fx=_effect(game,ability,origin,destination)
		if not _check(fx.position==origin,"caster-centered cue: "+ability):return false
		fx.queue_free()

	var volley=_effect(game,"Quick Volley",origin,destination,"volley")
	var positions:Array=[origin+Vector2(120,-35),origin+Vector2(145,0),origin+Vector2(160,42),origin+Vector2(180,60)]
	volley.set_target_positions(positions)
	if not _check(volley.target_offsets.size()==3 and volley.target_offsets[0]==Vector2(120,-35) and volley.target_offsets[2]==Vector2(160,42),"volley keeps actual destinations, capped at three"):return false
	volley.set_target_positions([positions[0]])
	if not _check(volley.target_offsets.size()==1,"one target does not show three fake hits"):return false
	volley.queue_free()

	# Exercise integration before trap_timer is initialized: previous implementation
	# read stale trap_pos and put the deployment cue on the caster.
	game.player.position=origin
	game.facing="right"
	game.trap_timer=0.0
	game.trap_pos=Vector2(1,1)
	var saved_data:Dictionary=game.data.duplicate(true)
	var cooldowns:Array=[]
	for cooldown in game.skill_cooldowns:cooldowns.append(cooldown)
	game._play_ability_fx("Snare Trap","trap")
	var trap=game.world.get_child(game.world.get_child_count()-1)
	var expected:Vector2=origin+Vector2(130,0)
	if not game._walkable(expected):expected=origin
	if not _check(trap.position==expected,"first trap cast uses this placement, not stale timer state"):return false
	if not _check(game.trap_timer==0.0 and game.trap_pos==Vector2(1,1),"visual does not alter trap gameplay state"):return false
	if not _check(game.data==saved_data,"visual does not mutate saves, stats, currency or progression"):return false
	for i in range(cooldowns.size()):
		if not _check(game.skill_cooldowns[i]==cooldowns[i],"visual does not change cooldowns"):return false
	trap.queue_free()
	print("ADVENTURE ODYSSEY READABLE FX CHECKS: PASS / silhouettes, travel, bounded trails, cast-site placement, cleanup")
	return true
