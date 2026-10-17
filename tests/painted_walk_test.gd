extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	for base in ["male","female"]:
		for cls in preload("res://src/creator/catalog.gd").CLASSES:
			var a=preload("res://src/layered_avatar.gd").new()
			root.add_child(a)
			a.configure(base,cls,{"hair":base+"_hair_01","skin":"blue","eyes":"Green"})
			a.set_equipped_weapon(cls.to_lower()+"_01_weapon")
			for facing in range(4):
				a.advance(facing,true,0)
				var pilot:bool=base=="male" and cls=="Warrior" and facing==1
				check(a.uses_painted_pilot()==pilot,"Pilot strictly male Warrior left only")
				check(a.body.hframes==(6 if pilot else 8),"Real drawing count follows scope")
				check(a.cadence_speed(facing)==(135 if pilot else 60),"Actual-distance cadence calibration")
				check(a.palette_ready and a.hair_renderer.ready and a.weapon_back.visible,"All customization and equipment retained")
				if pilot:
					for phase in range(6):
						a.elapsed=(phase+0.01)/9.0
						a.advance(1,true,0)
						check(a.body.frame==phase,"Literal6 drawings, no duplicate phases")
						check(a.hair_renderer.front.position==a._pilot_offset("hair_offsets"),"Head registration follows pose")
						check(a.weapon_back.position==a._pilot_offset("weapon_offsets"),"Sword grip follows far hand")
					a.elapsed=0
					a.advance(1,true,15.0/a.cadence_speed(1))
					check(a.body.frame==1,"15px actual travel advances one drawing")
					var before:int=a.body.frame
					a.advance(1,true,0)
					check(a.body.frame==before,"Collision-stopped movement never advances")
					a.set_equipped_weapon("")
					check(not a.weapon_back.visible and not a.weapon_front.visible,"Unequip hides pilot sword")
					a.set_equipped_weapon("warrior_01_weapon")
				a.advance(facing,false,0)
				check(a.hair_renderer.front.position==Vector2.ZERO and a.weapon_back.position==Vector2.ZERO,"Idle clears pilot transforms")
				check(a.body.hframes==4,"Idle artwork unchanged")
			a.queue_free()
			await process_frame
	print("PAINTED WALK: %d checks; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
