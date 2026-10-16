#!/usr/bin/env python3
"""Add the AO class skillbook, objective journal and light-weight visual combat cues."""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(a,b):
    global s
    n=s.count(a)
    if n!=1:raise SystemExit(f"SKILLBOOK/VFX ANCHOR ERROR {n}: {a[:105]!r}")
    s=s.replace(a,b,1)

rep('''	_button(hud,"SAVE",1024,158,216,43,_save)
	if _has_mentor_skill():_add_mentor_skill_button()''',
'''	_button(hud,"SAVE",1024,158,216,43,_save)
	_button(hud,"SKILLBOOK",781,157,218,44,_open_skillbook)
	_button(hud,"QUEST JOURNAL",781,209,218,44,_open_quest_journal)
	if _has_mentor_skill():_add_mentor_skill_button()''')

rep('''	skill_cooldowns[slot]=float(skill["cd"])
	_mentor_record_cast(slot)''',
'''	skill_cooldowns[slot]=float(skill["cd"])
	_play_ability_fx(name,kind)
	_mentor_record_cast(slot)''')

rep('''	mentor_skill_cooldown=float(info["cooldown"])
	match hero_class:''',
'''	mentor_skill_cooldown=float(info["cooldown"])
	_play_ability_fx(str(info["name"]),"advanced")
	match hero_class:''')

rep('''		var mission:String="Guild: DONE"''','''		var mission:String="Guild: DONE"''') if False else None

