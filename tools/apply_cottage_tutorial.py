#!/usr/bin/env python3
"""Install playable cottage rooms AFTER home furniture and dialogue UI patches.

The archived v0.3 source remains unchanged; this is additive to the build.
Furniture cosmetics and purchasing are intentionally NOT modified.
"""
from pathlib import Path

path = Path("scripts/game.gd")
src = path.read_text(encoding="utf-8")

def rep(old: str, new: str) -> None:
    global src
    occurrences = src.count(old)
    if occurrences != 1:
        raise SystemExit(f"COTTAGE PATCH ANCHOR FAILED ({occurrences}): {old[:140]!r}")
    src = src.replace(old, new, 1)

rep('const HOME_STARTER =', '''const COTTAGE_OBJECTS = {
    "Bedroom Door": Vector2(1024,308),
    "Front Door": Vector2(1024,1095),
    "Hearth": Vector2(393,585),
    "Pantry": Vector2(1690,772),
    "Kitchen Table": Vector2(1337,643),
    "Travel Map": Vector2(656,467)
}
const HOME_STARTER =''')

rep('var bedroom_art: Node2D', '''var bedroom_art: Node2D
var cottage_art: Node2D''')

rep('''\tbedroom_art=null
\tplayer=null''', '''\tbedroom_art=null
\tcottage_art=null
\tplayer=null''')

rep('''\t\tbedroom_art.call("apply_styles", data["home_styles"])
\telse:
\t\tvar image=Sprite2D.new()''', '''\t\tbedroom_art.call("apply_styles", data["home_styles"])
\telif map_name=="cottage":
\t\tcottage_art=Node2D.new()
\t\tcottage_art.set_script(load("res://scripts/cottage_scene.gd"))
\t\tworld.add_child(cottage_art)
\telse:
\t\tvar image=Sprite2D.new()''')

rep('''\tif map_name=="bedroom":camera.zoom=Vector2(0.9,0.9)''',
'''\tif map_name=="bedroom" or map_name=="cottage":camera.zoom=Vector2(0.9,0.9)''')

rep('''\tvar town_label="YOUR BEDROOM" if current_map=="bedroom" else ("ELMWATCH VILLAGE" if current_map=="town" else "THORNBROOK FOREST")''',
'''\tvar town_label="YOUR BEDROOM" if current_map=="bedroom" else ("STARTER COTTAGE" if current_map=="cottage" else ("ELMWATCH VILLAGE" if current_map=="town" else "THORNBROOK FOREST"))''')

rep('''\tvar first_hint="Your first day as an adventurer! Look around your room." if current_map=="bedroom" else "Walk east to Thornbrook Forest"''',
'''\tvar first_hint="Your first day as an adventurer! Look around your room." if current_map=="bedroom" else ("Explore the cottage and find the front door." if current_map=="cottage" else ("Visit the Adventurers Guild." if current_map=="town" else "Walk west to return to Elmwatch."))''')

rep('''func _walkable(where:Vector2)->bool:
\tif current_map=="bedroom":''',
'''func _walkable(where:Vector2)->bool:
\tif current_map=="cottage":
\t\tif where.x<270 or where.x>1795 or where.y<280 or where.y>1136:return false
\t\t# Large pieces of furniture and fixed counters in the shared home.
\t\tfor obstacle in [Rect2(321,440,142,215),Rect2(508,658,327,150),Rect2(681,870,255,122),Rect2(1280,730,325,184),Rect2(1363,468,242,150),Rect2(1627,515,159,505),Rect2(1227,578,212,160)]:
\t\t\tif obstacle.has_point(where):return false
\t\treturn true
\tif current_map=="bedroom":''')

rep('''\tif current_map=="bedroom":
\t\tvar target=_bedroom_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Explore your room and try TALK / USE"
\telif current_map=="town" and nearby.size()>0:prompt.text="Talk: %s" % nearby["name"]''',
'''\tif current_map=="bedroom":
\t\tvar target=_bedroom_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Explore your room and try TALK / USE"
\telif current_map=="cottage":
\t\tvar target=_cottage_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Explore your home. Find the front door to Elmwatch."
\telif current_map=="town" and _near_cottage_entry():prompt.text="Use: Cottage Entrance"
\telif current_map=="town" and nearby.size()>0:prompt.text="Talk: %s" % nearby["name"]''')

rep('''func _interact()->void:
\tif current_map=="bedroom":
\t\t_interact_bedroom()
\t\treturn
\tif current_map!="town":return''',
'''func _interact()->void:
\tif current_map=="bedroom":
\t\t_interact_bedroom()
\t\treturn
\tif current_map=="cottage":
\t\t_interact_cottage()
\t\treturn
\tif current_map!="town":return''')

