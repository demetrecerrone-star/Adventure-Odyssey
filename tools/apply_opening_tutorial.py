#!/usr/bin/env python3
"""Contextual, save-persistent opening guidance, after house and town NPC patches."""
from pathlib import Path

p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(a,b):
    global s
    n=s.count(a)
    if n!=1:raise SystemExit(f"OPENING GUIDE ANCHOR FAILED ({n}): {a[:110]!r}")
    s=s.replace(a,b,1)

rep('''\t\t"Use the left joystick or arrow keys to walk around. When you approach something interesting, tap TALK / USE to interact with it.",''',
''' \t\t"Use the left joystick or arrow keys to walk. Approach a person, door or furnishing and tap TALK / USE to interact.",'''.lstrip())
rep('''\t\t"Your storage chest keeps items safe, and the dressing mirror lets you change your look. Rest in bed whenever you need to recover.",''',
'''\t\t"The chest stores equipment, your dressing mirror changes your look, and the bed restores health. All three remain yours whenever you return home.",''')
rep('''\t\t"When you're ready, explore your home and head toward Elmwatch's Adventurers Guild. Your journey is just beginning."''',
'''\t\t"From this single bedroom, explore the foyer and combined living room and kitchen. Look for pantry supplies before the front door takes you into Elmwatch."''')
rep('''\t\thint_label.text="Explore your bedroom: bed, chest, mirror and doorway."''',
'''\t\thint_label.text=_tutorial_hint()''')
rep('''\thint_label=_label(hud,first_hint,265,654,700,47,20,Color("fff2ce"),true)''',
'''\thint_label=_label(hud,_tutorial_hint(),265,654,700,47,20,Color("fff2ce"),true)''')
rep('''func _open_home_chest()->void:
\tif not data.has("storage")''',
'''func _open_home_chest()->void:
\t_tutorial_mark("chest_opened")
\tif not data.has("storage")''')
rep('''func _open_home_mirror()->void:
\tif mirror_backup.is_empty():''',
'''func _open_home_mirror()->void:
\t_tutorial_mark("mirror_opened")
\tif mirror_backup.is_empty():''')
rep('''\t\t"Bed":
\t\t\tdata["hp"]=int(data["max_hp"])''',
'''\t\t"Bed":
\t\t\t_tutorial_mark("bed_rest")
\t\t\tdata["hp"]=int(data["max_hp"])''')
rep('''func _enter_house_room(map_name:String,spawn:Vector2)->void:
\tdata["map"]=map_name''',
'''func _enter_house_room(map_name:String,spawn:Vector2)->void:
\tif map_name=="foyer":_tutorial_mark("foyer_seen")
\telif map_name=="living":_tutorial_mark("living_seen")
\telif map_name=="town":_tutorial_mark("elmwatch_seen")
\tdata["map"]=map_name''')
rep('''\t\t\tif not bool(data.get("cottage_pantry_claimed",false)):
\t\t\t\tdata["cottage_pantry_claimed"]=true''',
'''\t\t\tif not bool(data.get("cottage_pantry_claimed",false)):
\t\t\t\t_tutorial_mark("pantry_found")
\t\t\t\tdata["cottage_pantry_claimed"]=true''')
rep('''\t\t_enter_world(entry,Vector2(1024,980))
\t\treturn''',
'''\t\t_enter_world(entry,Vector2(1024,980))
\t\tif entry=="guild":_tutorial_mark("guild_entered")
\t\treturn''')
rep('''\tvar npc_name=str(n.get("name","Villager"))
\tvar role=str(n.get("role","Resident"))''',
'''\tvar npc_name=str(n.get("name","Villager"))
\tif npc_name=="Ilyan Crest":_tutorial_mark("registrar_spoken")
\telif npc_name=="Captain Elara Voss":_tutorial_mark("mentor_spoken")
\tvar role=str(n.get("role","Resident"))''')

s+='''
# Optional, saved first-day milestones. Nothing here locks a door or a quest.
func _tutorial_flags()->Dictionary:
\tif not data.has("tutorial_actions") or typeof(data["tutorial_actions"])!=TYPE_DICTIONARY:
\t\tdata["tutorial_actions"]={}
\treturn data["tutorial_actions"]

func _tutorial_mark(key:String)->void:
\tif bool(_tutorial_flags().get(key,false)):return
\tdata["tutorial_actions"][key]=true
\t_save()
\tif hint_label!=null and is_instance_valid(hint_label):
\t\thint_label.text=_tutorial_hint()

func _tutorial_hint()->String:
\tvar flags:Dictionary=_tutorial_flags()
\tmatch current_map:
\t\t"bedroom":
\t\t\tif str(data.get("tutorial_stage",""))=="wake":
\t\t\t\treturn "Your first day begins here. Read the Adventurer's Journal."
\t\t\tif not bool(flags.get("chest_opened",false)):
\t\t\t\treturn "Walk near your chest, then tap TALK / USE for home storage."
\t\t\tif not bool(flags.get("mirror_opened",false)):
\t\t\t\treturn "Try the dressing mirror, then find your bedroom doorway."
\t\t\treturn "Your bed restores health. Use the bedroom door when ready."
\t\t"foyer":
\t\t\tif not bool(flags.get("living_seen",false)):
\t\t\t\treturn "Explore the living room and kitchen through the left doorway."
\t\t\treturn "Your front door leads to Elmwatch; the bedroom is also here."
\t\t"living":
\t\t\tif not bool(flags.get("pantry_found",false)):
\t\t\t\treturn "Explore the hearth and kitchen; check the pantry for a potion."
\t\t\treturn "Return to the foyer through the bottom-center doorway."
\t\t"town":
\t\t\tif int(data.get("quest_kills",0))>=3 and not bool(data.get("guild_training_completed",false)):
\t\t\t\treturn "Well done! Report back to Captain Elara at the Guild."
\t\t\tif bool(flags.get("mentor_spoken",false)):
\t\t\t\treturn "Head east to Thornbrook and defeat three slimes for training."
\t\t\treturn "Visit the Adventurers Guild and talk to its registrar or mentor."
\t\t"guild":
\t\t\tif int(data.get("quest_kills",0))>=3:
\t\t\t\treturn "Speak to Captain Elara to report your training."
\t\t\treturn "Talk to Ilyan Crest and Captain Elara about your first assignment."
\t\t"forest":
\t\t\treturn "Defeat three green slimes, then return to Elmwatch."
\treturn "Explore and tap TALK / USE near people and interesting objects."
'''
p.write_text(s,encoding="utf-8")
print("OPENING TUTORIAL PATCH OK: bedroom, cottage, guild and first quest guidance.")
