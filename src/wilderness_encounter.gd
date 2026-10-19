extends RefCounted
# Deterministic encounter simulation. Save owns resources, consumption and quest rewards.
const Abilities = preload("res://src/class_abilities.gd")
const ID := "south_meadow_slimes"
const SPAWNS := [Vector2(1040,2190), Vector2(1250,2260), Vector2(1100,2430)]
const RETRY_POINT := Vector2(1000,2020)
const MAX_HP := 100
const ENEMY_HP := 36
const ATTACK_RANGE := 108.0
const LEASH := 235.0
var continuous := false
var territory := Rect2()
var encounter_id := ID
var spawns: Array = SPAWNS.duplicate()
var retry_point := RETRY_POINT
var enemy_hp := ENEMY_HP
var enemy_damage := 14
var enemy_speed := 76.0
var windup := 0.65
var leash := LEASH
var detection_radius := 190.0
var enemy_attack_range := 62.0
var enemy_attack_cooldown := 1.25
var max_hp := MAX_HP
var max_mana := 50.0
var mana := 50.0
var mana_recovery := 1.0
var hero_class := "Warrior"
var power_bonus := 0
var skill_cooldowns: Array = [0.0,0.0,0.0]
var potion_cooldown := 0.0
var buff_timer := 0.0
var shield_timer := 0.0
var shield_charges := 0
var trap_timer := 0.0
var trap_position := Vector2.ZERO
var summon_timer := 0.0
var summon_cooldown := 0.0
var summon_position := Vector2.ZERO
var summon_facing := Vector2.DOWN
var summon_moving := false
var summon_attack_flash := 0.0
var skill_flash := 0.0
var skill_kind := ""
var skill_origin := Vector2.ZERO
var enemies: Array[Dictionary] = []
var hp := MAX_HP
var attack_cooldown := 0.0
var invulnerability := 0.0
var strike_flash := 0.0
var hit_flash := 0.0
var defeated := false
var victory := false
var strike_target := Vector2.ZERO

func _init() -> void: reset()
func reset() -> void:
	enemies.clear()
	for spawn in spawns:
		enemies.append({"home":spawn,"position":spawn,"hp":enemy_hp,"max_hp":enemy_hp,"stun":0.0,"slow":0.0,"burn":0.0,"poison":0.0,"dot_tick":0.0,"mode":"idle","timer":0.0,"phase":0.0,"facing":0,"cooldown":0.0,"hit_flash":0.0,"aim":spawn})
	hp = max_hp
	mana = max_mana
	skill_cooldowns = [0.0,0.0,0.0]
	potion_cooldown = 0.0
	buff_timer = 0.0
	shield_timer = 0.0
	shield_charges = 0
	trap_timer = 0.0
	summon_timer = 0.0
	summon_cooldown = 0.0
	summon_moving = false
	summon_attack_flash = 0.0
	skill_flash = 0.0
	attack_cooldown = 0.0
	invulnerability = 0.0
	strike_flash = 0.0
	hit_flash = 0.0
	defeated = false
	victory = false

func living_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.hp > 0: count += 1
	return count

func attack(player: Vector2, can_stand: Callable) -> bool:
	if defeated or (victory and not continuous) or attack_cooldown > 0: return false
	var selected := -1
	var nearest := ATTACK_RANGE
	for i in enemies.size():
		var enemy := enemies[i]
		var distance := player.distance_to(enemy.position)
		if enemy.hp > 0 and distance <= nearest and line_clear(player,enemy.position,can_stand):
			nearest = distance
			selected = i
	if selected < 0: return false
	attack_cooldown = 0.48
	strike_flash = 0.18
	var enemy := enemies[selected]
	strike_target = enemy.position
	enemy.hp = maxi(0,enemy.hp - (12 + power_bonus + (6 if buff_timer > 0 else 0)))
	enemy.hit_flash = 0.16
	if enemy.hp == 0:
		enemy.mode = "dead"
		enemy.timer = 0.5
	if living_count() == 0: victory = true
	return true

func line_clear(a: Vector2, b: Vector2, can_stand: Callable) -> bool:
	var steps := maxi(1,int(ceil(a.distance_to(b)/4.0)))
	for i in range(steps+1):
		if not can_stand.call(a.lerp(b,float(i)/steps)): return false
	return true

