extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var resolver=preload("res://src/layered_avatar.gd").new()
	check(resolver._painted_manifest_path("male","Warrior")=="res://assets/painted-walk-pilot/manifest.json","Reviewed male Warrior catalog preserves existing assets")
	check(not resolver._painted_manifest_path("female","Warrior").is_empty(),"Reviewed female Warrior batch is explicitly registered")
	check(resolver._painted_manifest_path("unknown","Warrior").is_empty() and resolver._painted_manifest_path("male","unknown").is_empty(),"Unknown identity cannot borrow painted artwork")
	resolver.free()
	for base in ["male","female"]:
		for cls in preload("res://src/creator/catalog.gd").CLASSES:
			var a=preload("res://src/layered_avatar.gd").new()
			root.add_child(a)
			a.configure(base,cls,{"hair":base+"_hair_01","skin":"blue","eyes":"Green"})
			a.set_equipped_weapon(cls.to_lower()+"_01_weapon")
			for facing in range(4):
				a.advance(facing,true,0)
				var pilot:bool=cls in ["Warrior","Paladin","Ranger","Assassin","Mage","Necromancer"]
				check(a.uses_painted_pilot()==pilot,"Pilot covers reviewed all twelve reviewed base/class directional sets")
				check(a.body.hframes==(6 if pilot else 8),"Real drawing count follows scope")
				check(is_equal_approx(a.cadence_speed(facing),155.0 if pilot else 60.0 * 155.0 / 135.0),"Actual-distance cadence calibration")
				check(a.palette_ready and a.hair_renderer.ready and a.weapon_back.visible,"All customization and equipment retained")
				if pilot:
					for phase in range(6):
						a.elapsed=(phase+0.01)/9.0
						a.advance(facing,true,0)
						check(a.body.frame==phase,"Literal6 drawings, no duplicate phases")
						if base=="male" and cls=="Warrior" and facing==1:
							check(a.hair_renderer.front.position==a._pilot_offset("hair_offsets")+a.head_offset(),"Head registration follows pose")
							check(a.weapon_back.position==a._pilot_offset("weapon_offsets"),"Sword grip follows far hand")
						else:
							var h=a.hair_renderer.front
							var transform:Dictionary=a._active_pilot().hair_transforms[phase]
							var source:=Vector2(transform.source_anchor[0],transform.source_anchor[1])
							var target:=Vector2(transform.target_anchor[0],transform.target_anchor[1])-Vector2(128,232)
							check((h.position+(source+h.offset)*h.scale).is_equal_approx(target+a.head_offset()),"Affine hair crown follows drawing and local head lift")
							check(h.scale==Vector2.ONE*float(transform.scale) and h.frame==facing,"Hair uses fitted directional idle source")
							check(a.weapon_front.frame==phase and a.weapon_front.hframes==6 and a.weapon_front.position==Vector2.ZERO,"Dedicated occlusion-masked sword follows pose")
					a.elapsed=0
					a.advance(facing,true,(155.0 / 9.0)/a.cadence_speed(facing))
					check(a.body.frame==1,"155/9 px actual travel advances one drawing")
					var before:int=a.body.frame
					a.advance(facing,true,0)
					check(a.body.frame==before,"Collision-stopped movement never advances")
					a.set_equipped_weapon("")
					check(not a.weapon_back.visible and not a.weapon_front.visible,"Unequip hides pilot sword")
					a.set_equipped_weapon(cls.to_lower()+"_01_weapon")
				a.advance(facing,false,0)
				check(a.hair_renderer.front.position==a.head_offset() and a.hair_renderer.front.scale==Vector2.ONE and a.weapon_back.position==Vector2.ZERO,"Idle clears pilot transforms")
				check(a.body.hframes==4,"Idle artwork unchanged")
			a.queue_free()
			await process_frame
	var room=preload("res://src/bedroom.gd").new()
	var draft=preload("res://src/creator/character_draft.gd").new()
	draft.username="CadenceTester"
	draft.set_base("male")
	room.state.path="user://painted-cadence-test.json"
	DirAccess.remove_absolute(room.state.path)
	check(room.state.create(draft.payload()),"Create isolated cadence fixture")
	root.add_child(room)
	room.set_process(false)
	for strength in [1.0,0.5]:
		room.player=Vector2(1000,850)
		room.touch_direction=Vector2.LEFT*strength
		room.actor.advance(1,false,0)
		for tick in range(12): room._process(1.0/36.0)
		check(is_equal_approx(room.player.x,1000.0-186.0*strength/3.0),"Actual full/half analog travel is186/93 px/s")
		check(is_equal_approx(room.actor.elapsed,strength/3.0),"Actual full/half input retains9/4.5 poses per second")
		check(room.actor.outfit.walk.left.fps==9.0,"Pilot asset cadence remains9fps")
	room.touch_direction=Vector2.ZERO
	var stopped:Vector2=room.player
	room._process(0.05)
	check(room.player==stopped and room.actor.current_animation=="idle","Release stops travel and returns idle")
	room.player=Vector2(80.01,925)
	room.touch_direction=Vector2.LEFT
	room._process(0.05)
	check(room.actor.current_animation=="idle","Fully blocked movement cannot animate walking")
	room.queue_free()
	DirAccess.remove_absolute("user://painted-cadence-test.json")
	print("PAINTED WALK: %d checks; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
