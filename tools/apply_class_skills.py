#!/usr/bin/env python3
"""Restore the original eighteen Adventure Odyssey abilities as class starter skills.

Three usable skills for each of the six classes, available on character creation
and old saves. More powerful skills will be earned via mentors in future quests;
the previously implemented six replacement-skills are intentionally not used.
The Slime AI, Guild quest, equipment freedom and free stat points are preserved.
"""
from pathlib import Path

p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(a,b):
    global s
    count=s.count(a)
    if count!=1:
        raise SystemExit(f"STARTING SKILLS PATCH ANCHOR FAILED ({count}): {a[:130]!r}")
    s=s.replace(a,b,1)

rep('''var attack_cooldown := 0.0''','''var attack_cooldown := 0.0
var skill_cooldowns:Array[float]=[0.0,0.0,0.0]
var last_skill_name:String=""
var battle_cry_timer:float=0.0
var barrier_timer:float=0.0
var barrier_charges:int=0
var trap_pos:Vector2=Vector2.ZERO
var trap_timer:float=0.0
var summon_actor:Node2D=null
var summon_timer:float=0.0
var summon_attack_cd:float=0.0''')

rep('''	attack_cooldown=maxf(0.0,attack_cooldown-delta)
	var axis=movement+_key_axis()''',
'''	attack_cooldown=maxf(0.0,attack_cooldown-delta)
	for i in range(skill_cooldowns.size()):
		skill_cooldowns[i]=maxf(0.0,skill_cooldowns[i]-delta)
	_tick_starting_skill_effects(delta)
	var axis=movement+_key_axis()''')

# Reset runtime summons/traps and cooldowns when entering a world scene.
rep('''	current_map=map_name
	movement=Vector2.ZERO''',
'''	current_map=map_name
	movement=Vector2.ZERO
	skill_cooldowns=[0.0,0.0,0.0]
	battle_cry_timer=0.0
	barrier_timer=0.0
	barrier_charges=0
	trap_timer=0.0
	summon_timer=0.0
	summon_actor=null''')

rep('''	_button(hud,"ATTACK",1022,558,218,60,_attack)''',
'''	_button(hud,"ATTACK",1022,558,218,60,_attack)
	var skills:Array=_starter_skills()
	for slot in range(3):
		var name:String=str(skills[slot]["name"]).to_upper()
		_button(hud,name,510+slot*169,579,165,60,_use_starting_skill.bind(slot))
		# Long names must remain fully visible on a phone landscape screen.
		for child in hud.get_children():
			if child is Button and child.text==name:
				child.add_theme_font_size_override("font_size",18)''')

rep('''	if who=="Captain Elara Voss" and not bool(data.get("slime_training_accepted",false))''',
'''	# Starter abilities are available immediately; mentors will later offer
	# separate advanced quest skills, not lock or award these first eighteen.
	if bool(data.get("guild_training_completed",false)) and who==_skill_mentor():
		_show_npc_chat(n,"Your %s already knows three starting skills. Practice all three in Thornbrook. I'll have more advanced techniques for you to earn through future training." % str(data.get("class","Warrior")))
		return
	if who=="Captain Elara Voss" and not bool(data.get("slime_training_accepted",false))''')

rep('''			if bool(data.get("guild_training_completed",false)):
				return "Guild training complete! Explore Elmwatch or prepare for your next journey."''',
'''			if bool(data.get("guild_training_completed",false)):
				return "Use your three starter skills now; %s will teach advanced skills later." % _skill_mentor()''')
rep('''			if bool(data.get("guild_training_completed",false)):
				return "Your first Guild assignment is complete. Safe travels!"''',
'''			if bool(data.get("guild_training_completed",false)):
				return "Guild training complete! Your class's three starting abilities are ready."''')
rep('''		"forest":
			if int(data.get("quest_kills",0))>=3:''',
'''		"forest":
			if int(data.get("quest_kills",0))>=3:''') if False else None
# The original forest hint remains meaningful: the three skills are accessible
# independently of Guild status, and early stat progression is unchanged.

begin=s.index('\tvar dmg=8+int(int(data["stats"]["Strength"]) / 2)',s.index('func _attack()->void:'))
end=s.index('func _enemy_attack()->void:',begin)
if begin<0 or end<=begin:
    raise SystemExit("STARTING SKILLS PATCH: attack resolution boundaries missing")
