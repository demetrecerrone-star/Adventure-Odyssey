#!/usr/bin/env python3
"""Milestone 3: town resident routines, in-game time and staffed interiors.
Applies to the reconstructed Godot project after apply_elmwatch_art.py.
No cosmetic purchases, economy revisions or online services.
"""
from pathlib import Path

path=Path("scripts/game.gd")
src=path.read_text(encoding="utf-8")

def rep(before:str,after:str)->None:
    global src
    n=src.count(before)
    if n!=1:
        raise SystemExit(f"NPC ROUTINE PATCH ANCHOR FAILED ({n}): {before[:100]!r}")
    src=src.replace(before,after,1)

rep('const HOME_STARTER =', '''const BUSINESS_RESIDENTS = {
    "guild":["Ilyan Crest","Captain Elara Voss"],
    "market":["Mara Fenwick"],
    "inn":["Tamsin Reed"],
    "blacksmith":["Brann Ironhand"]
}
const BUSINESS_POSITIONS = {
    "Ilyan Crest":Vector2(1010,560),
    "Captain Elara Voss":Vector2(1410,670),
    "Mara Fenwick":Vector2(1050,595),
    "Tamsin Reed":Vector2(1380,540),
    "Brann Ironhand":Vector2(1220,590)
}
# Each destination is on a safe open pathway outside illustrated rooftops.
# Stages: morning work, midday errand, and evening stroll.
const NPC_ROUTINES = {
    "ilyan_crest":[Vector2(1555,1194),Vector2(1490,1124),Vector2(1630,1192)],
    "mara_fenwick":[Vector2(1500,610),Vector2(1610,550),Vector2(1580,635)],
    "brann_ironhand":[Vector2(1855,1198),Vector2(1890,1140),Vector2(1940,1180)],
    "tamsin_reed":[Vector2(750,570),Vector2(825,625),Vector2(680,590)],
    "captain_elara_voss":[Vector2(1370,1185),Vector2(1470,1110),Vector2(1335,1110)],
    "garrick_thorn":[Vector2(1890,820),Vector2(1935,875),Vector2(1870,914)],
    "sister_sera_vale":[Vector2(770,820),Vector2(845,790),Vector2(706,803)],
    "neris_crowe":[Vector2(1120,1150),Vector2(1055,1122),Vector2(1185,1165)]
}
const HOME_STARTER =''')

rep('var hint_label: Label', '''var clock_label: Label
var npc_anim_clock := 0.0
var hint_label: Label''')

rep('''\tif map_name=="town":
\t\t_spawn_npcs()
\t\t_add_elmwatch_signposts()
\telif map_name=="forest":_spawn_mobs()''',
'''\tif map_name=="town":
\t\t_spawn_npcs()
\t\t_add_elmwatch_signposts()
\telif BUILDING_ART.has(map_name):
\t\t_spawn_building_residents(map_name)
\telif map_name=="forest":_spawn_mobs()''')

rep('''\t\tnpcs.append(actor)

func _spawn_mobs()->void:''', '''\t\tactor["routine_state"]="Working"
\t\tactor["outdoor"]=true
\t\tnpcs.append(actor)

func _spawn_mobs()->void:''')

rep('''\t_label(hud,town_label,900,22,346,45,22,Color("f2daa5"),true)''',
'''\t_label(hud,town_label,900,22,346,45,22,Color("f2daa5"),true)
\tclock_label=_label(hud,_world_clock_text(),795,107,222,36,21,Color("#ffe1a0"),true)''')

rep('''\tattack_cooldown=maxf(0.0,attack_cooldown-delta)''',
'''\t_tick_world_time(delta)
\tif current_map=="town":_tick_town_residents(delta)
\tattack_cooldown=maxf(0.0,attack_cooldown-delta)''')

rep('''\tif player==null or current_map!="town":return {}''',
'''\tif player==null or (current_map!="town" and not BUILDING_ART.has(current_map)):return {}''')

rep('''\tif BUILDING_ART.has(current_map):
\t\tif player.position.distance_to(Vector2(1024,1090))<175.0:
\t\t\tvar saved_pos=data.get("town_return_pos",[1030.0,980.0])
\t\t\t_enter_world("town",Vector2(float(saved_pos[0]),float(saved_pos[1])))
\t\telse:
\t\t\t_message("Move toward the south entrance and press TALK / USE to return to Elmwatch.")
\t\treturn''',
'''\tif BUILDING_ART.has(current_map):
\t\tif player.position.distance_to(Vector2(1024,1090))<175.0:
\t\t\tvar saved_pos=data.get("town_return_pos",[1030.0,980.0])
\t\t\t_enter_world("town",Vector2(float(saved_pos[0]),float(saved_pos[1])))
\t\telse:
\t\t\tvar resident=_nearest_npc()
\t\t\tif not resident.is_empty():_show_npc_chat(resident)
\t\t\telse:_message("Move closer to someone to talk, or use the south entrance to return to Elmwatch.")
\t\treturn''')

