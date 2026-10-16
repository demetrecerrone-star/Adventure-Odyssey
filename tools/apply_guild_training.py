#!/usr/bin/env python3
"""Add the voluntary Guild training offer, combat tutorial and one-time rewards.

Run AFTER apply_opening_tutorial.py. Preserve existing kills, XP, free stat
allocation, NPC schedules, unrestricted equipment and single-bedroom house.
"""
from pathlib import Path

p=Path("scripts/game.gd")
src=p.read_text(encoding="utf-8")

def rep(before: str, after: str) -> None:
    global src
    count=src.count(before)
    if count!=1:
        raise SystemExit(f"GUILD TRAINING PATCH ANCHOR FAILED ({count}): {before[:130]!r}")
    src=src.replace(before,after,1)

rep('''\t_refresh_hud()
\t_save()

func _spawn_npcs()->void:''',
'''\t_refresh_hud()
\t_save()
\tif map_name=="forest" and not bool(data.get("forest_combat_intro_seen",false)):
\t\tdata["forest_combat_intro_seen"]=true
\t\t_save()
\t\t_show_journal("THORNBROOK FOREST  /  FIELD BASICS",[
\t\t\t"Green slimes are your first opponents. Approach one, then tap ATTACK when it is close enough. Each strike has a short cooldown.",
\t\t\t"Monsters can hurt you when nearby. Your Agility gives you a chance to dodge automatically. Watch your HP at the top of the screen.",
\t\t\t"Use BAG to drink a Health Potion when injured. You can retreat west to Elmwatch, rest at home or visit Sister Sera.",
\t\t\t"Defeat three green slimes, then return to Captain Elara at the Adventurers Guild to finish your training. Good luck!"
\t\t])

func _spawn_npcs()->void:''')

rep('''\tif who=="Captain Elara Voss" and int(data.get("quest_kills",0))>=3:''',
'''\tif who=="Captain Elara Voss" and not bool(data.get("slime_training_accepted",false)) and not bool(data.get("guild_training_completed",false)) and int(data.get("quest_kills",0))<3:
\t\t_show_npc_chat(n,"Ready for your first field exercise? Travel east to Thornbrook Forest and defeat three green slimes. You'll keep the experience and gold you earn, and I'll provide a Guild reward when you return. You can accept now or come back later.")
\t\tpopup.offer_quest_accept(_accept_slime_training)
\t\treturn
\tif who=="Captain Elara Voss" and int(data.get("quest_kills",0))>=3:''')

rep('''\t\t\tdata["guild_training_completed"]=true
\t\t\t_save()
\t\t\t_show_npc_chat(n,"Well done! You've defeated three slimes. Your first guild training assignment is complete. Elmwatch welcomes a true adventurer!")''',
'''\t\t\tdata["guild_training_completed"]=true
\t\t\tdata["slime_training_accepted"]=true
\t\t\tdata["gold"]=int(data["gold"])+20
\t\t\tdata["inventory"]["Health Potion"]=int(data["inventory"].get("Health Potion",0))+1
\t\t\t_refresh_hud()
\t\t\t_save()
\t\t\t_show_npc_chat(n,"Well done! You've defeated three slimes. Your first guild training assignment is complete. You earned 20 gold and a Health Potion. Elmwatch welcomes a true adventurer!")''')

rep('''\t\treturn
\t_show_npc_chat(n)

# -- Elmwatch milestone 4:''',
'''\t\treturn
\tif who=="Captain Elara Voss" and bool(data.get("slime_training_accepted",false)):
\t\t_show_npc_chat(n,"You're making progress: %d of 3 green slimes defeated. Thornbrook Forest lies east of Elmwatch. Use ATTACK when close to a slime, and drink a potion if you're hurt." % mini(3,int(data.get("quest_kills",0))))
\t\treturn
\t_show_npc_chat(n)

# -- Elmwatch milestone 4:''')

rep('''\t\thint_label.text="%d damage to green slime" % dmg''',
'''\t\thint_label.text="%d damage to green slime! ATTACK again after the cooldown." % dmg''') if False else None
# The attack feedback line has only one tab in the Godot source.
rep('''\thint_label.text="%d damage to green slime" % dmg''',
'''\thint_label.text="%d damage! Press ATTACK again after its short cooldown." % dmg''')

rep('''\t\telif int(data["quest_kills"])==3:
\t\t\thint_label.text="Slime quest complete! Return to Captain Elara."
\t\t_save()
\t\t_refresh_hud()''',
'''\t\t_save()
\t\t_refresh_hud()
\t\tif int(data["quest_kills"])>=3 and not bool(data.get("guild_training_completed",false)) and not bool(data.get("slime_training_ready_shown",false)):
\t\t\tdata["slime_training_ready_shown"]=true
\t\t\t_save()
\t\t\t_show_journal("FIRST FIELD ASSIGNMENT COMPLETE",[
\t\t\t\t"Three green slimes defeated! You have proven you can use ATTACK, manage your HP and survive an encounter.",
\t\t\t\t"Head west to Elmwatch, enter the Adventurers Guild and speak to Captain Elara to report your result and receive a one-time reward.",
\t\t\t\t"Every level grants five free stat points. Open STATS to assign them however you like. Your equipment choices remain unrestricted."
\t\t\t])
\t\telif current_map=="forest":
\t\t\thint_label.text=_tutorial_hint()''')