s=s[:begin]+'''	var dmg=8+int(int(data["stats"]["Strength"]) / 2)
	if battle_cry_timer>0.0:dmg+=6
	_apply_slime_damage(best,dmg,false)

func _apply_slime_damage(best:Dictionary,dmg:int,skill_hit:bool)->void:
	if current_map!="forest" or not bool(best.get("alive",false)):return
	best["hp"]=int(best["hp"])-maxi(1,dmg)
	best["hit_reaction"]=0.25
	best["indicator"].call("update_health",int(best["hp"]),int(best["max_hp"]))
	_combat_popup(best["node"].position,"-%d" % dmg,Color("#b4ddff") if skill_hit else Color("#ffe7a0"))
	hint_label.text="%s: %d damage!" % [last_skill_name,dmg] if skill_hit else "%d damage! Press ATTACK after its short cooldown." % dmg
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

# Keep the approved attack and enemy AI functions and append the new skill
# implementation, which intentionally contains no mentor-locked starter skills.
s+='''
# -- Eighteen original starter abilities, unlocked at level one -----------------
# Three immediately available for each class, no stat or equipment requirements.
const STARTING_CLASS_SKILLS={
	"Warrior":[
		{"name":"Power Slash","kind":"cleave","damage":18,"range":170.0,"cd":4.5,"stat":"Strength"},
		{"name":"Shield Bash","kind":"stun","damage":10,"range":135.0,"cd":7.0,"stat":"Strength"},
		{"name":"Battle Cry","kind":"buff","cd":15.0}
	],
	"Ranger":[
		{"name":"Aimed Shot","kind":"ranged","damage":23,"range":360.0,"cd":5.5,"stat":"Agility"},
		{"name":"Quick Volley","kind":"volley","damage":11,"range":330.0,"cd":8.0,"stat":"Agility"},
		{"name":"Snare Trap","kind":"trap","cd":11.0}
	],
	"Mage":[
		{"name":"Firebolt","kind":"burn","damage":17,"range":320.0,"cd":5.0,"stat":"Intelligence"},
		{"name":"Frost Nova","kind":"nova","damage":9,"range":230.0,"cd":10.0,"stat":"Intelligence"},
		{"name":"Arcane Barrier","kind":"barrier","cd":15.0}
	],
	"Necromancer":[
		{"name":"Raise Skeleton","kind":"summon","cd":19.0},
		{"name":"Soul Bolt","kind":"ranged","damage":18,"range":320.0,"cd":5.5,"stat":"Intelligence"},
		{"name":"Life Drain","kind":"drain","damage":12,"range":250.0,"cd":9.0,"stat":"Wisdom"}
	],
	"Assassin":[
		{"name":"Backstab","kind":"backstab","damage":17,"range":145.0,"cd":6.0,"stat":"Agility"},
		{"name":"Shadowstep","kind":"step","range":280.0,"cd":11.0},
		{"name":"Poison Blade","kind":"poison","damage":9,"range":150.0,"cd":8.0,"stat":"Agility"}
	],
	"Paladin":[
		{"name":"Holy Strike","kind":"holy","damage":18,"range":175.0,"cd":6.0,"stat":"Wisdom"},
		{"name":"Divine Heal","kind":"heal","cd":13.0},
		{"name":"Sacred Shield","kind":"shield","cd":18.0}
	]
}

func _starter_skills()->Array:
	var hero_class:String=str(data.get("class","Warrior"))
	return STARTING_CLASS_SKILLS.get(hero_class,STARTING_CLASS_SKILLS["Warrior"])

func _skill_mentor()->String:
	match str(data.get("class","Warrior")):
		"Warrior":return "Captain Elara Voss"
		"Ranger","Assassin":return "Garrick Thorn"
		"Mage","Necromancer":return "Neris Crowe"
		"Paladin":return "Sister Sera Vale"
	return "Captain Elara Voss"

func _skill_targets(radius:float)->Array:
	var found:Array=[]
	if current_map!="forest" or player==null:return found
	for mob in mobs:
		if bool(mob.get("alive",false)) and player.position.distance_to(mob["node"].position)<=radius:
			found.append(mob)
	found.sort_custom(func(a,b):return player.position.distance_to(a["node"].position)<player.position.distance_to(b["node"].position))
	return found

