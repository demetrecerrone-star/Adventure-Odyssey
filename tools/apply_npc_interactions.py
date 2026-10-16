#!/usr/bin/env python3
"""Keep gameplay interactions consistent indoors and outdoors after NPC routines."""
from pathlib import Path
path=Path("scripts/game.gd")
src=path.read_text(encoding="utf-8")

def rep(before:str,after:str)->None:
    global src
    n=src.count(before)
    if n!=1:
        raise SystemExit(f"NPC INTERACTION ANCHOR FAILED ({n}): {before[:100]!r}")
    src=src.replace(before,after,1)

rep('''\t\t\tif not resident.is_empty():_show_npc_chat(resident)''',
    '''\t\t\tif not resident.is_empty():_interact_resident(resident)''')

rep('''\tif n["name"]=="Sister Sera Vale":
\t\tdata["hp"]=int(data["max_hp"])
\t\t_refresh_hud()
\tif n["name"]=="Mara Fenwick":
\t\t# The merchant's proper store UI is a later milestone. Dialogue works now.
\t\tpass
\tif n["name"]=="Captain Elara Voss" and int(data["quest_kills"])>=3:
\t\t_show_npc_chat(n,"Well done! You've defeated three slimes. Elmwatch welcomes a true adventurer.")
\t\treturn
\t_show_npc_chat(n)''',
'''\t_interact_resident(n)''')

rep('''\t\tvar target:Vector2=NPC_ROUTINES[key][slot]
\t\tvar actor:Node2D=npc["node"]''',
'''\t\tvar target:Vector2=NPC_ROUTINES[key][slot]
\t\t# Alternate between the work spot and a nearby waypoint.
\t\tif slot==0 and int(_world_minutes()/7.0)%2==0:target+=Vector2(45,0)
\t\tvar actor:Node2D=npc["node"]''')

src += '''
# Common interactions work whether the resident is in the street or a building.
func _interact_resident(n:Dictionary)->void:
\tvar who:String=str(n.get("name",""))
\tif who=="Sister Sera Vale" and int(data["hp"])<int(data["max_hp"]):
\t\tdata["hp"]=int(data["max_hp"])
\t\t_refresh_hud()
\t\t_save()
\t\t_show_npc_chat(n,"Let me tend to your wounds. There, you're feeling much better! Take care on the road.")
\t\treturn
\tif who=="Captain Elara Voss" and int(data.get("quest_kills",0))>=3:
\t\tif not bool(data.get("guild_training_completed",false)):
\t\t\tdata["guild_training_completed"]=true
\t\t\t_save()
\t\t\t_show_npc_chat(n,"Well done! You've defeated three slimes. Your first guild training assignment is complete. Elmwatch welcomes a true adventurer!")
\t\telse:
\t\t\t_show_npc_chat(n,"You've completed your first guild training assignment. Keep practicing and explore Thornbrook carefully.")
\t\treturn
\t_show_npc_chat(n)
'''
path.write_text(src,encoding="utf-8")
print("NPC INTERACTIONS PATCH OK: patrol, healing and guild training in every location.")
