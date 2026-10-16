#!/usr/bin/env python3
"""First mentor-quest arc: existing 18 starting skills remain level-one skills.

Six distinct mentors, including Mira Ashwood and Kael Rook, train one additional
technique after Guild graduation, an explicit offer, three skill demonstrations,
and two actual Thornbrook enemy defeats. No fetching or arbitrary item gates.
"""
from pathlib import Path
import re

p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(before,after):
    global s
    count=s.count(before)
    if count!=1:raise SystemExit(f"MENTOR PATCH ANCHOR FAILED ({count}): {before[:110]!r}")
    s=s.replace(before,after,1)

# Two previously planned instructors get their own named NPC entries, patrols
# and dialogue. Current sprite variants are tinted placeholders pending bespoke art.
rep('''	["Neris Crowe", "Necromancy Scholar", "neris_crowe", Vector2(1120,1150), "Even the forgotten have stories. Whispercrypt's secrets can wait for another day."]
]''',
'''	["Neris Crowe", "Necromancy Scholar", "neris_crowe", Vector2(1120,1150), "Even the forgotten have stories. Whispercrypt's secrets can wait for another day."],
	["Mira Ashwood", "Mage Mentor", "neris_crowe", Vector2(1250,890), "Magic is discipline, not just fire. Master the basics and I'll teach you more."],
	["Kael Rook", "Assassin Mentor", "garrick_thorn", Vector2(1550,780), "Shadows reward patience. Master your first techniques before we begin."]
]''')

rep('''    "neris_crowe":[Vector2(1120,1150),Vector2(1055,1122),Vector2(1185,1165)]
}''',
'''    "neris_crowe":[Vector2(1120,1150),Vector2(1055,1122),Vector2(1185,1165)],
    "mira_ashwood":[Vector2(1250,890),Vector2(1305,920),Vector2(1205,930)],
    "kael_rook":[Vector2(1550,780),Vector2(1510,810),Vector2(1630,740)]
}''')

# Routes key off appearance variant in legacy code. Give the two new
# characters dedicated routine keys while keeping their existing sprite files.
rep('''		actor["routine_state"]="Working"
		actor["outdoor"]=true
		npcs.append(actor)

func _spawn_mobs()->void:''',
'''		actor["routine_state"]="Working"
		actor["outdoor"]=true
		if str(entry[0])=="Mira Ashwood":
			actor["routine_key"]="mira_ashwood"
			actor["sprite"].modulate=Color("#a9d3f0")
		elif str(entry[0])=="Kael Rook":
			actor["routine_key"]="kael_rook"
			actor["sprite"].modulate=Color("#ceb8e8")
		npcs.append(actor)

func _spawn_mobs()->void:''')
rep('''		var key:String=str(npc["variant"])
		if not NPC_ROUTINES.has(key):continue''',
'''		var key:String=str(npc.get("routine_key",npc["variant"]))
		if not NPC_ROUTINES.has(key):continue''')
# _pose_resident must continue loading a real existing NPC sprite, not the new
# schedule-only key.
# Keep Mage/Assassin assignments from the initial design rather than proxies.
rep('''		"Ranger","Assassin":return "Garrick Thorn"
		"Mage","Necromancer":return "Neris Crowe"''',
'''		"Ranger":return "Garrick Thorn"
		"Assassin":return "Kael Rook"
		"Mage":return "Mira Ashwood"
		"Necromancer":return "Neris Crowe"''')

# Set up save-compatible runtime state; no migration of old characters needed.
rep('''var summon_attack_cd:float=0.0''',
'''var summon_attack_cd:float=0.0
var mentor_skill_cooldown:float=0.0
var mentor_smoke_timer:float=0.0''')
rep('''	_refresh_skill_icon_cooldowns()
	var axis=movement+_key_axis()''',
'''	_refresh_skill_icon_cooldowns()
	mentor_skill_cooldown=maxf(0.0,mentor_skill_cooldown-delta)
	mentor_smoke_timer=maxf(0.0,mentor_smoke_timer-delta)
	_refresh_mentor_button()
	var axis=movement+_key_axis()''')
rep('''	summon_actor=null

	#''','''	summon_actor=null
	mentor_skill_cooldown=0.0
	mentor_smoke_timer=0.0

	#''') if False else None
# End of _enter_world currently followed by more setup; keep one anchored line.
rep('''	summon_actor=null
	npc_presence_key=_presence_window()''',
'''	summon_actor=null
	mentor_skill_cooldown=0.0
	mentor_smoke_timer=0.0
	npc_presence_key=_presence_window()''')