func tick(delta: float, player: Vector2, can_stand: Callable) -> void:
	if defeated or (victory and not continuous): return
	# Cap simulation steps: resuming from background cannot deliver a burst of damage.
	var dt := clampf(delta,0,0.05)
	_tick_skills(dt,player,can_stand)
	if victory and not continuous: return
	attack_cooldown = maxf(0,attack_cooldown-dt)
	invulnerability = maxf(0,invulnerability-dt)
	strike_flash = maxf(0,strike_flash-dt)
	hit_flash = maxf(0,hit_flash-dt)
	for enemy in enemies:
		enemy.hit_flash = maxf(0,enemy.hit_flash-dt)
		enemy.cooldown = maxf(0,enemy.cooldown-dt)
		enemy.timer = maxf(0,enemy.timer-dt)
		if enemy.hp <= 0: continue
		if enemy.stun > 0: continue
		var offset: Vector2 = player-enemy.position
		var distance := offset.length()
		if (territory.has_area() and not territory.has_point(player)) or player.distance_to(enemy.home) > leash or Vector2(enemy.position).distance_to(enemy.home) > leash:
			enemy.mode = "return"
		if enemy.mode == "return":
			_move(enemy,enemy.home,dt,can_stand)
			if Vector2(enemy.position).distance_to(enemy.home) < 5:
				enemy.position = enemy.home
				enemy.hp = enemy_hp
				enemy.mode = "idle"
			continue
		if enemy.mode == "windup":
			if enemy.timer <= 0:
				enemy.mode = "recover"
				enemy.timer = 0.38
				enemy.cooldown = enemy_attack_cooldown
				# Aim is locked at windup: stepping away avoids the strike.
				if player.distance_to(enemy.aim) <= 38 and distance <= 75 and line_clear(enemy.position,player,can_stand) and invulnerability <= 0:
					if shield_charges > 0 and shield_timer > 0: shield_charges -= 1
					else: hp = maxi(0,hp-enemy_damage)
					invulnerability = 0.6
					hit_flash = 0.18
					if hp == 0: defeated = true; return
			continue
		if enemy.mode == "recover":
			if enemy.timer <= 0: enemy.mode = "idle"
			continue
		if distance < detection_radius and line_clear(enemy.position,player,can_stand):
			_face(enemy,offset)
			if distance <= enemy_attack_range and enemy.cooldown <= 0:
				enemy.mode = "windup"
				enemy.timer = windup
				enemy.aim = player
			elif distance > 52:
				enemy.mode = "chase"
				_move(enemy,player,dt,can_stand)
			else: enemy.mode = "idle"
		else:
			enemy.mode = "idle"
			if continuous:
				enemy.mode = "wander"
				enemy.phase += dt*0.35
				var wander: Vector2 = enemy.home + Vector2(cos(enemy.phase),sin(enemy.phase))*24
				_move(enemy,wander,dt*0.22,can_stand)

func _face(enemy: Dictionary, offset: Vector2) -> void:
	if offset.length() > 0:
		enemy.facing = (2 if offset.x > 0 else 1) if absf(offset.x) > absf(offset.y) else (0 if offset.y > 0 else 3)

func _move(enemy: Dictionary, destination: Vector2, dt: float, can_stand: Callable) -> void:
	var offset: Vector2 = destination-enemy.position
	_face(enemy,offset)
	var step := offset.limit_length(enemy_speed * (0.45 if enemy.slow > 0 else 1.0) * dt)
	var old: Vector2 = enemy.position
	if _enemy_can_stand(enemy.position+Vector2(step.x,0),enemy,can_stand): enemy.position += Vector2(step.x,0)
	if _enemy_can_stand(enemy.position+Vector2(0,step.y),enemy,can_stand): enemy.position += Vector2(0,step.y)
	if old != enemy.position: enemy.phase += dt*7.0

func _enemy_can_stand(point: Vector2, moving: Dictionary, can_stand: Callable) -> bool:
	if territory.has_area() and not territory.has_point(point): return false
	if not can_stand.call(point): return false
	for other in enemies:
		if other != moving and other.hp > 0 and point.distance_to(other.position) < 42: return false
	return true