rep('''\thp_label.text="HP %d/%d     EXP %d/%d     Gold %d     Quest: %d/3" % [int(data["hp"]),int(data["max_hp"]),int(data["xp"]),int(data["level"])*50,int(data["gold"]),int(data["quest_kills"])]''',
'''\tvar mission:String="Guild: DONE" if bool(data.get("guild_training_completed",false)) else ("Slimes: %d/3" % mini(3,int(data.get("quest_kills",0))))
\thp_label.text="HP %d/%d     EXP %d/%d     Gold %d     %s" % [int(data["hp"]),int(data["max_hp"]),int(data["xp"]),int(data["level"])*50,int(data["gold"]),mission]''')

rep('''\t\t"town":
\t\t\tif int(data.get("quest_kills",0))>=3 and not bool(data.get("guild_training_completed",false)):''',
'''\t\t"town":
\t\t\tif bool(data.get("guild_training_completed",false)):
\t\t\t\treturn "Guild training complete! Explore Elmwatch or prepare for your next journey."
\t\t\tif int(data.get("quest_kills",0))>=3 and not bool(data.get("guild_training_completed",false)):''')

rep('''\t\t\tif bool(flags.get("mentor_spoken",false)):
\t\t\t\treturn "Head east to Thornbrook and defeat three slimes for training."
\t\t\treturn "Visit the Adventurers Guild and talk to its registrar or mentor."''',
'''\t\t\tif bool(data.get("slime_training_accepted",false)):
\t\t\t\treturn "Guild training: %d/3 slimes. Head east to Thornbrook Forest." % mini(3,int(data.get("quest_kills",0)))
\t\t\tif bool(flags.get("mentor_spoken",false)):
\t\t\t\treturn "Return to Captain Elara and select ACCEPT QUEST to begin training."
\t\t\treturn "Visit the Adventurers Guild and speak to Captain Elara."''')

rep('''\t\t"guild":
\t\t\tif int(data.get("quest_kills",0))>=3:''',
'''\t\t"guild":
\t\t\tif bool(data.get("guild_training_completed",false)):
\t\t\t\treturn "Your first Guild assignment is complete. Safe travels!"
\t\t\tif int(data.get("quest_kills",0))>=3:''')

rep('''\t\t\treturn "Talk to Ilyan Crest and Captain Elara about your first assignment."
\t\t"forest":
\t\t\treturn "Defeat three green slimes, then return to Elmwatch."''',
'''\t\t\tif bool(data.get("slime_training_accepted",false)):
\t\t\t\treturn "Field assignment: %d/3 slimes. The eastern trail leads to Thornbrook." % mini(3,int(data.get("quest_kills",0)))
\t\t\treturn "Talk to Captain Elara and select ACCEPT QUEST for your first mission."
\t\t"forest":
\t\t\tif int(data.get("quest_kills",0))>=3:
\t\t\t\treturn "Three slimes defeated! Travel west and report to Captain Elara."
\t\t\tif bool(data.get("slime_training_accepted",false)):
\t\t\t\treturn "Guild training %d/3. ATTACK near slimes; BAG has potions." % int(data.get("quest_kills",0))
\t\t\treturn "Practice ATTACK near slimes, then ask Captain Elara for training."''')

src+='''
# -- First Guild assignment: explicit acceptance, persistent completion, one-time reward. --
func _accept_slime_training()->void:
\tif bool(data.get("guild_training_completed",false)) or bool(data.get("slime_training_accepted",false)):
\t\treturn
\tdata["slime_training_accepted"]=true
\t_tutorial_mark("slime_training_accepted")
\t_save()
\t_show_journal("GUILD ASSIGNMENT  /  GREEN SLIMES",[
\t\t"Captain Elara has accepted you for your first field training. Your objective is to defeat three green slimes in Thornbrook Forest.",
\t\t"Leave the Guild through its southern doorway, then follow Elmwatch's eastern trail into the forest.",
\t\t"Get close to a green slime and press ATTACK. Every hit has a brief cooldown. Your Agility can automatically dodge attacks.",
\t\t"Watch your HP. BAG contains healing potions, Sister Sera can heal you in Elmwatch, and your cottage bed restores health.",
\t\t"After defeating three slimes, return to Captain Elara for a one-time reward: 20 gold and a Health Potion."
\t])
'''
p.write_text(src,encoding="utf-8")
print("GUILD TRAINING PATCH OK: accept quest, first forest tutorial, kill progress and single reward.")