rep('''	_button(hud,"SAVE",1024,158,216,43,_save)''',
'''	_button(hud,"SAVE",1024,158,216,43,_save)
	if _has_mentor_skill():_add_mentor_skill_button()''')
rep('''	# Starter abilities are available immediately; mentors will later offer
	# separate advanced quest skills, not lock or award these first eighteen.
	if bool(data.get("guild_training_completed",false)) and who==_skill_mentor():
		_show_npc_chat(n,"Your %s already knows three starting skills. Practice all three in Thornbrook. I'll have more advanced techniques for you to earn through future training." % str(data.get("class","Warrior")))
		return''',
'''	# The first eighteen are always usable. Training teaches a fourth skill.
	if who==_skill_mentor() and _interact_skill_mentor(n):return''')

rep('''	skill_cooldowns[slot]=float(skill["cd"])
	var scaling:int=''', '''	skill_cooldowns[slot]=float(skill["cd"])
	_mentor_record_cast(slot)
	var scaling:int=''')
rep('''		data["quest_kills"]=int(data["quest_kills"])+1
		if int(data["xp"])''',
'''		data["quest_kills"]=int(data["quest_kills"])+1
		_mentor_record_kill()
		if int(data["xp"])''')
# Hunter's Mark increases attacks on marked targets; enemies carry the mark.
rep('''	best["hp"]=int(best["hp"])-maxi(1,dmg)
	best["hit_reaction"]''',
'''	if float(best.get("mentor_mark_timer",0.0))>0.0:dmg+=8
	best["hp"]=int(best["hp"])-maxi(1,dmg)
	best["hit_reaction"]''')
rep('''		mob["slow_timer"]=maxf(0.0,float(mob.get("slow_timer",0.0))-dt)
		mob["stun_timer"]''',
'''		mob["mentor_mark_timer"]=maxf(0.0,float(mob.get("mentor_mark_timer",0.0))-dt)
		mob["slow_timer"]=maxf(0.0,float(mob.get("slow_timer",0.0))-dt)
		mob["stun_timer"]''')
rep('''	if barrier_charges>0 and barrier_timer>0.0:
		barrier_charges-=1''',
'''	if mentor_smoke_timer>0.0:
		_combat_popup(player.position,"EVADE",Color("#c6b4e6"))
		hint_label.text="Smoke Veil concealed you from the attack."
		return
	if barrier_charges>0 and barrier_timer>0.0:
		barrier_charges-=1''')
rep('''	var mission:String="Guild: DONE" if bool(data.get("guild_training_completed",false)) else ("Slimes: %d/3" % mini(3,int(data.get("quest_kills",0))))''',
'''	var mission:String="Guild: DONE" if bool(data.get("guild_training_completed",false)) else ("Slimes: %d/3" % mini(3,int(data.get("quest_kills",0))))
	if _mentor_quest_state()=="active":
		mission="Mentor: %d/2" % mini(2,int(_mentor_quest().get("kills",0)))
	elif _mentor_quest_state()=="ready":mission="Mentor: RETURN"''')
# Existing smoke test expects the old roster. Change only the expected total.
smoke=Path("tests/smoke_test.gd")
t=smoke.read_text(encoding="utf-8")
old='scene.current_map == "town" and scene.npcs.size() == 3,"Town/NPC population"'
if t.count(old)!=1:raise SystemExit("MENTOR PATCH: smoke count anchor missing")
smoke.write_text(t.replace(old,'scene.current_map == "town" and scene.npcs.size() == 5,"Town/NPC population"'),encoding="utf-8")