rep('''\telif BUILDING_ART.has(current_map):
\t\tprompt.text="Use: Return to Elmwatch" if player.position.distance_to(Vector2(1024,1090))<175.0 else "Explore the building and find the exit."''',
'''\telif BUILDING_ART.has(current_map):
\t\tvar resident=_nearest_npc()
\t\tif player.position.distance_to(Vector2(1024,1090))<175.0:prompt.text="Use: Return to Elmwatch"
\t\telif not resident.is_empty():prompt.text="Talk: "+str(resident["name"])
\t\telse:prompt.text="Explore this building; the exit is to the south."''')

rep('''\tpanel.configure_npc(npc_name,role,npc_sprite,text_value,_npc_advice(npc_name))''',
'''\tif str(n.get("routine_state","Working"))=="On Break":
\t\trole += "  /  ON BREAK"
\telif str(n.get("routine_state","Working"))=="Evening Stroll":
\t\trole += "  /  EVENING"
\tpanel.configure_npc(npc_name,role,npc_sprite,text_value,_npc_advice(npc_name))''')

src += '''
# -- NPC milestone: deterministic local-time activities and staffed interiors. --
func _world_minutes()->float:
\treturn fposmod(float(data.get("world_minutes",540.0)),1440.0)

func _world_clock_text()->String:
\tvar minutes:int=int(_world_minutes())
\tvar hour:int=int(minutes/60)
\tvar h:int=hour%12
\tif h==0:h=12
\treturn "%d:%02d %s" % [h,minutes%60,"PM" if hour>=12 else "AM"]

func _tick_world_time(delta:float)->void:
\t# One in-game day takes 16 real-time minutes. Dialogues pause the clock.
\tdata["world_minutes"]=fposmod(_world_minutes()+maxf(0.0,delta)*1.5,1440.0)
\tif clock_label!=null and is_instance_valid(clock_label):
\t\tclock_label.text=_world_clock_text()

func _routine_slot()->int:
\tvar hour:int=int(_world_minutes()/60.0)
\tif hour>=12 and hour<14:return 1
\tif hour>=19 or hour<7:return 2
\treturn 0

func _routine_name(slot:int)->String:
\tmatch slot:
\t\t1:return "On Break"
\t\t2:return "Evening Stroll"
\treturn "Working"

func _tick_town_residents(delta:float)->void:
\tif current_map!="town":return
\tnpc_anim_clock+=maxf(0.0,delta)
\tvar slot:int=_routine_slot()
\tfor npc in npcs:
\t\tif not bool(npc.get("outdoor",false)):continue
\t\tvar key:String=str(npc["variant"])
\t\tif not NPC_ROUTINES.has(key):continue
\t\tnpc["routine_state"]=_routine_name(slot)
\t\tvar target:Vector2=NPC_ROUTINES[key][slot]
\t\tvar actor:Node2D=npc["node"]
\t\tvar to_target:Vector2=target-actor.position
\t\tif to_target.length()<4.0:continue
\t\tvar step:Vector2=to_target.normalized()*minf(46.0*maxf(delta,0.0),to_target.length())
\t\tvar next:Vector2=actor.position+step
\t\tif not _walkable(next):continue
\t\tif player!=null and next.distance_to(player.position)<35.0:continue
\t\tactor.position=next
\t\tvar face:String="down"
\t\tif absf(step.x)>absf(step.y):face="right" if step.x>0.0 else "left"
\t\telse:face="down" if step.y>0.0 else "up"
\t\tvar spr:Sprite2D=npc["sprite"]
\t\tspr.texture=load(_sprite_path("npcs",key,face,int(npc_anim_clock*6.0)%3))

func _spawn_building_residents(building:String)->void:
\tfor entry in NPCS:
\t\tvar resident_name:String=str(entry[0])
\t\tif not BUSINESS_RESIDENTS[building].has(resident_name):continue
\t\tvar actor=_make_actor(world,BUSINESS_POSITIONS[resident_name],"npcs",str(entry[2]),0.70)
\t\tactor["name"]=resident_name
\t\tactor["role"]=str(entry[1])
\t\tactor["dialogue"]=str(entry[4])
\t\tactor["routine_state"]="Working"
\t\tactor["outdoor"]=false
\t\tvar tag=Label.new()
\t\ttag.text=resident_name
\t\ttag.position=Vector2(-112,-205)
\t\ttag.size=Vector2(224,35)
\t\ttag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
\t\ttag.add_theme_font_size_override("font_size",20)
\t\ttag.add_theme_color_override("font_color",Color("#fff0bd"))
\t\tactor["node"].add_child(tag)
\t\tnpcs.append(actor)
'''
path.write_text(src,encoding="utf-8")
print("NPC LIFE PATCH OK: local world clock, routines, and NPC chats inside four buildings.")
