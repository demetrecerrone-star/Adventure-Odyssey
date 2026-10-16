#!/usr/bin/env python3
"""Refine visual targeting only; all gameplay mutations stay in their old paths."""
from pathlib import Path
import re

p = Path('scripts/game.gd')
s = p.read_text(encoding='utf-8')
replacement = '''func _play_ability_fx(skill_name:String,kind:String)->void:
\tif world==null or not is_instance_valid(world) or player==null:return
\t_start_combat_pose(kind)
\tvar origin:Vector2=player.position
\tvar target:Vector2=origin
\tvar reach:float=350.0
\tfor skill in _starter_skills():
\t\tif str(skill["name"])==skill_name:
\t\t\treach=float(skill.get("range",350.0))
\t\t\tbreak
\tvar targets:Array=_skill_targets(reach)
\tif not targets.is_empty():target=targets[0]["node"].position
\tif kind in ["heal","buff","barrier","shield","nova"] or skill_name in ["Earthshaker","Meteor Burst","Smoke Veil","Consecration"]:
\t\ttarget=origin
\telif kind=="trap":
\t\t# FX is invoked before the gameplay timer is set; compute this cast's site.
\t\ttarget=origin+_skill_facing()*130.0
\t\tif not _walkable(target):target=origin
\telif kind=="summon":
\t\ttarget=origin+Vector2(75,0)
\telif kind=="step":
\t\tif not targets.is_empty():
\t\t\tvar next:Vector2=target+(origin-target).normalized()*65.0
\t\t\ttarget=next if _walkable(next) else origin
\tvar accent:Color=Color(str(CLASS_ACCENTS.get(str(data.get("class","Warrior")),"#fff0cb")))
\tvar effect=Node2D.new()
\teffect.name="AbilityEffect"
\teffect.set_script(load("res://scripts/skill_effect.gd"))
\tworld.add_child(effect)
\teffect.call("configure",skill_name,origin,target,accent,kind,_skill_facing())
\tif skill_name=="Quick Volley":
\t\tvar destinations:Array=[]
\t\tfor i in range(mini(3,targets.size())):destinations.append(targets[i]["node"].position)
\t\teffect.call("set_target_positions",destinations)
'''
# Stop at the first non-indented declaration, preserving following constants.
pattern = r'(?m)^func _play_ability_fx\([^\n]*\n(?:\t[^\n]*\n|\n)*'
s, count = re.subn(pattern, lambda _: replacement+'\n', s)
if count != 1:
    raise SystemExit(f'READABLE FX ANCHOR FAILED: {count}')
p.write_text(s, encoding='utf-8')
print('AO READABLE FX: PASS / cast-site traps, real volley targets, facing-safe effects')
