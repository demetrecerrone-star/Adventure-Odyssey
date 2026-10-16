#!/usr/bin/env python3
"""First learnable skill for all six classes, earned through a mentor field trial.

Run after apply_slime_ai.py. The first Guild quest remains the prerequisite;
combat rewards, free stat points and unrestricted equipment remain unchanged.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")

def rep(a,b):
    global s
    count=s.count(a)
    if count!=1:raise SystemExit(f"CLASS SKILLS PATCH ANCHOR FAILED ({count}): {a[:100]!r}")
    s=s.replace(a,b,1)

rep('''var attack_cooldown := 0.0''',
'''var attack_cooldown := 0.0
var skill_cooldown := 0.0''')
rep('''	attack_cooldown=maxf(0.0,attack_cooldown-delta)
	var axis=movement+_key_axis()''',
'''	attack_cooldown=maxf(0.0,attack_cooldown-delta)
	skill_cooldown=maxf(0.0,skill_cooldown-delta)
	var axis=movement+_key_axis()''')

rep('''	_button(hud,"ATTACK",1022,558,218,60,_attack)''',
'''	_button(hud,"ATTACK",1022,558,218,60,_attack)
	_button(hud,"SKILL",1022,625,218,57,_use_class_skill)''')

# The first skill quest appears at the appropriate established town mentor
# after the basic three-slime Guild assignment. Healer services stay available.
rep('''	if who=="Captain Elara Voss" and not bool(data.get("slime_training_accepted",false))''',
'''	if bool(data.get("guild_training_completed",false)) and who==_skill_mentor() and not bool(data.get("skill_unlocked",false)):
		if not bool(data.get("skill_trial_accepted",false)):
			_show_npc_chat(n,"Ready to learn %s? Land four basic hits on slimes in Thornbrook, then return to me. Your class skill will be yours." % str(_class_skill()["name"]))
			popup.offer_quest_accept(_accept_skill_trial)
		elif int(data.get("skill_trial_hits",0))>=4:
			_complete_skill_trial()
		else:
			_show_npc_chat(n,"Your skill training is underway: %d/4 basic attacks landed in Thornbrook. Return when you've completed the trial." % int(data.get("skill_trial_hits",0)))
		return
	if who=="Captain Elara Voss" and not bool(data.get("slime_training_accepted",false))''')

rep('''			if bool(data.get("guild_training_completed",false)):
				return "Guild training complete! Explore Elmwatch or prepare for your next journey."''',
'''			if bool(data.get("guild_training_completed",false)):
				if bool(data.get("skill_unlocked",false)):
					return "%s learned! Try your SKILL button in Thornbrook." % str(_class_skill()["name"])
				if bool(data.get("skill_trial_accepted",false)):
					return "Skill training: %d/4 basic hits. Return to %s." % [mini(4,int(data.get("skill_trial_hits",0))),_skill_mentor()]
				return "Ask %s about your first class skill." % _skill_mentor()''')

rep('''			if bool(data.get("guild_training_completed",false)):
				return "Your first Guild assignment is complete. Safe travels!"''',
'''			if bool(data.get("guild_training_completed",false)):
				if bool(data.get("skill_unlocked",false)):
					return "Your signature class skill is ready; use SKILL in combat."
				if bool(data.get("skill_trial_accepted",false)):
					return "Skill training: %d/4 basic hits. Visit your mentor to finish." % mini(4,int(data.get("skill_trial_hits",0)))
				return "Guild training is complete. Seek %s for skill training." % _skill_mentor()''')

rep('''		"forest":
			if int(data.get("quest_kills",0))>=3:''',
'''		"forest":
			if bool(data.get("skill_trial_accepted",false)) and not bool(data.get("skill_unlocked",false)):
				return "Skill trial: %d/4 ATTACK hits. Return to %s afterward." % [mini(4,int(data.get("skill_trial_hits",0))),_skill_mentor()]
			if bool(data.get("skill_unlocked",false)):
				return "Use SKILL: %s. It has its own cooldown." % str(_class_skill()["name"])
			if int(data.get("quest_kills",0))>=3:''')

# Replace the damage/reward portion only, preserving the existing attack
# targeting and cooldown logic. Both normal hits and class skills now share
# one central damage/death/reward implementation.
begin=s.index('\tvar dmg=8+int(int(data["stats"]["Strength"]) / 2)',s.index('func _attack()->void:'))
end=s.index('func _enemy_attack()->void:',begin)
if begin<0 or end<0 or end<=begin:
    raise SystemExit("CLASS SKILLS PATCH: cannot locate original attack resolution")
s=s[:begin]+'''	var dmg=8+int(int(data["stats"]["Strength"]) / 2)
	_apply_slime_damage(best,dmg,false)

func _apply_slime_damage(best:Dictionary,dmg:int,skill_hit:bool)->void:
	if current_map!="forest" or not bool(best.get("alive",false)):return
	best["hp"]=int(best["hp"])-dmg
	best["hit_reaction"]=0.25
	best["indicator"].call("update_health",int(best["hp"]),int(best["max_hp"]))
	_combat_popup(best["node"].position,"-%d" % dmg,Color("#b4ddff") if skill_hit else Color("#ffe7a0"))
	hint_label.text="%s: %d damage!" % [str(_class_skill()["name"]),dmg] if skill_hit else "%d damage! Press ATTACK again after its short cooldown." % dmg
	if not skill_hit and bool(data.get("skill_trial_accepted",false)) and not bool(data.get("skill_unlocked",false)):
		if int(data.get("skill_trial_hits",0))<4:
			data["skill_trial_hits"]=int(data.get("skill_trial_hits",0))+1
			_save()
			if int(data["skill_trial_hits"])==4:
				_show_journal("CLASS SKILL TRIAL COMPLETE",[
					"Four ordinary attacks landed! Your practice shows that you can control your strikes even as enemies move.",
					"Return to %s in Elmwatch to learn %s. Your class determines the technique; equipment stays unrestricted." % [_skill_mentor(),str(_class_skill()["name"])]
				])
	if int(best["hp"])<=0:
		best["alive"]=false
		best["node"].hide()
		data["xp"]=int(data["xp"])+25
		data["gold"]=int(data["gold"])+3
		data["quest_kills"]=int(data["quest_kills"])+1
		if int(data["xp"])>=int(data["level"])*50:
			data["xp"]=int(data["xp"])-int(data["level"])*50
			data["level"]=int(data["level"])+1
			data["points"]=int(data["points"])+5
			hint_label.text="LEVEL UP! +5 free stat points"
		_save()
		_refresh_hud()
		if int(data["quest_kills"])>=3 and not bool(data.get("guild_training_completed",false)) and not bool(data.get("slime_training_ready_shown",false)):
			data["slime_training_ready_shown"]=true
			_save()
			_show_journal("FIRST FIELD ASSIGNMENT COMPLETE",[
				"Three green slimes defeated! You have proven you can use ATTACK, manage your HP and survive an encounter.",
				"Head west to Elmwatch, enter the Adventurers Guild and speak to Captain Elara to report your result and receive a one-time reward.",
				"Every level grants five free stat points. Open STATS to assign them however you like. Your equipment choices remain unrestricted."
			])
		elif current_map=="forest" and (popup==null or not is_instance_valid(popup)):
			hint_label.text=_tutorial_hint()

'''+s[end:]

s+='''
# -- Six signature class techniques: one mentor field trial each. -------------
func _class_skill()->Dictionary:
	match str(data.get("class","Warrior")):
		"Warrior":return {"name":"Power Strike","damage":23,"range":170.0,"cooldown":5.0,"heal":0,"stat":"Strength"}
		"Ranger":return {"name":"Piercing Arrow","damage":18,"range":340.0,"cooldown":5.5,"heal":0,"stat":"Agility"}
		"Mage":return {"name":"Arcane Bolt","damage":21,"range":310.0,"cooldown":5.5,"heal":0,"stat":"Intelligence"}
		"Necromancer":return {"name":"Soul Siphon","damage":15,"range":270.0,"cooldown":7.0,"heal":10,"stat":"Intelligence"}
		"Assassin":return {"name":"Shadow Cut","damage":25,"range":170.0,"cooldown":6.0,"heal":0,"stat":"Agility"}
		"Paladin":return {"name":"Radiant Smite","damage":19,"range":190.0,"cooldown":6.5,"heal":8,"stat":"Wisdom"}
	return {"name":"Power Strike","damage":23,"range":170.0,"cooldown":5.0,"heal":0,"stat":"Strength"}

func _skill_mentor()->String:
	match str(data.get("class","Warrior")):
		"Warrior":return "Captain Elara Voss"
		"Ranger","Assassin":return "Garrick Thorn"
		"Mage","Necromancer":return "Neris Crowe"
		"Paladin":return "Sister Sera Vale"
	return "Captain Elara Voss"

func _accept_skill_trial()->void:
	if not bool(data.get("guild_training_completed",false)) or bool(data.get("skill_unlocked",false)):
		return
	if bool(data.get("skill_trial_accepted",false)):return
	data["skill_trial_accepted"]=true
	data["skill_trial_hits"]=0
	_save()
	_show_journal("CLASS SKILL TRAINING  /  %s" % str(data["class"]).to_upper(),[
		"%s will teach you %s after you demonstrate careful weapon handling." % [_skill_mentor(),str(_class_skill()["name"])],
		"Travel east of Elmwatch into Thornbrook Forest and land FOUR ordinary ATTACK hits on green slimes.",
		"Any equipment is allowed. Strength, Agility, Intelligence and Wisdom still grow through your freely assigned stat points.",
		"Return to %s to unlock your technique permanently. It will appear on the SKILL button and have its own cooldown." % _skill_mentor()
	])

func _complete_skill_trial()->void:
	if not bool(data.get("skill_trial_accepted",false)) or int(data.get("skill_trial_hits",0))<4:
		return
	if bool(data.get("skill_unlocked",false)):return
	data["skill_unlocked"]=true
	_save()
	_show_journal("NEW CLASS SKILL UNLOCKED",[
		"%s is now yours! It is your %s class's first signature ability." % [str(_class_skill()["name"]),str(data["class"])],
		"Use the SKILL button in combat, then wait for the skill cooldown. Skills do not restrict which weapons or armor you can equip.",
		"Class-specific quests and additional abilities can build on this foundation as your adventures continue."
	])

func _nearest_skill_slime(radius:float)->Dictionary:
	if current_map!="forest" or player==null:return {}
	var winner:Dictionary={}
	var closest:float=radius
	for mob in mobs:
		if not bool(mob.get("alive",false)):continue
		var distance:float=player.position.distance_to(mob["node"].position)
		if distance<closest:
			closest=distance
			winner=mob
	return winner

func _use_class_skill()->void:
	if not bool(data.get("skill_unlocked",false)):
		hint_label.text="SKILL locked: complete Guild training, then visit %s." % _skill_mentor()
		return
	if current_map!="forest":
		hint_label.text="Try %s against a slime in Thornbrook Forest." % str(_class_skill()["name"])
		return
	if skill_cooldown>0.0:
		hint_label.text="%s cooldown: %.1f seconds" % [str(_class_skill()["name"]),skill_cooldown]
		return
	var skill:Dictionary=_class_skill()
	var target:Dictionary=_nearest_skill_slime(float(skill["range"]))
	if target.is_empty():
		hint_label.text="Move into range to use %s." % str(skill["name"])
		return
	skill_cooldown=float(skill["cooldown"])
	var amount:int=int(skill["damage"])+int(float(data["stats"][str(skill["stat"])])*0.7)
	_apply_slime_damage(target,amount,true)
	if int(skill["heal"])>0:
		var restored:int=mini(int(skill["heal"]),int(data["max_hp"])-int(data["hp"]))
		if restored>0:
			data["hp"]=int(data["hp"])+restored
			_combat_popup(player.position,"+%d HP" % restored,Color("#91eac0"))
			_refresh_hud()
			_save()
'''
p.write_text(s,encoding="utf-8")
print("CLASS SKILLS PATCH OK: six ability buttons, mentor quests and saved unlocks.")
