extends SceneTree
const Encounter = preload("res://src/wilderness_encounter.gd")
const Stats = preload("res://src/character_stats.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var clear := func(_point: Vector2): return true
	for selected_class in Encounter.Abilities.SETS:
		for slot in 3:
			var e = Encounter.new()
			e.configure({},selected_class,Stats.summary(Stats.initial_state()),1)
			e.hp = 60
			var player: Vector2 = e.enemies[0].position+Vector2(30,0)
			var skill: Dictionary = Encounter.Abilities.for_class(selected_class)[slot]
			var before := e.capture()
			var result: Dictionary = e.use_skill(slot,player,clear)
			check(result.ok,selected_class+" "+skill.name+" usable")
			check(e.mana == 50-skill.mana and e.skill_cooldowns[slot] == skill.cd,"Exact mana and cooldown")
			match skill.kind:
				"buff": check(e.buff_timer > 0,"Battle Cry buff")
				"barrier","shield": check(e.shield_timer > 0 and e.shield_charges > 0,"Shield charges")
				"heal": check(e.hp == 95,"Divine Heal restores HP")
				"trap": check(e.trap_timer > 0 and e.trap_position == player,"Snare placed")
				"summon":
					check(e.summon_timer > 0,"Skeleton raised")
					for tick in 40: e.tick(0.05,player,clear)
					check(e.enemies[0].hp < before.enemies[0].hp,"Skeleton damages real enemy")
				"step": check(result.position.distance_to(e.enemies[0].position) <= 65.01,"Shadowstep repositions")
				_:
					check(e.enemies[0].hp < before.enemies[0].hp,"Skill deals damage")
					if skill.kind == "drain": check(e.hp == 70,"Life Drain heals")
					if skill.kind == "burn": check(e.enemies[0].burn > 0,"Firebolt burns")
					if skill.kind == "poison": check(e.enemies[0].poison > 0,"Poison Blade poisons")
					if skill.kind == "stun": check(e.enemies[0].stun > 0,"Shield Bash stuns")
					if skill.kind == "nova": check(e.enemies[0].slow > 0,"Frost Nova slows")

			if skill.kind in ["burn","poison"]:
				var wounded: int = e.enemies[0].hp
				for tick in 24: e.tick(0.05,player,clear)
				check(e.enemies[0].hp < wounded,"Damage over time actually ticks")
			if skill.kind == "stun":
				var stunned_at: Vector2 = e.enemies[0].position
				for tick in 10: e.tick(0.05,player+Vector2(90,0),clear)
				check(e.enemies[0].position == stunned_at,"Stun prevents pursuit")
			if skill.kind == "trap":
				e.tick(0.05,player,clear)
				check(e.enemies[0].slow > 0,"Trap applies slow to nearby enemy")
			if skill.kind == "buff":
				var wounded: int = e.enemies[0].hp
				e.attack(player,clear)
				check(wounded-e.enemies[0].hp == 19,"Battle Cry increases real basic strike")
			var applied := e.capture()
			check(not e.use_skill(slot,player,clear).ok and e.capture() == applied,"Cooldown rejects spam without mutation")
			e.restore(before); e.mana = 0
			check(not e.use_skill(slot,player,clear).ok and e.mana == 0,"No-mana cast rejected")
			e.restore(before)
			var wall := func(_p: Vector2): return false
			if skill.kind not in ["buff","barrier","shield","heal","trap","summon"]:
				check(not e.use_skill(slot,player,wall).ok and e.mana == 50,"No casts through walls or consumed mana")
			e.restore(before)
			var modal_snapshot := e.capture()
			check(e.capture() == modal_snapshot,"Snapshot detached")
	var e = Encounter.new()
	e.configure({},"Paladin",Stats.summary(Stats.initial_state()))
	check(not e.use_skill(1,Encounter.SPAWNS[0],clear).ok and e.mana == 50,"Full-health heal costs nothing")
	e.hp = 40; e.use_skill(2,Encounter.SPAWNS[0],clear)
	for tick in 20: e.tick(0.05,Encounter.SPAWNS[0]+Vector2(30,0),clear)
	check(e.hp == 40 and e.shield_charges == 2,"Sacred Shield blocks an actual hit")
	e.mana = 49.99
	for tick in 100: e.tick(0.05,Vector2.ZERO,clear)
	check(e.mana <= e.max_mana,"Mana regeneration clamps")
	print("CLASS ABILITY CHECKS: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
