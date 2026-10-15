#!/usr/bin/env python3
"""Add Adventurer's Journal tutorial bubbles and named NPC dialogue panels.
Run AFTER apply_bedroom_tutorial.py, leaving the source ZIP untouched.
"""
from pathlib import Path
path = Path("scripts/game.gd")
src = path.read_text(encoding="utf-8")

def rep(old, new):
    global src
    if src.count(old) != 1:
        raise SystemExit(f"DIALOGUE PATCH ANCHOR FAILED ({src.count(old)}): {old[:100]!r}")
    src = src.replace(old, new, 1)

rep('''\t_enter_world("bedroom",BEDROOM_SPAWN)

func _make_actor''', '''\t_enter_world("bedroom",BEDROOM_SPAWN)
\t_show_intro_tutorial()

func _make_actor''')
rep('''\t\t_message("Well done! You've defeated three slimes. Elmwatch welcomes a true adventurer.")
\t\treturn
\t_message(str(n["name"])+" — "+str(n["role"])+"\\n\\n"+str(n["dialogue"]))''', '''\t\t_show_npc_chat(n,"Well done! You've defeated three slimes. Elmwatch welcomes a true adventurer.")
\t\treturn
\t_show_npc_chat(n)''')
rep('''\t\t\t_message("A good night's rest. Today is your first day as an adventurer!\\n\\nThe Elmwatch Guild is waiting beyond your home.")''', '''\t\t\t_show_journal("REST AND RECOVER",["Your bed restores your health. Make time to rest between dangerous expeditions.","Today is your first day as an adventurer. The guild in Elmwatch is waiting for you."])''')
rep('''\t\t\t_message("The doorway leads to your cottage hallway. We'll connect the kitchen, living room, and front entrance in the next home-building stage.")''', '''\t\t\t_show_journal("THE NEXT ROOM",["The hallway is beyond this door. Your kitchen, living room and the way into Elmwatch will open as the cottage is completed.","For now, explore the bedroom, organize your supplies, and try the mirror."])''')
src += '''
# -- Dialogue systems: story journal and conversations with town NPCs --
func _open_dialogue_panel()->Control:
\tif popup!=null and is_instance_valid(popup):popup.queue_free()
\tvar dialogue=Control.new()
\tdialogue.set_script(load("res://scripts/dialogue_ui.gd"))
\tdialogue.size=Vector2(1280,720)
\tui.add_child(dialogue)
\tpopup=dialogue
\treturn dialogue

func _show_journal(chapter:String,slides:Array,first_time:bool=false)->void:
\tvar panel=_open_dialogue_panel()
\tif first_time:panel.finished.connect(_complete_intro_tutorial)
\telse:panel.finished.connect(_dismiss_message)
\tpanel.configure_tutorial(chapter,slides)

func _show_intro_tutorial()->void:
\t_show_journal("PROLOGUE  /  YOUR FIRST DAY",[
\t\t"Morning light spills into your bedroom. Today is your first day as an adventurer. A whole world is waiting beyond these walls.",
\t\t"Use the left joystick or arrow keys to walk around. When you approach something interesting, tap TALK / USE to interact with it.",
\t\t"Your storage chest keeps items safe, and the dressing mirror lets you change your look. Rest in bed whenever you need to recover.",
\t\t"When you're ready, explore your home and head toward Elmwatch's Adventurers Guild. Your journey is just beginning."
\t],true)

func _complete_intro_tutorial()->void:
\tdata["tutorial_stage"]="explore"
\t_save()
\tif hint_label!=null and is_instance_valid(hint_label):
\t\thint_label.text="Explore your bedroom: bed, chest, mirror and doorway."
\t_dismiss_message()

func _npc_advice(name:String)->String:
\tmatch name:
\t\t"Ilyan Crest":return "Start at the Adventurers Guild. I'm the registrar; once you're ready, Captain Elara can teach you the basics."
\t\t"Mara Fenwick":return "Keep a few healing potions in your bag. A prepared adventurer is more likely to make it home."
\t\t"Brann Ironhand":return "There's no weapon or armor class restriction here. Try different equipment and improve your proficiency through practice."
\t\t"Tamsin Reed":return "An adventurer needs somewhere to rest. Visit the inn between quests, and don't rush into danger exhausted."
\t\t"Captain Elara Voss":return "Your first field exercise is to defeat three green slimes beyond the eastern gate. Return to me once you're done."
\t\t"Garrick Thorn":return "The eastern trail leads to Thornbrook Forest. Stay near the path until you understand the creatures living there."
\t\t"Sister Sera Vale":return "Even brave heroes need healing. I can help restore your health whenever you return to town."
\t\t"Neris Crowe":return "Magic rewards patience. Study what an enemy can do before you make a dangerous choice."
\treturn "Talk to the people of Elmwatch. Someone at the guild can point you toward your first adventure."

func _show_npc_chat(n:Dictionary, override_text:String="")->void:
\tvar panel=_open_dialogue_panel()
\tpanel.finished.connect(_dismiss_message)
\tvar npc_name=str(n.get("name","Villager"))
\tvar role=str(n.get("role","Resident"))
\tvar text_value=override_text if not override_text.is_empty() else str(n.get("dialogue","Welcome to Elmwatch!"))
\tvar npc_sprite="res://assets/npcs/%s/down_00.png" % str(n.get("variant",""))
\tpanel.configure_npc(npc_name,role,npc_sprite,text_value,_npc_advice(npc_name))
'''
path.write_text(src,encoding="utf-8")
print("DIALOGUE PATCH OK: journal on new-game, reusable tutorial help, portraits and NPC chats")