func configure(data: Dictionary, selected_class: String, stats_summary: Dictionary, upgrade: int = 0) -> void:
	encounter_id = data.get("id",ID)
	continuous = bool(data.get("continuous",false))
	territory = data.get("territory",Rect2())
	spawns = []
	for point in data.get("spawns",[]): spawns.append(Vector2(point[0],point[1]))
	if spawns.is_empty(): spawns = SPAWNS.duplicate()
	var retry = data.get("retry_point",[RETRY_POINT.x,RETRY_POINT.y])
	retry_point = Vector2(retry[0],retry[1])
	enemy_hp = int(data.get("max_enemy_hp",ENEMY_HP))
	enemy_damage = int(data.get("damage",14))
	enemy_speed = float(data.get("speed",76))
	windup = float(data.get("windup",0.65))
	leash = float(data.get("leash",LEASH))
	detection_radius = float(data.get("detection_radius",190))
	enemy_attack_range = float(data.get("attack_range",62))
	enemy_attack_cooldown = float(data.get("attack_cooldown",1.25))
	hero_class = selected_class
	refresh_stats(stats_summary,upgrade)
	reset()

func refresh_stats(stats_summary: Dictionary, upgrade: int) -> void:
	var effects: Dictionary = stats_summary.planned_effects
	max_hp = int(effects.max_hp)
	max_mana = float(effects.max_mana)
	mana_recovery = float(effects.mana_recovery_per_second)
	# Explicit starter tuning: each +1 rank adds one damage, STR adds half its
	# increase above baseline. Other probability/gear formulas remain previews.
	power_bonus = int((stats_summary.attributes.STR-10)*0.5) + upgrade
	hp = mini(hp,max_hp)
	mana = minf(mana,max_mana)

func resource_state(revision: int) -> Dictionary:
	return {"version":1,"revision":revision,"hp":hp,"mana":mana,"skills":skill_cooldowns.duplicate(),"potion":potion_cooldown}

func apply_resources(value: Dictionary) -> void:
	hp = int(value.hp)
	mana = float(value.mana)
	skill_cooldowns = value.skills.duplicate()
	potion_cooldown = float(value.potion)
	defeated = hp <= 0

func capture() -> Dictionary:
	var result := {}
	for key in ["enemies","hp","mana","skill_cooldowns","potion_cooldown","attack_cooldown","invulnerability","strike_flash","hit_flash","defeated","victory","strike_target","buff_timer","shield_timer","shield_charges","trap_timer","trap_position","summon_timer","summon_cooldown","summon_position","summon_facing","summon_moving","summon_attack_flash","skill_flash","skill_kind","skill_origin"]:
		var value = get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func restore(value: Dictionary) -> void:
	for key in value:
		set(key,value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else value[key])

func _targets(player: Vector2, radius: float, can_stand: Callable) -> Array:
	var result := []
	for enemy in enemies:
		if enemy.hp > 0 and player.distance_to(enemy.position) <= radius and line_clear(player,enemy.position,can_stand): result.append(enemy)
	result.sort_custom(func(a,b): return player.distance_to(a.position) < player.distance_to(b.position))
	return result