s+=r'''
# -- Usable class skillbook and objective journal ------------------------------
const CLASS_ACCENTS={
	"Warrior":"#ffbe78","Ranger":"#8ae7c8","Mage":"#95cbff",
	"Necromancer":"#bda1f0","Assassin":"#de9ed8","Paladin":"#ffe6a0"
}
const SKILL_GUIDE={
	"cleave":"Hit up to three nearby enemies.",
	"stun":"Damage and briefly stun one enemy.",
	"buff":"Temporarily increase normal attack damage.",
	"ranged":"Focus damage on one distant enemy.",
	"volley":"Strike up to three targets at range.",
	"trap":"Leave a snare that slows nearby monsters.",
	"burn":"Damage and ignite one target.",
	"nova":"Damage and slow nearby opponents.",
	"barrier":"Block two incoming attacks.",
	"summon":"Summon a temporary fighting skeleton.",
	"drain":"Steal life from a nearby enemy.",
	"backstab":"Deal more damage to unaware enemies.",
	"step":"Teleport toward a selected enemy.",
	"poison":"Strike and apply a damaging toxin.",
	"holy":"Close-range holy damage.",
	"heal":"Restore missing health.",
	"shield":"Block three incoming attacks."
}

func _panel_dialog(title_text:String)->void:
	if popup!=null and is_instance_valid(popup):popup.queue_free()
	popup=Control.new()
	popup.size=Vector2(1280,720)
	ui.add_child(popup)
	var dim=ColorRect.new()
	dim.color=Color(0.015,0.025,0.045,0.88)
	dim.size=Vector2(1280,720)
	popup.add_child(dim)
	_panel(popup,Rect2(110,45,1060,625),Color("#162438"))
	_label(popup,title_text,152,69,860,48,34,Color("#f0d18b"))
	_button(popup,"CLOSE",1032,78,102,47,_dismiss_message)

func _open_skillbook()->void:
	_panel_dialog("ADVENTURER'S SKILLBOOK")
	var tint:Color=Color(str(CLASS_ACCENTS.get(str(data.get("class","Warrior")),"#fff0cb")))
	_label(popup,"%s  •  Level %d  •  %s" % [data["class"],int(data["level"]),_skill_mentor()],161,125,949,35,21,tint)
	for slot in range(3):
		var skill:Dictionary=_starter_skills()[slot]
		var top:int=182+slot*112
		_panel(popup,Rect2(160,top,945,99),Color("#23394b"))
		var name:String=str(skill["name"])
		var path:String="res://assets/skills/%s_%s.svg" % [str(data["class"]).to_lower(),name.to_lower().replace(" ","_")]
		if ResourceLoader.exists(path):
			var image=TextureRect.new()
			image.texture=load(path)
			image.position=Vector2(175,top+12)
			image.size=Vector2(70,70)
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			popup.add_child(image)
		_label(popup,name,261,top+8,500,37,23,tint)
		_label(popup,str(SKILL_GUIDE.get(str(skill["kind"]),"Class ability")),262,top+47,680,32,19)
		_label(popup,"LEVEL 1 • %.1fs" % float(skill["cd"]),850,top+12,230,31,18,Color("#b7d4ed"))
	_panel(popup,Rect2(160,529,945,107),Color("#23394b"))
	var advance:Dictionary=_mentor_skill_info()
	var unlock:String="LEARNED" if _has_mentor_skill() else ("READY TO CLAIM" if _mentor_quest_state()=="ready" else "MENTOR TRIAL")
	_label(popup,"ADVANCED: %s  [%s]" % [str(advance.get("name","")),unlock],177,542,810,34,23,tint)
	_label(popup,str(advance.get("description","Complete your class trial to unlock.")),177,586,850,32,19)

func _open_quest_journal()->void:
	_panel_dialog("ADVENTURER'S QUEST JOURNAL")
	_label(popup,"MAIN STORY",167,130,870,38,24,Color("#ffdda0"))
	_label(popup,"Your first day in Elmwatch: discover the Guild and prepare for the unknown.",186,172,910,37,19)
	_label(popup,"GUILD TRAINING",167,223,870,38,24,Color("#ffdda0"))
	var guild:String="COMPLETE — 20 gold and a potion claimed." if bool(data.get("guild_training_completed",false)) else ("IN PROGRESS — slimes %d/3" % mini(3,int(data.get("quest_kills",0))) if bool(data.get("slime_training_accepted",false)) else "AVAILABLE — speak with Captain Elara in the Guild.")
	_label(popup,guild,186,263,900,40,20)
	_label(popup,"CLASS MENTOR",167,328,870,38,24,Color("#ffdda0"))
	var state:String=_mentor_quest_state()
	var msg:String="Available after Guild training and level 2."
	if state=="active":msg=_mentor_progress_text()
	elif state=="ready":msg="READY — return to %s to learn %s." % [_skill_mentor(),str(_mentor_skill_info().get("name",""))]
	elif state=="complete":msg="COMPLETE — advanced skill %s learned." % str(_mentor_skill_info().get("name",""))
	elif bool(data.get("guild_training_completed",false)):msg="Talk to %s to begin advanced training." % _skill_mentor()
	_label(popup,msg,186,369,900,48,20)
	_label(popup,"SIDE QUESTS",167,446,870,38,24,Color("#ffdda0"))
	_label(popup,"Discover additional requests as Elmwatch and Thornbrook expand.",186,488,900,40,20)
	_label(popup,"Quest goals persist in your character save. No timed expiry.",184,564,890,36,17,Color("#b4d1dd"))

func _play_ability_fx(skill_name:String,kind:String)->void:
	if world==null or not is_instance_valid(world) or player==null:return
	var target:Vector2=player.position
	if current_map=="forest" and kind not in ["heal","buff","barrier","shield","trap","summon","step"]:
		var targets:Array=_skill_targets(350.0)
		if not targets.is_empty():target=targets[0]["node"].position
	var accent:Color=Color(str(CLASS_ACCENTS.get(str(data.get("class","Warrior")),"#fff0cb")))
	var effect=Node2D.new()
	effect.name="AbilityEffect"
	effect.set_script(load("res://scripts/skill_effect.gd"))
	world.add_child(effect)
	effect.call("configure",skill_name,player.position,target,accent)
'''
p.write_text(s,encoding="utf-8")
print("SKILLBOOK/VFX PATCH OK: visual combat cues, 24 ability records and objective journal.")
