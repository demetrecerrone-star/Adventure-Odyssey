extends SceneTree
# Real sheets, movement-driven walk, and attack cues driven solely by combat.
func _initialize()->void:
	call_deferred("_run")

func _check(value:bool,detail:String)->bool:
	if not value:
		push_error("MONSTER ANIMATION TEST FAILED: "+detail)
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
	var slime:Dictionary=game.mobs[0]
	if not _check(not slime.has("animation_appearance") and slime["sprite"].hframes==1,"original forest slime remains unchanged"):return
	var mob:Dictionary=game.mobs[4]
	var sprite:Sprite2D=mob["sprite"]
	if not _check(mob.get("animation_appearance","")=="wolf","forest wolf configured at spawn"):return
	var wolf_only:bool="--wolf-only" in OS.get_cmdline_user_args()
	for appearance in (["wolf"] if wolf_only else game.MONSTER_ANIMATION_KEYS):
		game._configure_monster_animation(mob,appearance)
		if not _check(sprite.texture.resource_path.ends_with("/"+appearance+".png") and sprite.hframes==4 and sprite.vframes==6,"correct 4x6 directional texture: "+appearance):return
		var sheet:Image=sprite.texture.get_image()
		if not _check(sheet.get_size()==Vector2i(512,768) and sheet.get_pixel(0,0).a==0.0,"transparent sheet dimensions: "+appearance):return
		var walk0:PackedByteArray=sheet.get_region(Rect2i(0,0,128,128)).get_data()
		var walk1:PackedByteArray=sheet.get_region(Rect2i(128,0,128,128)).get_data()
		var strike:PackedByteArray=sheet.get_region(Rect2i(256,384,128,128)).get_data()
		if not _check(walk0!=walk1 and walk0!=strike,"walk and attack art differ: "+appearance):return
		var walk_up:PackedByteArray=sheet.get_region(Rect2i(0,256,128,128)).get_data()
		var walk_right:PackedByteArray=sheet.get_region(Rect2i(0,128,128,128)).get_data()
		if not _check(walk0!=walk_up and walk0!=walk_right and walk_up!=walk_right,"up/down/right are distinct drawn views: "+appearance):return
	game._configure_monster_animation(mob,"wolf")
	for other in game.mobs:
		if other["node"]!=mob["node"]:other["alive"]=false
	mob["node"].position=Vector2(550,650)
	mob["home"]=mob["node"].position
	mob["animation_position"]=mob["node"].position
	mob["state"]="pursue"
	mob["attack_cd"]=1.0
	game.player.position=Vector2(850,650)
	var seen:Dictionary={}
	for i in range(8):
		game._tick_slime_ai(0.1)
		seen[sprite.frame]=true
	if not _check(seen.size()>=3,"actual AI movement advances walk frames"):return
	var idle_position:Vector2=mob["node"].position
	game.player.position=idle_position+Vector2(70,0)
	mob["attack_cd"]=1.0
	for i in range(3):
		game._tick_slime_ai(0.1)
		if not _check(sprite.frame==4 and mob["node"].position==idle_position,"cooldown idle does not walk"):return
	mob["attack_cd"]=0.0
	game._tick_slime_ai(0.01)
	if not _check(mob["state"]=="windup" and sprite.frame==16,"real windup begins attack row"):return
	game._tick_slime_ai(0.15)
	game._tick_slime_ai(0.15)
	if not _check(sprite.frame==17,"late windup advances preparation"):return
	# Visual updates cannot cause damage or consume the actual windup.
	var hp:int=int(game.data["hp"])
	var windup:float=float(mob["windup"])
	for i in range(10):game._tick_monster_animations(0.1)
	if not _check(int(game.data["hp"])==hp and float(mob["windup"])==windup,"visual ticks never attack or alter AI timing"):return
	game.barrier_timer=10.0
	game.barrier_charges=10
	game._tick_slime_ai(0.15)
	game._tick_slime_ai(0.15)
	if not _check(sprite.frame==18 and game.barrier_charges==9,"strike appears when actual attack resolves once"):return
	game._tick_slime_ai(0.1)
	game._tick_slime_ai(0.1)
	if not _check(sprite.frame==19 and game.barrier_charges==9,"recovery frame never causes another hit"):return
	mob["animation_recovery"]=0.0
	mob["state"]="windup"
	mob["windup"]=0.5
	game.player.position=mob["node"].position+Vector2(300,0)
	game._tick_slime_ai(0.1)
	if not _check(mob["state"]=="pursue" and sprite.frame<12,"cancelled windup does not fake a strike"):return
	mob["stun_timer"]=1.0
	game._tick_slime_ai(0.1)
	if not _check(sprite.frame%4==0 and sprite.frame<12,"stunned creatures remain still"):return
	mob["stun_timer"]=0.0
	mob["node"].position.x-=5.0
	game._tick_monster_animations(0.1)
	if not _check(sprite.flip_h,"left movement flips the sheet"):return
	for direction in [Vector2.UP,Vector2.DOWN]:
		mob["node"].position+=direction*5.0
		game._tick_monster_animations(0.1)
		var expected_row:int=2 if direction==Vector2.UP else 0
		if not _check(int(sprite.frame/4)==expected_row and not sprite.flip_h,"vertical movement selects actual up/down art"):return
		mob["state"]="windup"
		mob["windup"]=0.58
		game.player.position=mob["node"].position+direction*70.0
		game._tick_monster_animations(0.1)
		if not _check(sprite.frame==(expected_row+3)*4,"vertical attack selects matching directional art"):return
		mob["state"]="pursue"
	mob["alive"]=false
	var dead_frame:int=sprite.frame
	mob["node"].position.x+=10.0
	for i in range(5):game._tick_monster_animations(0.1)
	if not _check(sprite.frame==dead_frame,"dead enemies do not animate"):return
	if wolf_only:
		print("ADVENTURE ODYSSEY DIRECTIONAL WOLF TEST: PASS")
		quit(0)
		return
	print("ADVENTURE ODYSSEY MONSTER ANIMATION TEST: PASS")
	quit(0)
