#!/usr/bin/env python3
"""Install visual-only sprite-sheet animation after apply_combat_polish.py.

Artwork: 512x768 PNG; 128px cells, four frames per row. Rows are walk
down/right/up, then attack down/right/up; left mirrors right only. AI, damage,
collision, loot, and the original Thornbrook slime are deliberately unchanged.
"""
from pathlib import Path
p = Path('scripts/game.gd')
s = p.read_text(encoding='utf-8')
if 'func _configure_monster_animation(' in s:
    print('Monster animation already applied')
    raise SystemExit(0)
def rep(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit(f'MONSTER ANIMATION PATCH ANCHOR FAILED: {old[:100]!r}')
    s = s.replace(old, new, 1)

rep('if mob["alive"] and str(mob.get("species","slime"))=="slime":',
    'if mob["alive"] and str(mob.get("species","slime"))=="slime" and not mob.has("animation_appearance"):')
rep('\tmobs.append(enemy)\n\treturn enemy',
    '\t_configure_monster_animation(enemy,species)\n\tmobs.append(enemy)\n\treturn enemy')
rep('\tenemy["appearance"]=appearance',
    '\tenemy["appearance"]=appearance\n\t_configure_monster_animation(enemy,appearance)')
rep('func _tick_slime_ai(delta:float)->void:', '''func _tick_slime_ai(delta:float)->void:
	var animation_world:Node2D=world
	_tick_slime_ai_state(delta)
	if world!=animation_world:return
	if not _is_adventure_combat_zone() or player==null:return
	_tick_monster_animations(delta)

func _tick_slime_ai_state(delta:float)->void:''')
rep('''func _slime_attack(mob:Dictionary)->void:
	if not _is_adventure_combat_zone() or player==null or not mob["alive"]:return''', '''func _slime_attack(mob:Dictionary)->void:
	if not _is_adventure_combat_zone() or player==null or not mob["alive"]:return
	# A visual cue for this real attack attempt, including misses/blocks.
	if mob.has("animation_appearance"):mob["animation_recovery"]=0.32''')
s += '''
# -- Creature sprites: presentation only; never invoke combat from animation. --
const MONSTER_ANIMATION_ART="res://assets/creatures/animated/"
const MONSTER_ANIMATION_KEYS=["wolf","goblin","fungus","guardian","ruins_wolf","ruins_archer","stone_golem","cursed_fungus","stone_goblin","spore_bat","ruins_skeleton"]

func _configure_monster_animation(mob:Dictionary,appearance:String)->void:
	if not appearance in MONSTER_ANIMATION_KEYS:return
	var path:String=MONSTER_ANIMATION_ART+appearance+".png"
	if not ResourceLoader.exists(path):return
	var texture:Texture2D=load(path)
	if texture==null or texture.get_size()!=Vector2(512,768):return
	var sprite:Sprite2D=mob["sprite"]
	sprite.texture=texture
	sprite.hframes=4
	sprite.vframes=6
	sprite.frame=0
	sprite.flip_h=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var footprint:float=300.0 if appearance=="guardian" else (160.0 if mob.has("appearance") else 140.0)
	sprite.scale=Vector2.ONE*(footprint/128.0)
	# Art cells share a baseline at y=120; the actor remains the collision foot.
	sprite.position=Vector2(0,-56.0*sprite.scale.y)
	mob["animation_appearance"]=appearance
	mob["animation_walk_time"]=0.0
	mob["animation_direction"]="down"
	mob["animation_recovery"]=0.0
	mob["animation_position"]=mob["node"].position

func _tick_monster_animations(delta:float)->void:
	var dt:float=clampf(delta,0.0,0.15)
	for mob in mobs:
		if not bool(mob.get("alive",false)) or not mob.has("animation_appearance"):continue
		var sprite:Sprite2D=mob["sprite"]
		var actor:Node2D=mob["node"]
		if not is_instance_valid(sprite) or not is_instance_valid(actor):continue
		var displacement:Vector2=actor.position-Vector2(mob["animation_position"])
		mob["animation_position"]=actor.position
		var state:String=str(mob.get("state","wander"))
		var recovering:float=float(mob.get("animation_recovery",0.0))
		var facing:Vector2=displacement if recovering<=0.0 else Vector2.ZERO
		if state=="windup" and player!=null:facing=player.position-actor.position
		if facing.length_squared()>0.001:
			if absf(facing.y)>absf(facing.x):
				mob["animation_direction"]="up" if facing.y<0.0 else "down"
			else:
				mob["animation_direction"]="left" if facing.x<0.0 else "right"
		var direction:String=str(mob.get("animation_direction","down"))
		var walk_row:int=2 if direction=="up" else (0 if direction=="down" else 1)
		var walk_base:int=walk_row*4
		var attack_base:int=(walk_row+3)*4
		sprite.flip_h=direction=="left"
		if float(mob.get("stun_timer",0.0))>0.0:
			mob["animation_recovery"]=0.0
			sprite.frame=walk_base
		elif state=="windup":
			var duration:float=1.15 if str(mob.get("species",""))=="guardian" else 0.58
			var progress:float=1.0-clampf(float(mob.get("windup",duration))/duration,0.0,1.0)
			sprite.frame=attack_base+mini(1,int(progress*2.0))
		elif recovering>0.0:
			sprite.frame=attack_base+(2 if recovering>0.16 else 3)
			mob["animation_recovery"]=maxf(0.0,recovering-dt)
		elif displacement.length_squared()>0.001:
			mob["animation_walk_time"]=fposmod(float(mob["animation_walk_time"])+dt,0.5)
			sprite.frame=walk_base+int(float(mob["animation_walk_time"])*8.0)%4
		else:
			mob["animation_walk_time"]=0.0
			sprite.frame=walk_base
'''
p.write_text(s, encoding='utf-8')
print('Applied visual-only monster sprite animation')
