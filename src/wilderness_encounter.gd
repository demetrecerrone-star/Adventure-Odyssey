extends RefCounted
# Small deterministic, transient training encounter. Save owns quest completion/rewards.
const ID := "south_meadow_slimes"
const SPAWNS := [Vector2(1040,2190), Vector2(1250,2260), Vector2(1100,2430)]
const RETRY_POINT := Vector2(1000,2020)
const MAX_HP := 100
const ENEMY_HP := 36
const ATTACK_RANGE := 108.0
const LEASH := 235.0
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
	for spawn in SPAWNS:
		enemies.append({"home":spawn,"position":spawn,"hp":ENEMY_HP,"mode":"idle","timer":0.0,"phase":0.0,"facing":0,"cooldown":0.0,"hit_flash":0.0,"aim":spawn})
	hp = MAX_HP
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
	if defeated or victory or attack_cooldown > 0: return false
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
	enemy.hp = maxi(0,enemy.hp - 12)
	enemy.hit_flash = 0.16
	if enemy.hp == 0:
		enemy.mode = "dead"
		enemy.timer = 0.5
	if living_count() == 0: victory = true
	return true

func line_clear(a: Vector2, b: Vector2, can_stand: Callable) -> bool:
	var steps := maxi(1,int(ceil(a.distance_to(b)/8.0)))
	for i in range(steps+1):
		if not can_stand.call(a.lerp(b,float(i)/steps)): return false
	return true

func tick(delta: float, player: Vector2, can_stand: Callable) -> void:
	if defeated or victory: return
	# Cap simulation steps: resuming from background cannot deliver a burst of damage.
	var dt := clampf(delta,0,0.05)
	attack_cooldown = maxf(0,attack_cooldown-dt)
	invulnerability = maxf(0,invulnerability-dt)
	strike_flash = maxf(0,strike_flash-dt)
	hit_flash = maxf(0,hit_flash-dt)
	for enemy in enemies:
		enemy.hit_flash = maxf(0,enemy.hit_flash-dt)
		enemy.cooldown = maxf(0,enemy.cooldown-dt)
		enemy.timer = maxf(0,enemy.timer-dt)
		if enemy.hp <= 0: continue
		var offset: Vector2 = player-enemy.position
		var distance := offset.length()
		if player.distance_to(enemy.home) > LEASH or Vector2(enemy.position).distance_to(enemy.home) > LEASH:
			enemy.mode = "return"
		if enemy.mode == "return":
			_move(enemy,enemy.home,dt,can_stand)
			if Vector2(enemy.position).distance_to(enemy.home) < 5:
				enemy.position = enemy.home
				enemy.hp = ENEMY_HP
				enemy.mode = "idle"
			continue
		if enemy.mode == "windup":
			if enemy.timer <= 0:
				enemy.mode = "recover"
				enemy.timer = 0.38
				enemy.cooldown = 1.25
				# Aim is locked at windup: stepping away avoids the strike.
				if player.distance_to(enemy.aim) <= 38 and distance <= 75 and line_clear(enemy.position,player,can_stand) and invulnerability <= 0:
					hp = maxi(0,hp-14)
					invulnerability = 0.6
					hit_flash = 0.18
					if hp == 0: defeated = true; return
			continue
		if enemy.mode == "recover":
			if enemy.timer <= 0: enemy.mode = "idle"
			continue
		if distance < 190 and line_clear(enemy.position,player,can_stand):
			_face(enemy,offset)
			if distance <= 62 and enemy.cooldown <= 0:
				enemy.mode = "windup"
				enemy.timer = 0.65
				enemy.aim = player
			elif distance > 52:
				enemy.mode = "chase"
				_move(enemy,player,dt,can_stand)
			else: enemy.mode = "idle"
		else: enemy.mode = "idle"

func _face(enemy: Dictionary, offset: Vector2) -> void:
	if offset.length() > 0:
		enemy.facing = (2 if offset.x > 0 else 1) if absf(offset.x) > absf(offset.y) else (0 if offset.y > 0 else 3)

func _move(enemy: Dictionary, destination: Vector2, dt: float, can_stand: Callable) -> void:
	var offset: Vector2 = destination-enemy.position
	_face(enemy,offset)
	var step := offset.limit_length(76.0*dt)
	var old: Vector2 = enemy.position
	if _enemy_can_stand(enemy.position+Vector2(step.x,0),enemy,can_stand): enemy.position += Vector2(step.x,0)
	if _enemy_can_stand(enemy.position+Vector2(0,step.y),enemy,can_stand): enemy.position += Vector2(0,step.y)
	if old != enemy.position: enemy.phase += dt*7.0

func _enemy_can_stand(point: Vector2, moving: Dictionary, can_stand: Callable) -> bool:
	if not can_stand.call(point): return false
	for other in enemies:
		if other != moving and other.hp > 0 and point.distance_to(other.position) < 42: return false
	return true