rep('''\tvar n=_nearest_npc()
\tif n.size()==0:
\t\t_message("Move closer to a villager to speak with them.")''',
'''\tif _near_cottage_entry():
\t\t_enter_world("cottage",Vector2(1024,984))
\t\treturn
\tvar n=_nearest_npc()
\tif n.size()==0:
\t\t_message("Move closer to a villager to speak with them.")''')

rep('''\t\t"Door":
\t\t\tdata["tutorial_stage"]="door"
\t\t\t_save()
\t\t\t_show_journal("THE NEXT ROOM",["The hallway is beyond this door. Your kitchen, living room and the way into Elmwatch will open as the cottage is completed.","For now, explore the bedroom, organize your supplies, and try the mirror."])''',
'''\t\t"Door":
\t\t\tvar first_visit=not bool(data.get("cottage_intro_seen",false))
\t\t\tdata["tutorial_stage"]="cottage"
\t\t\tdata["cottage_intro_seen"]=true
\t\t\t_enter_world("cottage",Vector2(1024,417))
\t\t\tif first_visit:
\t\t\t\t_show_journal("A HOME BEFORE THE JOURNEY",[
\t\t\t\t\t"The cottage opens into a warm hallway. There's a sitting room on one side and a little kitchen on the other.",
\t\t\t\t\t"Take a moment to explore. Interact with the hearth, the old travel map, or the pantry before you leave.",
\t\t\t\t\t"The front door leads to Elmwatch Village. Find the guild registrar to begin your first adventure."
\t\t\t\t])''')

src += '''
# -- Tutorial milestone two: a connected cottage and the first village exit. --
func _near_cottage_entry()->bool:
\treturn current_map=="town" and player!=null and player.position.distance_to(Vector2(540,1095))<108.0

func _cottage_target()->String:
\tif current_map!="cottage" or player==null:return ""
\tvar nearest:=157.0
\tvar selected:=""
\tfor name in COTTAGE_OBJECTS.keys():
\t\tvar d:float=player.position.distance_to(COTTAGE_OBJECTS[name])
\t\tif d<nearest:
\t\t\tselected=name
\t\t\tnearest=d
\treturn selected

func _interact_cottage()->void:
\tmatch _cottage_target():
\t\t"Bedroom Door":
\t\t\t_enter_world("bedroom",Vector2(1024,1010))
\t\t"Front Door":
\t\t\tvar first_visit=not bool(data.get("elmwatch_intro_seen",false))
\t\t\tdata["tutorial_stage"]="elmwatch"
\t\t\tdata["elmwatch_intro_seen"]=true
\t\t\t_enter_world("town",Vector2(540,1095))
\t\t\tif first_visit:
\t\t\t\t_show_journal("WELCOME TO ELMWATCH",[
\t\t\t\t\t"Fresh air, chimneys and the sound of merchants fill the streets of Elmwatch. Your cottage is near the edge of town.",
\t\t\t\t\t"Look for Ilyan Crest, the Guild Registrar, and Captain Elara Voss at the Adventurers Guild.",
\t\t\t\t\t"Your training begins here. You can return home through the cottage entrance whenever you need to rest."
\t\t\t\t])
\t\t"Hearth":
\t\t\t_show_journal("THE FAMILY HEARTH",["The embers still hold a little warmth. A peaceful place to return to after a difficult expedition."])
\t\t"Travel Map":
\t\t\t_show_journal("A MAP OF THE REGION",["Elmwatch is your starting town. Thornbrook Forest lies to the east, and the Adventurers Guild can guide you toward your first quest."])
\t\t"Kitchen Table":
\t\t\t_show_journal("BREAKFAST BEFORE ADVENTURE",["A little breakfast and a quiet morning. The people of Elmwatch are already preparing for another busy day."])
\t\t"Pantry":
\t\t\tif not bool(data.get("cottage_pantry_claimed",false)):
\t\t\t\tdata["cottage_pantry_claimed"]=true
\t\t\t\tdata["inventory"]["Health Potion"]=int(data["inventory"].get("Health Potion",0))+1
\t\t\t\t_save()
\t\t\t\t_show_journal("A USEFUL SUPPLY",["You discover one Health Potion in the kitchen pantry. It's been added to your backpack. The pantry won't replenish it automatically."])
\t\t\telse:
\t\t\t\t_show_journal("KITCHEN PANTRY",["Dry herbs, flour and empty jars line the shelves. You've already collected the spare potion."])
\t\t_:
\t\t\t_message("Walk closer to the doors, travel map, hearth, kitchen table or pantry, then tap TALK / USE.")
'''
path.write_text(src,encoding="utf-8")
print("COTTAGE PATCH OK: kitchen, living area, hallway, village exit and return.")