func _use_starting_skill(slot:int)->void:
	if slot<0 or slot>=3:return
	var skill:Dictionary=_starter_skills()[slot]
	var name:String=str(skill["name"])
	if skill_cooldowns[slot]>0.0:
		hint_label.text="%s cooldown: %.1f seconds" % [name,skill_cooldowns[slot]]
		return
	var kind:String=str(skill["kind"])
	if current_map!="forest" and kind not in ["heal","shield","barrier","buff"]:
		hint_label.text="%s: try this ability in Thornbrook." % name
		return
	var target:Dictionary={}
	var targets:Array=_skill_targets(float(skill.get("range",0.0)))
	if kind in ["cleave","stun","ranged","volley","burn","nova","drain","backstab","poison","holy","step"] and targets.is_empty():
		hint_label.text="%s: move closer to an enemy." % name
		return
	# No cost if a healing ability has nothing to restore.
	if kind=="heal" and int(data["hp"])>=int(data["max_hp"]):
		hint_label.text="Divine Heal: your health is already full."
		return
	last_skill_name=name
	skill_cooldowns[slot]=float(skill["cd"])
	var scaling:int=int(float(data["stats"].get(str(skill.get("stat","Strength")),10))*0.5)
	match kind:
		"cleave":
			var n:int=0
			for mob in targets:
				if n>=3:break
				_apply_slime_damage(mob,int(skill["damage"])+scaling,true)
				n+=1
		"stun":
			target=targets[0]
			target["stun_timer"]=2.0
			target["state"]="pursue"
			_apply_slime_damage(target,int(skill["damage"])+scaling,true)
		"buff":
			battle_cry_timer=9.0
			_combat_popup(player.position,"BATTLE CRY",Color("#f5ca8a"))
		"ranged":
			_apply_slime_damage(targets[0],int(skill["damage"])+scaling,true)
		"volley":
			var n:int=0
			for mob in targets:
				if n>=3:break
				_apply_slime_damage(mob,int(skill["damage"])+scaling,true)
				n+=1
		"trap":
			trap_pos=player.position+_skill_facing()*130.0
			if not _walkable(trap_pos):trap_pos=player.position
			trap_timer=12.0
			_combat_popup(trap_pos,"SNARE",Color("#7ce3c5"))
		"burn":
			target=targets[0]
			target["burn_timer"]=3.0
			target["burn_tick"]=0.0
			_apply_slime_damage(target,int(skill["damage"])+scaling,true)
		"nova":
			for mob in targets:
				mob["slow_timer"]=4.0
				_apply_slime_damage(mob,int(skill["damage"])+scaling,true)
			_combat_popup(player.position,"FROST NOVA",Color("#aee6ff"))
		"barrier":
			barrier_charges=2
			barrier_timer=13.0
			_combat_popup(player.position,"BARRIER",Color("#accdff"))
		"summon":
			if summon_actor!=null and is_instance_valid(summon_actor):summon_actor.queue_free()
			summon_actor=Node2D.new()
			summon_actor.name="SummonedSkeleton"
			summon_actor.position=player.position+Vector2(75,0)
			world.add_child(summon_actor)
			var spirit=Label.new()
			spirit.text="☠"
			spirit.add_theme_font_size_override("font_size",53)
			spirit.add_theme_color_override("font_color",Color("#c9e8db"))
			summon_actor.add_child(spirit)
			summon_timer=15.0
			summon_attack_cd=1.2
			_combat_popup(player.position,"SKELETON",Color("#c0edd9"))
		"drain":
			target=targets[0]
			_apply_slime_damage(target,int(skill["damage"])+scaling,true)
			_skill_heal(10)
		"backstab":
			target=targets[0]
			var bonus:int=12 if str(target.get("state","wander")) in ["wander","return"] else 0
			_apply_slime_damage(target,int(skill["damage"])+scaling+bonus,true)
		"step":
			target=targets[0]
			var direction:Vector2=(player.position-target["node"].position).normalized()
			var next:Vector2=target["node"].position+direction*65.0
			if _walkable(next):
				player.position=next
				_combat_popup(player.position,"SHADOWSTEP",Color("#cb9ce2"))
		"poison":
			target=targets[0]
			target["poison_timer"]=5.0
			target["poison_tick"]=0.0
			_apply_slime_damage(target,int(skill["damage"])+scaling,true)
		"holy":
			target=targets[0]
			_apply_slime_damage(target,int(skill["damage"])+scaling,true)
		"heal":
			_skill_heal(30+int(float(data["stats"]["Wisdom"])*0.5))
		"shield":
			barrier_charges=3
			barrier_timer=13.0
			_combat_popup(player.position,"SACRED SHIELD",Color("#fff4bc"))
	_save()
	_refresh_hud()

