#!/usr/bin/env python3
"""Slimes wander, chase, telegraph attacks and retreat when badly wounded.

Applied after combat feedback. Keep the four enemies, painted forest collision,
HP, Agility dodging, and rewards compatible with existing saves.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(a,b):
    global s
    n=s.count(a)
    if n!=1:raise SystemExit(f"SLIME AI ANCHOR FAILED ({n}): {a[:120]!r}")
    s=s.replace(a,b,1)

rep('''		mob["indicator"]=indicator
		mobs.append(mob)''',
'''		mob["indicator"]=indicator
		mob["home"]=where
		mob["state"]="wander"
		mob["roam_dir"]=Vector2.RIGHT.rotated(float(mobs.size())*1.83)
		mob["roam_timer"]=1.0+float(mobs.size())*0.35
		mob["attack_cd"]=1.1
		mob["windup"]=0.0
		mob["retreat_left"]=0.0
		mob["retreat_cd"]=0.0
		mob["hit_reaction"]=0.0
		mobs.append(mob)''')

rep('''		if monster_timer>2.1:
			monster_timer=0.0
			_enemy_attack()''',
'''		# Each slime has its own movement, attack windup and cooldown.
		_tick_slime_ai(delta)
		if monster_timer>1000.0:monster_timer=0.0''')

rep('''		var warning:bool=monster_timer>1.55 and player.position.distance_to(mob["node"].position)<105.0''',
'''		var warning:bool=str(mob.get("state",""))=="windup"''')

rep('''	best["hp"]=int(best["hp"])-dmg
	best["indicator"].call("update_health"''',
'''	best["hp"]=int(best["hp"])-dmg
	best["hit_reaction"]=0.25
	best["indicator"].call("update_health"''')

# The old global timer function no longer governs attacks, but remains a
# compatibility wrapper for scripted callers while behavior is per-enemy.
rep('''func _enemy_attack()->void:
	for mob in mobs:
		if not mob["alive"]:continue
		if player.position.distance_to(mob["node"].position)<105:
			var evade=minf(0.35,0.05+float(data["stats"]["Agility"])*0.003)
			if randf()<evade:
				_combat_popup(player.position,"DODGE",Color("#8ce7ee"))
				hint_label.text="DODGE! Your Agility avoided the attack."
			else:
				_combat_popup(player.position,"-5 HP",Color("#ff9a98"))
				data["hp"]=maxi(0,int(data["hp"])-5)
				hint_label.text="A slime hits you for 5 damage."
				_refresh_hud()
				if int(data["hp"])==0:
					data["hp"]=int(data["max_hp"])
					_enter_world("town",Vector2(1030,980))
					_message("You fainted and were brought safely back to Elmwatch.")
			return''',
'''func _enemy_attack()->void:
	# Compatibility for existing calls: attacks now originate per slime.
	for mob in mobs:
		if mob["alive"] and player.position.distance_to(mob["node"].position)<105:
			_slime_attack(mob)
			return''')

s+='''
# -- Thornbrook enemy behavior state machine -----------------------------------
# Movement is always checked against the painted-map collision. Player stamina,
# no-loot exploits, class equipment and the Guild quest are unaffected.
func _tick_slime_ai(delta:float)->void:
	if current_map!="forest" or player==null:return
	var dt:float=clampf(delta,0.0,0.15)
	for mob in mobs:
		if not bool(mob.get("alive",false)):continue
		mob["attack_cd"]=maxf(0.0,float(mob["attack_cd"])-dt)
		mob["retreat_cd"]=maxf(0.0,float(mob["retreat_cd"])-dt)
		mob["hit_reaction"]=maxf(0.0,float(mob["hit_reaction"])-dt)
		var actor:Node2D=mob["node"]
		var home:Vector2=mob["home"]
		var player_dist:float=actor.position.distance_to(player.position)
		var home_dist:float=actor.position.distance_to(home)
		var state:String=str(mob["state"])
		# A fleeing or windup slime can be defeated; never resurrect here.
		if state=="windup":
			mob["windup"]=maxf(0.0,float(mob["windup"])-dt)
			if player_dist>133.0:
				mob["state"]="pursue"
			elif float(mob["windup"])<=0.0:
				mob["state"]="attack"
				_slime_attack(mob)
				# _slime_attack can change the map if the player faints.
				if current_map!="forest":return
				mob["attack_cd"]=2.25
				mob["state"]="pursue"
			continue
		if state=="attack":
			mob["state"]="pursue"
			continue
		if home_dist>395.0 or (player_dist>425.0 and state!="wander"):
			mob["state"]="return"
			state="return"
		elif int(mob["hp"])<=11 and player_dist<190.0 and float(mob["retreat_cd"])<=0.0 and state!="retreat":
			mob["state"]="retreat"
			mob["retreat_left"]=1.6
			mob["retreat_cd"]=5.5
			state="retreat"
		elif player_dist<275.0 and state in ["wander","return"]:
			mob["state"]="pursue"
			state="pursue"
		if state=="return":
			if home_dist<24.0:
				mob["state"]="wander"
				mob["roam_timer"]=0.2
				continue
			_slime_move(mob,(home-actor.position).normalized(),98.0,dt)
		elif state=="retreat":
			mob["retreat_left"]=maxf(0.0,float(mob["retreat_left"])-dt)
			var away:Vector2=(actor.position-player.position).normalized()
			if away.length()<0.1:away=Vector2.RIGHT
			_slime_move(mob,away,130.0,dt)
			if float(mob["retreat_left"])<=0.0:
				mob["state"]="return"
		elif state=="pursue":
			if player_dist<100.0:
				if float(mob["attack_cd"])<=0.0:
					mob["state"]="windup"
					mob["windup"]=0.58
				continue
			_slime_move(mob,(player.position-actor.position).normalized(),106.0,dt)
		else:
			mob["roam_timer"]=float(mob["roam_timer"])-dt
			if float(mob["roam_timer"])<=0.0:
				var angle:float=float(randi_range(0,628))/100.0
				mob["roam_dir"]=Vector2.from_angle(angle)
				mob["roam_timer"]=randf_range(1.2,2.5)
			if home_dist>95.0:
				mob["roam_dir"]=(home-actor.position).normalized()
			_slime_move(mob,mob["roam_dir"],37.0,dt)

func _slime_move(mob:Dictionary,direction:Vector2,speed:float,dt:float)->void:
	var actor:Node2D=mob["node"]
	var next:Vector2=actor.position+direction*speed*dt
	if next.distance_to(mob["home"])>400.0:return
	# Let the player step away or around an enemy instead of overlapping it.
	if next.distance_to(player.position)<40.0:return
	if _walkable(next):
		actor.position=next
	# Enemies do not clip through another slime's body.
	# The 4 spawn points remain well spaced on the beginner path.

func _slime_attack(mob:Dictionary)->void:
	if current_map!="forest" or player==null or not mob["alive"]:return
	if mob["node"].position.distance_to(player.position)>110.0:return
	var evade:float=minf(0.35,0.05+float(data["stats"]["Agility"])*0.003)
	if randf()<evade:
		_combat_popup(player.position,"DODGE",Color("#8ce7ee"))
		hint_label.text="DODGE! Your Agility avoided the slime."
	else:
		_combat_popup(player.position,"-5 HP",Color("#ff9a98"))
		data["hp"]=maxi(0,int(data["hp"])-5)
		hint_label.text="A slime strikes! -5 HP"
		_refresh_hud()
		if int(data["hp"])==0:
			data["hp"]=int(data["max_hp"])
			_enter_world("town",Vector2(1030,980))
			_message("You fainted and were brought safely back to Elmwatch.")
'''
p.write_text(s,encoding="utf-8")
print("SLIME AI PATCH OK: wander, aggro, attack windup, retreat and leash-safe return.")