s+=r'''
# -- First class mentor skill quests -------------------------------------------
# Names for this first advanced tier are changeable; no original level-1 name
# or mechanics are overwritten.
const MENTOR_SKILLS={
	"Warrior":{"name":"Earthshaker","cooldown":18.0,"description":"An area shockwave that damages nearby enemies."},
	"Ranger":{"name":"Hunter's Mark","cooldown":17.0,"description":"Mark a target so subsequent hits deal extra damage."},
	"Mage":{"name":"Meteor Burst","cooldown":20.0,"description":"A fiery ranged impact with splash damage."},
	"Necromancer":{"name":"Death Echo","cooldown":20.0,"description":"Drain life from several nearby enemies at once."},
	"Assassin":{"name":"Smoke Veil","cooldown":18.0,"description":"Disappear briefly and evade incoming strikes."},
	"Paladin":{"name":"Consecration","cooldown":20.0,"description":"Heal and strike nearby enemies with holy energy."}
}

func _mentor_quest()->Dictionary:
	var state=data.get("mentor_training",{})
	if typeof(state)!=TYPE_DICTIONARY:return {}
	if str(state.get("class",""))!=str(data.get("class","Warrior")):return {}
	return state

func _mentor_quest_state()->String:
	return str(_mentor_quest().get("state",""))

func _has_mentor_skill()->bool:
	var unlocked=data.get("mentor_unlocked",{})
	return typeof(unlocked)==TYPE_DICTIONARY and bool(unlocked.get(str(data.get("class","Warrior")),false))

func _mentor_skill_info()->Dictionary:
	return MENTOR_SKILLS.get(str(data.get("class","Warrior")),{})

func _mentor_ready()->bool:
	var state:Dictionary=_mentor_quest()
	if str(state.get("state",""))!="active":return false
	var casts:Array=state.get("casts",[])
	if casts.size()!=3 or int(state.get("kills",0))<2:return false
	for done in casts:
		if not bool(done):return false
	return true

func _mentor_progress_text()->String:
	var state:Dictionary=_mentor_quest()
	var casts:Array=state.get("casts",[false,false,false])
	var trained:int=0
	for flag in casts:
		if bool(flag):trained+=1
	return "Practice: %d/3 starting abilities; enemies: %d/2. Return when both are complete." % [trained,mini(2,int(state.get("kills",0)))]

func _interact_skill_mentor(n:Dictionary)->bool:
	if not bool(data.get("guild_training_completed",false)):return false
	if _has_mentor_skill():
		_show_npc_chat(n,"Your advanced training is complete. %s is now on your combat HUD. Keep exploring to master it!" % str(_mentor_skill_info()["name"]))
		return true
	if int(data.get("level",1))<2:
		_show_npc_chat(n,"You've learned the basics, but first reach level 2 through exploration and combat. Then come back for personal instruction.")
		return true
	if _mentor_ready():
		_grant_mentor_skill(n)
		return true
	if _mentor_quest_state()=="active":
		_show_npc_chat(n,"I can see your progress. "+_mentor_progress_text()+" Return when you've proved yourself.")
		return true
	_show_npc_chat(n,"You've earned Guild recognition. My advanced teaching is not handed out for free: travel to Thornbrook, demonstrate each of your three original skills, defeat two slimes and report back. Will you accept this class training quest?")
	popup.offer_quest_accept(_accept_mentor_training)
	return true

func _accept_mentor_training()->void:
	if not bool(data.get("guild_training_completed",false)) or int(data.get("level",1))<2 or _has_mentor_skill():return
	if _mentor_quest_state()!="":return
	var hero_class:String=str(data.get("class","Warrior"))
	data["mentor_training"]={"class":hero_class,"state":"active","casts":[false,false,false],"kills":0}
	_save()
	_refresh_hud()
	_show_journal("CLASS MENTOR  /  %s" % hero_class.to_upper(),[
		"Your class mentor, %s, has offered a personal trial. Mastery starts by using the abilities you already know, not by collecting meaningless errands." % _skill_mentor(),
		"Travel east from Elmwatch to Thornbrook Forest. Use EACH of your three starting skills at least once during the trial, then defeat TWO slimes. Abilities only count when successfully activated in the forest.",
		"Return to your mentor in Elmwatch. You will learn %s, a fourth advanced ability with its own cooldown, without losing any starting skills." % str(_mentor_skill_info()["name"])
	])

func _mentor_record_cast(slot:int)->void:
	if current_map!="forest" or _mentor_quest_state()!="active" or slot<0 or slot>2:return
	var state:Dictionary=_mentor_quest()
	var casts:Array=state.get("casts",[false,false,false])
	if casts.size()!=3:return
	if bool(casts[slot]):return
	casts[slot]=true
	state["casts"]=casts
	data["mentor_training"]=state
	_mentor_update_ready()
	_save()

func _mentor_record_kill()->void:
	if current_map!="forest" or _mentor_quest_state()!="active":return
	var state:Dictionary=_mentor_quest()
	state["kills"]=mini(2,int(state.get("kills",0))+1)
	data["mentor_training"]=state
	_mentor_update_ready()
	_save()

func _mentor_update_ready()->void:
	if not _mentor_ready():return
	var state:Dictionary=_mentor_quest()
	state["state"]="ready"
	data["mentor_training"]=state
	if hint_label!=null and is_instance_valid(hint_label):
		hint_label.text="MENTOR TRIAL COMPLETE! Return to %s." % _skill_mentor()
	_refresh_hud()

func _grant_mentor_skill(n:Dictionary)->void:
	if not _mentor_ready():return
	var state:Dictionary=_mentor_quest()
	state["state"]="complete"
	data["mentor_training"]=state
	var unlocked=data.get("mentor_unlocked",{})
	if typeof(unlocked)!=TYPE_DICTIONARY:unlocked={}
	unlocked[str(data.get("class","Warrior"))]=true
	data["mentor_unlocked"]=unlocked
	mentor_skill_cooldown=0.0
	_save()
	_refresh_hud()
	if hud!=null and is_instance_valid(hud):_add_mentor_skill_button()
	_show_npc_chat(n,"You've proven your discipline and courage. I now teach you %s! A new ADVANCED button has appeared on your HUD. Your first three abilities remain yours." % str(_mentor_skill_info()["name"]))

func _add_mentor_skill_button()->void:
	if hud==null or not is_instance_valid(hud) or not _has_mentor_skill():return
	if hud.get_node_or_null("MentorSkillButton")!=null:return
	var name:String=str(_mentor_skill_info()["name"])
	_button(hud,"ADV: "+name.to_upper(),1024,212,216,56,_use_mentor_skill)
	for child in hud.get_children():
		if child is Button and child.text=="ADV: "+name.to_upper():
			child.name="MentorSkillButton"
			child.add_theme_font_size_override("font_size",17)
			child.tooltip_text=str(_mentor_skill_info()["description"])
			break
	_refresh_mentor_button()

func _refresh_mentor_button()->void:
	if hud==null or not is_instance_valid(hud):return
	var button:Button=hud.get_node_or_null("MentorSkillButton") as Button
	if button==null:return
	var name:String=str(_mentor_skill_info().get("name","ADVANCED"))
	button.text="ADV: %s" % name.to_upper() if mentor_skill_cooldown<=0.0 else ("ADV: %s  %ds" % [name.to_upper(),int(ceil(mentor_skill_cooldown))])
	button.modulate=Color.WHITE if mentor_skill_cooldown<=0.0 else Color(0.7,0.72,0.78)

func _use_mentor_skill()->void:
	if not _has_mentor_skill() or player==null or current_map!="forest":return
	if mentor_skill_cooldown>0.0:
		hint_label.text="Advanced skill ready in %.1fs" % mentor_skill_cooldown
		return
	var hero_class:String=str(data.get("class","Warrior"))
	var targets:Array=_skill_targets(350.0)
	# Attack and mark skills require a target. Protective smoke works without one.
	if hero_class in ["Warrior","Ranger","Mage","Necromancer"] and targets.is_empty():
		hint_label.text="Move closer to a slime before using your advanced ability."
		return
	var info:Dictionary=_mentor_skill_info()
	last_skill_name=str(info["name"])
	mentor_skill_cooldown=float(info["cooldown"])
	match hero_class:
		"Warrior":
			for mob in targets:
				if mob["node"].position.distance_to(player.position)<=210.0:
					_apply_slime_damage(mob,28+int(int(data["stats"]["Strength"])/2),true)
		"Ranger":
			targets[0]["mentor_mark_timer"]=9.0
			_combat_popup(targets[0]["node"].position,"MARKED",Color("#b6f8c4"))
		"Mage":
			var impact:Vector2=targets[0]["node"].position
			for mob in targets:
				if mob["node"].position.distance_to(impact)<=155.0:
					_apply_slime_damage(mob,24+int(int(data["stats"]["Intelligence"])/2),true)
		"Necromancer":
			var healed:int=0
			for mob in targets:
				if mob["node"].position.distance_to(player.position)<=235.0:
					_apply_slime_damage(mob,13+int(int(data["stats"]["Wisdom"])/3),true)
					healed+=8
			_skill_heal(healed)
		"Assassin":
			mentor_smoke_timer=5.5
			_combat_popup(player.position,"SMOKE VEIL",Color("#c7b0df"))
		"Paladin":
			_skill_heal(22+int(int(data["stats"]["Wisdom"])/2))
			for mob in targets:
				if mob["node"].position.distance_to(player.position)<=220.0:
					_apply_slime_damage(mob,16+int(int(data["stats"]["Wisdom"])/3),true)
	if hint_label!=null and is_instance_valid(hint_label):
		hint_label.text="%s activated!" % str(info["name"])
	_refresh_mentor_button()
	_refresh_hud()
	_save()
'''
p.write_text(s,encoding="utf-8")
print("MENTOR QUEST PATCH OK: six mentors, persistent trials, six additional combat abilities.")
