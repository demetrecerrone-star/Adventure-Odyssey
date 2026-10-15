#!/usr/bin/env python3
"""Elmwatch milestone 4: a single map presence per resident, animated NPC poses.
Runs after apply_npc_interactions.py on the reconstructed project.
"""
from pathlib import Path

p=Path("scripts/game.gd")
src=p.read_text(encoding="utf-8")

def rep(before:str,after:str)->None:
    global src
    hits=src.count(before)
    if hits!=1:
        raise SystemExit("NPC PRESENCE ANCHOR FAILED (%d): %r" % (hits,before[:130]))
    src=src.replace(before,after,1)

rep('var npc_anim_clock := 0.0','var npc_anim_clock := 0.0\nvar npc_presence_key := -1')

rep('''\tif map_name=="town":
\t\t_spawn_npcs()
\t\t_add_elmwatch_signposts()
\telif BUILDING_ART.has(map_name):''',
'''\tnpc_presence_key=_presence_window()
\tif map_name=="town":
\t\t_spawn_npcs()
\t\t_add_elmwatch_signposts()
\telif BUILDING_ART.has(map_name):''')

rep('''func _spawn_npcs()->void:
\tfor entry in NPCS:
\t\tvar actor=_make_actor(world,entry[3],"npcs",entry[2],0.70)''',
'''func _spawn_npcs()->void:
\tfor entry in NPCS:
\t\tif _resident_location(str(entry[0]))!="town":continue
\t\tvar actor=_make_actor(world,entry[3],"npcs",entry[2],0.70)''')

rep('''func _spawn_building_residents(building:String)->void:
\tfor entry in NPCS:
\t\tvar resident_name:String=str(entry[0])
\t\tif not BUSINESS_RESIDENTS[building].has(resident_name):continue''',
'''func _spawn_building_residents(building:String)->void:
\tfor entry in NPCS:
\t\tvar resident_name:String=str(entry[0])
\t\tif not BUSINESS_RESIDENTS[building].has(resident_name):continue
\t\tif _resident_location(resident_name)!=building:continue''')

rep('''\tdata["world_minutes"]=fposmod(_world_minutes()+maxf(0.0,delta)*1.5,1440.0)
\tif clock_label!=null and is_instance_valid(clock_label):''',
'''\tdata["world_minutes"]=fposmod(_world_minutes()+maxf(0.0,delta)*1.5,1440.0)
\t_refresh_npc_presence()
\tif clock_label!=null and is_instance_valid(clock_label):''')

rep('''func _tick_town_residents(delta:float)->void:
\tif current_map!="town":return
\tnpc_anim_clock''',
'''func _tick_town_residents(delta:float)->void:
\tif current_map!="town":return
\t_refresh_npc_presence()
\tnpc_anim_clock''')

rep('''\t\tif to_target.length()<4.0:continue
\t\tvar step:Vector2''',
'''\t\tif to_target.length()<4.0:
\t\t\t_pose_resident(npc,false,delta)
\t\t\tcontinue
\t\tvar step:Vector2''')

rep('''\t\tif not _walkable(next):continue
\t\tif player!=null and next.distance_to(player.position)<35.0:continue''',
'''\t\tif not _walkable(next):
\t\t\t_pose_resident(npc,false,delta)
\t\t\tcontinue
\t\tif player!=null and next.distance_to(player.position)<35.0:
\t\t\t_pose_resident(npc,false,delta)
\t\t\tcontinue''')

rep('''\t\tvar spr:Sprite2D=npc["sprite"]
\t\tspr.texture=load(_sprite_path("npcs",key,face,int(npc_anim_clock*6.0)%3))''',
'''\t\tnpc["facing"]=face
\t\t_pose_resident(npc,true,delta)''')

rep('''\t\telse:prompt.text="Explore this building; the exit is to the south."''',
'''\t\telse:prompt.text="Staff return at 7 AM or 2 PM. Exit to the south." if npcs.is_empty() else "Explore this building; the exit is to the south."''')

src+='''
# -- Elmwatch milestone 4: residents exist in only one location at a time. --
func _presence_window()->int:
\tvar h:int=int(_world_minutes()/60.0)
\tif h>=22 or h<7:return 0 # Sleeping off-map overnight
\tif h<12:return 1          # At work
\tif h<14:return 2          # Lunch in town
\tif h<19:return 3          # Afternoon at work
\treturn 4                 # Evening in town

func _resident_location(name:String)->String:
\tvar phase:int=_presence_window()
\tif phase==0:return ""
\tfor building in BUSINESS_RESIDENTS.keys():
\t\tif BUSINESS_RESIDENTS[building].has(name):
\t\t\treturn str(building) if phase==1 or phase==3 else "town"
\t# Outdoor mentors, healer and scholar do not belong to a shop.
\treturn "town"

func _refresh_npc_presence()->void:
\tif current_map!="town" and not BUILDING_ART.has(current_map):return
\tvar phase:int=_presence_window()
\tif npc_presence_key==phase:return
\tnpc_presence_key=phase
\tfor npc in npcs:
\t\tvar actor:Node2D=npc["node"]
\t\tif is_instance_valid(actor):actor.queue_free()
\tnpcs.clear()
\tif current_map=="town":_spawn_npcs()
\telse:_spawn_building_residents(current_map)

func _pose_resident(npc:Dictionary,walking:bool,delta:float)->void:
\tvar spr:Sprite2D=npc["sprite"]
\tif spr==null or not is_instance_valid(spr):return
\tvar face:String=str(npc.get("facing","down"))
\tvar phase:float=float(npc.get("walk_anim_seconds",0.0))
\tif walking:phase+=maxf(delta,0.0)
\telse:phase=0.0
\tnpc["walk_anim_seconds"]=phase
\tvar frame:int=int(phase*6.0)%3 if walking else 0
\tvar sprite_path:String=_sprite_path("npcs",str(npc["variant"]),face,frame)
\tif not ResourceLoader.exists(sprite_path):
\t\tsprite_path=_sprite_path("npcs",str(npc["variant"]),"down",0)
\tif spr.texture==null or spr.texture.resource_path!=sprite_path:
\t\tspr.texture=load(sprite_path)
'''
p.write_text(src,encoding="utf-8")
print("NPC PRESENCE PATCH OK: no duplicate shopkeepers, schedule-aware staffing, walking/idle sprites.")
