#!/usr/bin/env python3
"""Attach the approved illustrated foyer without erasing the functional kitchen.

This runs AFTER the NPC and interior navigation patches. The game archives,
starter furniture, currency and class systems stay untouched.
"""
from pathlib import Path

game=Path("scripts/game.gd")
src=game.read_text(encoding="utf-8")

def rep(before:str,after:str)->None:
    global src
    n=src.count(before)
    if n!=1:
        raise SystemExit("APPROVED FOYER PATCH ANCHOR FAILED (%d): %s" % (n,before[:100]))
    src=src.replace(before,after,1)

rep('var cottage_art: Node2D', '''var cottage_art: Node2D
var foyer_art: Node2D''')

rep('''\tcottage_art=null
\tplayer=null''', '''\tcottage_art=null
\tfoyer_art=null
\tplayer=null''')

rep('''\telif map_name=="cottage":
\t\tcottage_art=Node2D.new()
\t\tcottage_art.set_script(load("res://scripts/cottage_scene.gd"))
\t\tworld.add_child(cottage_art)
\telse:''',
'''\telif map_name=="cottage":
\t\tcottage_art=Node2D.new()
\t\tcottage_art.set_script(load("res://scripts/cottage_scene.gd"))
\t\tworld.add_child(cottage_art)
\telif map_name=="foyer":
\t\tfoyer_art=Node2D.new()
\t\tfoyer_art.set_script(load("res://scripts/foyer_scene.gd"))
\t\tworld.add_child(foyer_art)
\telse:''')

rep('''if map_name=="bedroom" or map_name=="cottage" or BUILDING_ART.has(map_name):camera.zoom''',
'''if map_name=="bedroom" or map_name=="cottage" or map_name=="foyer" or BUILDING_ART.has(map_name):camera.zoom''')

rep('''\t_label(hud,town_label,900,22,346,45,22,Color("f2daa5"),true)''',
'''\tif current_map=="foyer":town_label="COTTAGE FOYER"
\t_label(hud,town_label,900,22,346,45,22,Color("f2daa5"),true)''')

rep('''\thint_label=_label(hud,first_hint,265,654,700,47,20,Color("fff2ce"),true)''',
'''\tif current_map=="foyer":first_hint="Your cottage foyer leads to Elmwatch or back to your living room."
\thint_label=_label(hud,first_hint,265,654,700,47,20,Color("fff2ce"),true)''')

rep('''\tif current_map=="cottage":
\t\tif where.x<270''',
'''\tif current_map=="foyer":
\t\t# Keep the player inside the illustrated wooden walls.
\t\treturn where.x>=330 and where.x<=1720 and where.y>=395 and where.y<=1120
\tif current_map=="cottage":
\t\tif where.x<270''')

rep('''\telif current_map=="cottage":
\t\tvar target=_cottage_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Explore your home. Find the front door to Elmwatch."''',
'''\telif current_map=="cottage":
\t\tvar target=_cottage_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Explore your home. Find the front door to Elmwatch."
\telif current_map=="foyer":
\t\tvar target=_foyer_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Return to the living room or leave for Elmwatch."''')

rep('''\tif current_map=="cottage":
\t\t_interact_cottage()
\t\treturn''',
'''\tif current_map=="cottage":
\t\t_interact_cottage()
\t\treturn
\tif current_map=="foyer":
\t\t_interact_foyer()
\t\treturn''')

rep('''\tif _near_cottage_entry():
\t\t_enter_world("cottage",Vector2(1024,984))''',
'''\tif _near_cottage_entry():
\t\t_enter_world("foyer",Vector2(1024,935))''')

rep('''\t\t"Front Door":
\t\t\tvar first_visit=not bool(data.get("elmwatch_intro_seen",false))
\t\t\tdata["tutorial_stage"]="elmwatch"
\t\t\tdata["elmwatch_intro_seen"]=true
\t\t\t_enter_world("town",Vector2(540,1095))
\t\t\tif first_visit:
\t\t\t\t_show_journal("WELCOME TO ELMWATCH",[
\t\t\t\t\t"Fresh air, chimneys and the sound of merchants fill the streets of Elmwatch. Your cottage is near the edge of town.",
\t\t\t\t\t"Look for Ilyan Crest, the Guild Registrar, and Captain Elara Voss at the Adventurers Guild.",
\t\t\t\t\t"Your training begins here. You can return home through the cottage entrance whenever you need to rest."
\t\t\t\t])''',
'''\t\t"Front Door":
\t\t\t_enter_world("foyer",Vector2(580,735))''')

src+='''
# -- Approved illustrated cottage entrance, separate from kitchen/living room --
const FOYER_OBJECTS = {
\t"Living Room":Vector2(460,735),
\t"Front Door":Vector2(1024,1085)
}

func _foyer_target()->String:
\tif current_map!="foyer" or player==null:return ""
\tvar best:=""
\tvar nearest:=168.0
\tfor key in FOYER_OBJECTS.keys():
\t\tvar dist:float=player.position.distance_to(FOYER_OBJECTS[key])
\t\tif dist<nearest:
\t\t\tbest=key
\t\t\tnearest=dist
\treturn best

func _interact_foyer()->void:
\tmatch _foyer_target():
\t\t"Living Room":
\t\t\t_enter_world("cottage",Vector2(1024,984))
\t\t"Front Door":
\t\t\tvar first_visit=not bool(data.get("elmwatch_intro_seen",false))
\t\t\tdata["tutorial_stage"]="elmwatch"
\t\t\tdata["elmwatch_intro_seen"]=true
\t\t\t_enter_world("town",Vector2(580,1060))
\t\t\tif first_visit:
\t\t\t\t_show_journal("WELCOME TO ELMWATCH",[
\t\t\t\t\t"Fresh air, chimneys and the sound of merchants fill the streets of Elmwatch. Your cottage stands near the edge of town.",
\t\t\t\t\t"Look for Ilyan Crest and Captain Elara Voss at the Adventurers Guild.",
\t\t\t\t\t"You can return to the cottage foyer, your kitchen, and bedroom whenever you need rest."
\t\t\t\t])
\t\t_:
\t\t\t_message("Move near the bottom door to leave for Elmwatch, or west to return to the living room.")
'''
game.write_text(src,encoding="utf-8")
print("APPROVED FOYER PATCH OK: original cottage painting, kitchen, bedroom, Elmwatch transitions.")
