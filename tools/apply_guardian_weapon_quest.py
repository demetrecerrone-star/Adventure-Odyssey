#!/usr/bin/env python3
"""One-time Guardian legacy quest, six unrestricted rewards, repeatable challenge.

Run after apply_ui_lifecycle_guard.py and after the normal item/loot patches.
All first-clear rewards are CLAIMED at Captain Elara's Guild dialogue, not
rolled from boss death. The story relic is moved to the claim reward and old
saves are upgraded to an unclaimed state without deleting their inventory.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
def once(a,b):
    global s
    n=s.count(a)
    if n!=1:raise SystemExit(f"AO GUARDIAN QUEST ANCHOR FAILED ({n}): {a[:110]!r}")
    s=s.replace(a,b,1)

once('const ITEM_CATALOG={\n',
'''const ITEM_CATALOG={
\t"Oldstone Oathblade":{"slot":"weapon","kind":"sword","power":14,"defense":0,"price":0,"rarity":"Epic","quest_reward":true},
\t"Oldstone Starbow":{"slot":"weapon","kind":"bow","power":13,"defense":0,"price":0,"rarity":"Epic","quest_reward":true},
\t"Oldstone Astral Staff":{"slot":"weapon","kind":"staff","power":14,"defense":0,"price":0,"rarity":"Epic","quest_reward":true},
\t"Oldstone Soulreaper":{"slot":"weapon","kind":"scythe","power":14,"defense":0,"price":0,"rarity":"Epic","quest_reward":true},
\t"Oldstone Twin Fangs":{"slot":"weapon","kind":"dagger","power":14,"defense":0,"price":0,"rarity":"Epic","quest_reward":true},
\t"Oldstone Dawnlance":{"slot":"weapon","kind":"spear","power":13,"defense":0,"price":0,"rarity":"Epic","quest_reward":true},
''')
# A first clear sets the quest-ready flag. Relic and 30 bonus Sigils wait for
# Captain Elara to award them; random 10%-for-5 boss Sigils stay independent.
once('\t\t\tdata["inventory"]["Guardian Relic"]=int(data["inventory"].get("Guardian Relic",0))+1',
'''\t\t\tdata["guardian_quest_state"]="ready"
\t\t\t_combat_popup(best["node"].position+Vector2(0,-95),"REPORT TO CAPTAIN ELARA",Color("#f5cf85"))''')
# The encounter can recur 60 real seconds after each defeat, but NOT before
# the one-time Guild quest reward is claimed.
once('\t\tbest["node"].hide()\n\t\tvar species:String=str(best.get("species","slime"))',
'''\t\tbest["node"].hide()
\t\tif str(best.get("species","slime"))=="guardian":
\t\t\tdata["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()
\t\tvar species:String=str(best.get("species","slime"))''')
once('\t\t_tick_slime_ai(delta)\n\t\tif monster_timer>1000.0:monster_timer=0.0',
'''\t\t_tick_slime_ai(delta)
\t\t_tick_guardian_respawn()
\t\tif monster_timer>1000.0:monster_timer=0.0''')
once('\tif bool(data.get("guardian_defeated",false)):return\n\t_spawn_custom_enemy("guardian",Vector2(1110,640),300,12,88.0,250,65,"")',
'''\tif bool(data.get("guardian_defeated",false)):
\t\tif str(data.get("guardian_quest_state",""))!="claimed":return
\t\tif not _guardian_respawn_ready():return
\t_spawn_custom_enemy("guardian",Vector2(1110,640),300,12,88.0,250,65,"")''')
once('\tif who=="Ilyan Crest" and bool(data.get("guild_training_completed",false))',
'''\tif who=="Captain Elara Voss" and str(data.get("guardian_quest_state",""))=="ready":
\t\t_show_npc_chat(n,"You've defended Oldstone and completed the Guardian Legacy! Claim your class's heirloom weapon, the Guardian Relic, and 30 Sigils for a first cottage cosmetic. The unique story reward can be claimed only once.")
\t\t_add_trade_action("CLAIM LEGACY",_claim_guardian_quest_reward)
\t\treturn
\tif who=="Ilyan Crest" and bool(data.get("guild_training_completed",false))''')
# Old characters who previously beat the one-time boss can claim the new
# first-clear class weapon. Do not remove any previously earned relic or gold.
once('\tdata = parsed\n\treturn true',
'''\tif bool(parsed.get("guardian_defeated",false)) and not parsed.has("guardian_quest_state"):
\t\tparsed["guardian_quest_state"]="ready"
\tdata = parsed
\treturn true''')
s+='''
# -- Guardian's Legacy: unique story instance and repeat boss encounters. ----
const GUARDIAN_LEGACY_WEAPONS={
\t"Warrior":"Oldstone Oathblade",
\t"Ranger":"Oldstone Starbow",
\t"Mage":"Oldstone Astral Staff",
\t"Necromancer":"Oldstone Soulreaper",
\t"Assassin":"Oldstone Twin Fangs",
\t"Paladin":"Oldstone Dawnlance"
}
const GUARDIAN_RESPAWN_SECONDS=60.0
const GUARDIAN_FIRST_QUEST_SIGILS=30

func _guardian_respawn_ready()->bool:
\tif not bool(data.get("guardian_defeated",false)):return true
\tif str(data.get("guardian_quest_state",""))!="claimed":return false
\treturn Time.get_unix_time_from_system()-float(data.get("guardian_last_defeat_unix",Time.get_unix_time_from_system()))>=GUARDIAN_RESPAWN_SECONDS

func _tick_guardian_respawn()->void:
\tif current_map!="sanctum" or not _guardian_respawn_ready():return
\tfor mob in mobs:
\t\tif str(mob.get("species",""))=="guardian" and bool(mob.get("alive",false)):return
\t_spawn_sanctum_guardian()

func _guardian_reward_weapon()->String:
\treturn str(GUARDIAN_LEGACY_WEAPONS.get(str(data.get("class","Warrior")),""))

func _claim_guardian_quest_reward()->bool:
\tif not bool(data.get("guardian_defeated",false)):return false
\tif str(data.get("guardian_quest_state",""))!="ready":return false
\tvar weapon:String=_guardian_reward_weapon()
\tif weapon.is_empty() or _gear_def(weapon).is_empty():return false
\t_ensure_gear()
\tdata["inventory"][weapon]=int(data["inventory"].get(weapon,0))+1
\t# Owners of an old save may already possess their unique story relic.
\tif int(data["inventory"].get("Guardian Relic",0))<1:
\t\tdata["inventory"]["Guardian Relic"]=1
\tdata["sigils"]=_sigils_balance()+GUARDIAN_FIRST_QUEST_SIGILS
\tdata["guardian_quest_weapon"]=weapon
\tdata["guardian_quest_state"]="claimed"
\t_save()
\t_refresh_hud()
\t_show_journal("GUARDIAN'S LEGACY  /  QUEST COMPLETE",[
\t\t"Captain Elara awards your one-time Oldstone heirloom: "+weapon+".",
\t\t"Your reward also includes a Guardian Relic and 30 Sigils, enough for your first cottage cosmetic when the special styles arrive.",
\t\t"Every class can equip every weapon. Your chosen class determines only which heirloom you receive as this quest reward.",
\t\t"The Guardian's challenge returns 60 seconds after each victory. Repeat fights give ordinary XP, gold, materials and their own rare boss loot rolls, never another story weapon or quest bonus."
\t])
\treturn true
'''
p.write_text(s,encoding="utf8")
print("AO GUARDIAN LEGACY QUEST: PASS / six class weapons, one-time Guild claim, 30 Sigils, 60s boss retry")