func _skill_facing()->Vector2:
	match facing:
		"left":return Vector2.LEFT
		"up":return Vector2.UP
		"down":return Vector2.DOWN
	return Vector2.RIGHT

func _skill_heal(amount:int)->void:
	var restored:int=mini(amount,int(data["max_hp"])-int(data["hp"]))
	if restored<=0:return
	data["hp"]=int(data["hp"])+restored
	_combat_popup(player.position,"+%d HP" % restored,Color("#a6f0ba"))

func _tick_starting_skill_effects(delta:float)->void:
	var dt:float=maxf(delta,0.0)
	battle_cry_timer=maxf(0.0,battle_cry_timer-dt)
	barrier_timer=maxf(0.0,barrier_timer-dt)
	if barrier_timer==0.0:barrier_charges=0
	trap_timer=maxf(0.0,trap_timer-dt)
	summon_timer=maxf(0.0,summon_timer-dt)
	if current_map!="forest":return
	for mob in mobs:
		if not bool(mob.get("alive",false)):continue
		mob["slow_timer"]=maxf(0.0,float(mob.get("slow_timer",0.0))-dt)
		mob["stun_timer"]=maxf(0.0,float(mob.get("stun_timer",0.0))-dt)
		if trap_timer>0.0 and mob["node"].position.distance_to(trap_pos)<100.0:
			mob["slow_timer"]=maxf(float(mob["slow_timer"]),1.0)
		for effect in ["burn","poison"]:
			var remaining:String=effect+"_timer"
			var tick:String=effect+"_tick"
			if float(mob.get(remaining,0.0))>0.0:
				mob[remaining]=maxf(0.0,float(mob[remaining])-dt)
				mob[tick]=float(mob.get(tick,0.0))+dt
				if float(mob[tick])>=1.0:
					mob[tick]=0.0
					last_skill_name="Firebolt" if effect=="burn" else "Poison Blade"
					_apply_slime_damage(mob,4 if effect=="burn" else 3,true)
	if summon_timer<=0.0:
		if summon_actor!=null and is_instance_valid(summon_actor):summon_actor.queue_free()
		summon_actor=null
	elif summon_actor!=null and is_instance_valid(summon_actor) and player!=null:
		summon_attack_cd=maxf(0.0,summon_attack_cd-dt)
		var destination:Vector2=player.position+Vector2(75,0)
		if summon_actor.position.distance_to(destination)>145.0:
			var step:Vector2=summon_actor.position.move_toward(destination,160.0*dt)
			if _walkable(step):summon_actor.position=step
		if summon_attack_cd<=0.0:
			for mob in mobs:
				if bool(mob.get("alive",false)) and summon_actor.position.distance_to(mob["node"].position)<150.0:
					last_skill_name="Raise Skeleton"
					_apply_slime_damage(mob,6,true)
					summon_attack_cd=1.5
					break
'''
# Slime control effects must remain compatible with existing AI update.
rep('''		mob["attack_cd"]=maxf(0.0,float(mob["attack_cd"])-dt)''',
'''		if float(mob.get("stun_timer",0.0))>0.0:
			mob["state"]="pursue"
			mob["windup"]=0.0
			continue
		mob["attack_cd"]=maxf(0.0,float(mob["attack_cd"])-dt)''')
rep('''	var next:Vector2=actor.position+direction*speed*dt''',
'''	var slow_factor:float=0.45 if float(mob.get("slow_timer",0.0))>0.0 else 1.0
	var next:Vector2=actor.position+direction*speed*slow_factor*dt''')
rep('''	if mob["node"].position.distance_to(player.position)>110.0:return
	var evade:''',
'''	if mob["node"].position.distance_to(player.position)>110.0:return
	if barrier_charges>0 and barrier_timer>0.0:
		barrier_charges-=1
		_combat_popup(player.position,"BLOCK",Color("#ffe9a9"))
		hint_label.text="Your protective shield blocked the hit!"
		return
	var evade:''')

p.write_text(s,encoding="utf-8")
print("STARTING SKILLS PATCH OK: 18 original skills at level one, advanced mentor skills reserved.")