func use_skill(slot: int, player: Vector2, can_stand: Callable) -> Dictionary:
	var skills := Abilities.for_class(hero_class)
	if slot < 0 or slot >= skills.size() or defeated or (victory and not continuous): return {"ok":false,"message":"No active encounter."}
	var skill: Dictionary = skills[slot]
	if skill_cooldowns[slot] > 0: return {"ok":false,"message":"%s is cooling down." % skill.name}
	if mana < skill.mana: return {"ok":false,"message":"%s needs %d mana. Use a mana potion or keep moving to recover." % [skill.name,skill.mana]}
	var targets := _targets(player,float(skill.get("range",0)),can_stand)
	var kind: String = skill.kind
	if kind not in ["buff","trap","barrier","summon","heal","shield"] and targets.is_empty(): return {"ok":false,"message":"%s: move closer with a clear line to an enemy." % skill.name}
	if kind == "heal" and hp >= max_hp: return {"ok":false,"message":"Health is full. No mana spent."}
	var next_position := player
	if kind == "step":
		next_position = targets[0].position + (player-targets[0].position).normalized()*65.0
		if not line_clear(player,next_position,can_stand): return {"ok":false,"message":"Shadowstep path is blocked. No mana spent."}
	mana -= skill.mana
	skill_cooldowns[slot] = skill.cd
	skill_flash = 0.6
	skill_kind = kind
	skill_origin = player
	match kind:
		"buff": buff_timer = 9.0
		"barrier", "shield":
			shield_timer = 13.0
			shield_charges = 2 if kind == "barrier" else 3
		"heal": hp = mini(max_hp,hp+35)
		"trap":
			trap_timer = 12.0
			trap_position = player
		"summon":
			summon_timer = 15.0
			summon_cooldown = 0.5
			summon_position = player + Vector2(48,0)
		"step": pass
		_:
			var count := targets.size() if kind in ["cleave","volley","nova"] else 1
			for index in range(mini(3,count)):
				var target: Dictionary = targets[index]
				var damage := int(skill.get("damage",0))
				if kind == "backstab" and target.mode in ["idle","return"]: damage += 12
				_damage(target,damage)
				if kind == "stun": target.stun = 2.0; target.mode = "idle"
				if kind == "burn": target.burn = 3.0
				if kind == "poison": target.poison = 5.0
				if kind == "nova": target.slow = 4.0
				if kind == "drain": hp = mini(max_hp,hp+10)
	return {"ok":true,"message":"%s • %d MP" % [skill.name,skill.mana],"position":next_position}

func _damage(enemy: Dictionary, amount: int) -> void:
	if enemy.hp <= 0: return
	enemy.hp = maxi(0,enemy.hp-amount)
	enemy.hit_flash = 0.16
	strike_target = enemy.position
	if enemy.hp == 0: enemy.mode = "dead"; enemy.timer = 0.5
	if living_count() == 0: victory = true

func _tick_skills(dt: float, player: Vector2, can_stand: Callable) -> void:
	mana = minf(max_mana,mana+mana_recovery*dt)
	for index in 3: skill_cooldowns[index] = maxf(0,skill_cooldowns[index]-dt)
	potion_cooldown = maxf(0,potion_cooldown-dt)
	buff_timer = maxf(0,buff_timer-dt)
	shield_timer = maxf(0,shield_timer-dt)
	if shield_timer <= 0: shield_charges = 0
	trap_timer = maxf(0,trap_timer-dt)
	summon_timer = maxf(0,summon_timer-dt)
	summon_attack_flash = maxf(0,summon_attack_flash-dt)
	summon_moving = false
	skill_flash = maxf(0,skill_flash-dt)
	for enemy in enemies:
		if enemy.hp <= 0: continue
		enemy.stun = maxf(0,enemy.stun-dt)
		enemy.slow = maxf(0,enemy.slow-dt)
		if trap_timer > 0 and Vector2(enemy.position).distance_to(trap_position) < 100: enemy.slow = maxf(enemy.slow,1.0)
		var damage := 0
		if enemy.burn > 0: damage += 3
		if enemy.poison > 0: damage += 2
		enemy.burn = maxf(0,enemy.burn-dt)
		enemy.poison = maxf(0,enemy.poison-dt)
		if damage > 0:
			enemy.dot_tick += dt
			if enemy.dot_tick >= 1.0:
				enemy.dot_tick -= 1.0
				_damage(enemy,damage)
	if summon_timer > 0:
		summon_cooldown -= dt
		var targets := _targets(player,300,can_stand)
		if not targets.is_empty():
			var target: Dictionary = targets[0]
			var desired: Vector2 = target.position + Vector2(40,0)
			var next := summon_position.move_toward(desired,140*dt)
			if can_stand.call(next) and not next.is_equal_approx(summon_position):
				if summon_attack_flash <= 0: summon_facing = next-summon_position
				summon_position = next
				summon_moving = true
			if summon_cooldown <= 0 and summon_position.distance_to(target.position) <= 110 and line_clear(summon_position,target.position,can_stand):
				_damage(target,7)
				summon_facing = Vector2(target.position)-summon_position
				summon_attack_flash = 0.45
				summon_cooldown = 1.2
