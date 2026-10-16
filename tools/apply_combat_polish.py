#!/usr/bin/env python3
"""Combat polish on reconstructed AO game.gd: collision detours and pose-safe skills.

Run after oldstone_dungeon and before the icon/export step. Preserve legacy
state, class skills, item art, UI, and approved source images.
"""
from pathlib import Path

p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(old,new):
    global s
    n=s.count(old)
    if n!=1:
        raise SystemExit(f"COMBAT POLISH PATCH ANCHOR FAILED ({n}): {old[:120]!r}")
    s=s.replace(old,new,1)

# An attacking or casting character borrows a registered source animation
# frame, so hair and all seven worn gear sprites follow the identical pose.
# Dedicated bespoke attack/cast art can later replace this safe interim cue.
rep('var mentor_skill_cooldown:float=0.0',
'''var mentor_skill_cooldown:float=0.0
var combat_pose_timer:float=0.0
var combat_pose_kind:String=""''')
rep('''\tmentor_skill_cooldown=maxf(0.0,mentor_skill_cooldown-delta)''',
'''\tcombat_pose_timer=maxf(0.0,combat_pose_timer-delta)
\tmentor_skill_cooldown=maxf(0.0,mentor_skill_cooldown-delta)''')
rep('''func _set_player_frame()->void:
''','''func _set_player_frame()->void:
\tif combat_pose_timer>0.0:
\t\tanim_frame=1 if combat_pose_kind=="cast" else 2
''')
rep('''func _play_ability_fx(skill_name:String,kind:String)->void:
''','''func _play_ability_fx(skill_name:String,kind:String)->void:
\t_start_combat_pose(kind)
''')
# World expansion already broadens target selection beyond Thornbrook.
rep('''\teffect.call("configure",skill_name,player.position,target,accent)''',
'''\teffect.call("configure",skill_name,player.position,target,accent,kind)''')
rep('''\tvar accent:Color=Color(str(CLASS_ACCENTS.get(str(data.get("class","Warrior")),"#fff0cb")))
\tvar effect=Node2D.new()''',
'''\tif kind=="trap" and trap_timer>0.0:
\t\ttarget=trap_pos
\tvar accent:Color=Color(str(CLASS_ACCENTS.get(str(data.get("class","Warrior")),"#fff0cb")))
\tvar effect=Node2D.new()''')

# The original mover checks only the first attempted position, allowing a
# creature to stop forever against rocks/trees. Preserve walkable, home leash,
# player radius and slow effects; steer a little to either side when blocked.
rep('''\tvar slow_factor:float=0.45 if float(mob.get("slow_timer",0.0))>0.0 else 1.0
\tvar next:Vector2=actor.position+direction*speed*slow_factor*dt
\tif next.distance_to(mob["home"])>400.0:return
\t# Let the player step away or around an enemy instead of overlapping it.
\tif next.distance_to(player.position)<40.0:return
\tif _walkable(next):
\t\tactor.position=next''',
'''\tvar slow_factor:float=0.45 if float(mob.get("slow_timer",0.0))>0.0 else 1.0
\tvar step:float=speed*slow_factor*dt
\tif step<=0.0 or direction.length_squared()<0.0001:return
\tvar straight:Vector2=direction.normalized()
\tif _try_enemy_step(mob,straight,step):return
\t# Remember the detour side to avoid zigzagging at painted obstacles.
\tvar preferred:int=int(mob.get("avoid_turn",1))
\tfor angle in [0.75,1.3,PI/2.0]:
\t\tif _try_enemy_step(mob,straight.rotated(preferred*float(angle)),step):
\t\t\tmob["avoid_turn"]=preferred
\t\t\treturn
\t\tif _try_enemy_step(mob,straight.rotated(-preferred*float(angle)),step):
\t\t\tmob["avoid_turn"]=-preferred
\t\t\treturn
\tif str(mob.get("state",""))=="wander":
\t\tmob["roam_timer"]=0.0''')

s+='''
# -- First-pass collision detours and matching equipment combat poses ----------
func _try_enemy_step(mob:Dictionary,direction:Vector2,distance:float)->bool:
\tvar actor:Node2D=mob["node"]
\tvar next:Vector2=actor.position+direction*distance
\tif next.distance_to(mob["home"])>400.0:return false
\tif next.distance_to(player.position)<40.0:return false
\t# Check the center of the move too, not just the destination.
\tif not _walkable((actor.position+next)*0.5) or not _walkable(next):
\t\treturn false
\tfor other in mobs:
\t\tif other["node"]==actor or not bool(other.get("alive",false)):continue
\t\tif next.distance_to(other["node"].position)<34.0:return false
\tactor.position=next
\treturn true

func _start_combat_pose(kind:String)->void:
\tif player==null or not is_instance_valid(player):return
\tcombat_pose_kind="strike" if kind in ["cleave","stun","backstab","poison","holy"] else "cast"
\tcombat_pose_timer=0.28 if combat_pose_kind=="strike" else 0.34
\t_set_player_frame()
'''
p.write_text(s,encoding="utf-8")
print("AO COMBAT POLISH: PASS / steer around obstacles, named skill effects, pose-aligned worn gear")
