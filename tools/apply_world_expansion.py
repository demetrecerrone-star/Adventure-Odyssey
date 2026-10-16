#!/usr/bin/env python3
"""Progression areas, distinct enemy archetypes, side quests and a guardian boss.

Existing four beginner slimes, Guild rewards, character saves and forest map
remain untouched. Extras appear only after finishing Guild orientation.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(a,b):
    global s
    hits=s.count(a)
    if hits!=1:raise SystemExit(f"WORLD PATCH ANCHOR FAILED ({hits}): {a[:110]!r}")
    s=s.replace(a,b,1)

rep('''const ELMWATCH_TOWN_ART = "res://assets/world/elmwatch_village_new.jpg"''',
'''const ADVENTURE_ZONE_ART={
	"ruins":"res://assets/world/oldstone_ruins.svg",
	"sanctum":"res://assets/world/guardian_sanctum.svg"
}
const ELMWATCH_TOWN_ART = "res://assets/world/elmwatch_village_new.jpg"''')

rep('''var art_path = ELMWATCH_TOWN_ART if map_name=="town" else str(BUILDING_ART.get(map_name,"res://assets/world/thornbrook_forest_approved.jpg"))''',
'''var art_path = ELMWATCH_TOWN_ART if map_name=="town" else str(ADVENTURE_ZONE_ART.get(map_name,BUILDING_ART.get(map_name,"res://assets/world/thornbrook_forest_approved.jpg")))''')
rep('''	elif map_name=="forest":_spawn_mobs()''',
'''	elif map_name=="forest":_spawn_mobs()
	elif map_name=="ruins":_spawn_ruins_enemies()
	elif map_name=="sanctum":_spawn_sanctum_guardian()''')
rep('''{"bedroom":"YOUR BEDROOM","foyer":"COTTAGE FOYER","living":"LIVING ROOM / KITCHEN","town":"ELMWATCH VILLAGE","forest":"THORNBROOK FOREST"}''',
'''{"bedroom":"YOUR BEDROOM","foyer":"COTTAGE FOYER","living":"LIVING ROOM / KITCHEN","town":"ELMWATCH VILLAGE","forest":"THORNBROOK FOREST","ruins":"OLDSTONE RUINS","sanctum":"GUARDIAN SANCTUM"}''')
rep('''func _walkable(where:Vector2)->bool:
	if current_map=="forest":''',
'''func _walkable(where:Vector2)->bool:
	if current_map in ["ruins","sanctum"]:
		return where.x>=62.0 and where.x<=2000.0 and where.y>=175.0 and where.y<=1120.0
	if current_map=="forest":''')

rep('''		mobs.append(mob)

func _set_player_frame()->void:''',
'''		mob["species"]="slime"
		mobs.append(mob)
	if bool(data.get("guild_training_completed",false)):
		_spawn_extended_forest_enemies()

func _set_player_frame()->void:''')

rep('''	if current_map=="forest":
		monster_timer+=delta
		for mob in mobs:
			if mob["alive"]:
				var s:Sprite2D=mob["sprite"]
				s.texture=load(_sprite_path("monsters","green_slime_bounce","down",int(monster_timer*5)%3))''',
'''	if _is_adventure_combat_zone():
		monster_timer+=delta
		for mob in mobs:
			if mob["alive"] and str(mob.get("species","slime"))=="slime":
				var s:Sprite2D=mob["sprite"]
				s.texture=load(_sprite_path("monsters","green_slime_bounce","down",int(monster_timer*5)%3))''')
rep('''	if current_map=="forest":
		_update_slime_targeting()''',
'''	if _is_adventure_combat_zone():
		_update_slime_targeting()''')
rep('''	if current_map=="forest" and player.position.x<85:
		_enter_world("town",Vector2(1870,585))
		return''',
'''	if current_map=="forest" and player.position.x<85:
		_enter_world("town",Vector2(1870,585))
		return
	if current_map=="forest" and player.position.x>1965 and player.position.y>540 and player.position.y<800 and bool(data.get("guild_training_completed",false)):
		_enter_world("ruins",Vector2(130,655))
		return
	if current_map=="ruins" and player.position.x<85:
		_enter_world("forest",Vector2(1880,655))
		return
	if current_map=="ruins" and player.position.x>1940 and player.position.y>510 and player.position.y<840 and int(data.get("level",1))>=3:
		_enter_world("sanctum",Vector2(175,650))
		return
	if current_map=="sanctum" and player.position.x<95:
		_enter_world("ruins",Vector2(1850,655))
		return''')
rep('''	if current_map=="forest":
		monster_timer+=delta''', '''	if _is_adventure_combat_zone():
		monster_timer+=delta''') if False else None
rep('''		_tick_slime_ai(delta)
		if monster_timer>1000.0:monster_timer=0.0''',
'''		_tick_slime_ai(delta)
		if monster_timer>1000.0:monster_timer=0.0''') if False else None

rep('''	if current_map!="forest" or attack_cooldown>0:return''',
'''	if not _is_adventure_combat_zone() or attack_cooldown>0:return''')
rep('''	if current_map!="forest" or not bool(best.get("alive",false)):return''',
'''	if not _is_adventure_combat_zone() or not bool(best.get("alive",false)):return''')
rep('''	if current_map!="forest" or player==null:return {}''',
'''	if not _is_adventure_combat_zone() or player==null:return {}''')
rep('''	if current_map!="forest" or player==null:return found''',
'''	if not _is_adventure_combat_zone() or player==null:return found''')
rep('''	if current_map!="forest" and kind not in ["heal","shield","barrier","buff"]:''',
'''	if not _is_adventure_combat_zone() and kind not in ["heal","shield","barrier","buff"]:''')
rep('''	if current_map!="forest":return
	for mob in mobs:''',
'''	if not _is_adventure_combat_zone():return
	for mob in mobs:''')
rep('''	if current_map!="forest" or player==null:return
	var dt:float=clampf(delta,0.0,0.15)''',
'''	if not _is_adventure_combat_zone() or player==null:return
	var dt:float=clampf(delta,0.0,0.15)''')
rep('''	if current_map!="forest" or player==null or not mob["alive"]:return''',
'''	if not _is_adventure_combat_zone() or player==null or not mob["alive"]:return''')
rep('''	if mob["node"].position.distance_to(player.position)>110.0:return''',
'''	var reach:float=175.0 if str(mob.get("species",""))=="guardian" else 110.0
	if mob["node"].position.distance_to(player.position)>reach:return''')
rep('''		var taken:int=maxi(1,5-_gear_defense())''',
'''		var taken:int=maxi(1,int(mob.get("attack_damage",5))-_gear_defense())''')
rep('''		hint_label.text="A slime strikes! -%d HP" % taken''',
'''		hint_label.text="%s strikes! -%d HP" % [str(mob.get("species","slime")).capitalize(),taken]''')
rep('''		if mob["alive"] and player.position.distance_to(mob["node"].position)<105:''',
'''		if mob["alive"] and player.position.distance_to(mob["node"].position)<105:''') if False else None

rep('''	if current_map!="forest" or player==null:return
	var best:Dictionary={}''',
'''	if not _is_adventure_combat_zone() or player==null:return {}
	var best:Dictionary={}''') if False else None

rep('''			if player_dist<100.0:
				if float(mob["attack_cd"])<=0.0:
					mob["state"]="windup"
					mob["windup"]=0.58''',
'''			var attack_reach:float=165.0 if str(mob.get("species",""))=="guardian" else 100.0
			if player_dist<attack_reach:
				if float(mob["attack_cd"])<=0.0:
					mob["state"]="windup"
					mob["windup"]=1.15 if str(mob.get("species",""))=="guardian" else 0.58''')
rep('''				mob["attack_cd"]=2.25
				mob["state"]="pursue"''',
'''				mob["attack_cd"]=3.5 if str(mob.get("species",""))=="guardian" else 2.25
				mob["state"]="pursue"''')
rep('''		var actor:Node2D=mob["node"]
		var home:Vector2=mob["home"]''',
'''		if str(mob.get("species",""))=="guardian" and int(mob["hp"])<=int(mob["max_hp"])/2 and not bool(mob.get("phase_two",false)):
			mob["phase_two"]=true
			mob["attack_damage"]=16
			mob["sprite"].modulate=Color("#ffbb8b")
			_combat_popup(mob["node"].position,"GUARDIAN ENRAGED",Color("#ffbf91"))
		var actor:Node2D=mob["node"]
		var home:Vector2=mob["home"]''')
rep('''		# A fleeing or windup slime can be defeated; never resurrect here.''',
'''		# State machine serves slimes, wild creatures and the guardian boss.''')
rep('''		_slime_move(mob,(player.position-actor.position).normalized(),106.0,dt)''',
'''		_slime_move(mob,(player.position-actor.position).normalized(),float(mob.get("speed",106.0)),dt)''')
rep('''			_slime_move(mob,mob["roam_dir"],37.0,dt)''',
'''			_slime_move(mob,mob["roam_dir"],float(mob.get("speed",100.0))*0.36,dt)''')

rep('''		data["xp"]=int(data["xp"])+25
		data["gold"]=int(data["gold"])+3
		data["quest_kills"]=int(data["quest_kills"])+1
		_mentor_record_kill()''',
'''		var species:String=str(best.get("species","slime"))
		data["xp"]=int(data["xp"])+int(best.get("xp",25))
		data["gold"]=int(data["gold"])+int(best.get("gold",3))
		if species=="slime":
			data["quest_kills"]=int(data["quest_kills"])+1
			_mentor_record_kill()
		else:
			_record_expedition_kill(species)
			var drop:String=str(best.get("drop",""))
			if drop!="":
				data["inventory"][drop]=int(data["inventory"].get(drop,0))+1
		if species=="guardian" and not bool(data.get("guardian_defeated",false)):
			data["guardian_defeated"]=true
			data["inventory"]["Guardian Relic"]=int(data["inventory"].get("Guardian Relic",0))+1
			data["gold"]=int(data["gold"])+100
			_combat_popup(best["node"].position,"GUARDIAN DEFEATED",Color("#fff0ad"))''')

rep('''			_show_journal("FIRST FIELD ASSIGNMENT COMPLETE",[''',
'''			_show_journal("FIRST FIELD ASSIGNMENT COMPLETE",[''') if False else None
rep('''	if current_map!="forest":return
	for mob in mobs:
		if not bool(mob.get("alive",false)):continue
		mob["mentor_mark_timer"]''',
'''	if not _is_adventure_combat_zone():return
	for mob in mobs:
		if not bool(mob.get("alive",false)):continue
		mob["mentor_mark_timer"]''')

rep('''	if not _has_mentor_skill() or player==null or current_map!="forest":return''',
'''	if not _has_mentor_skill() or player==null or not _is_adventure_combat_zone():return''')
rep('''	if current_map=="forest" and kind not in ["heal","buff","barrier","shield","trap","summon","step"]:''',
'''	if _is_adventure_combat_zone() and kind not in ["heal","buff","barrier","shield","trap","summon","step"]:''')

rep('''	if who=="Mara Fenwick":
		_show_npc_chat(n,''',
'''	if who=="Ilyan Crest" and bool(data.get("guild_training_completed",false)) and _interact_expedition_quest(n):return
	if who=="Mara Fenwick":
		_show_npc_chat(n,''')

rep('''		_label(popup,"Discover additional requests as Elmwatch and Thornbrook expand.",186,488,900,40,20)''',
'''		_label(popup,_expedition_quest_hint(),186,488,900,40,20)''')
rep('''	elif current_map=="forest":
		var target=_nearest_attackable_slime()''',
'''	elif _is_adventure_combat_zone():
		var target=_nearest_attackable_slime()''')
rep('''	if current_map=="forest":
		monster_timer+=delta''', '''	if _is_adventure_combat_zone():
		monster_timer+=delta''') if False else None

s+=r'''
# -- Connected regions and enemies --------------------------------------------
func _is_adventure_combat_zone()->bool:
	return current_map in ["forest","ruins","sanctum"]

func _spawn_custom_enemy(species:String,where:Vector2,hp:int,damage:int,speed:float,xp:int,gold:int,loot:String="")->Dictionary:
	var enemy=_make_actor(world,where,"monsters","green_slime_bounce",0.61)
	var texture_path="res://assets/creatures/%s.svg" % species
	if ResourceLoader.exists(texture_path):
		enemy["sprite"].texture=load(texture_path)
		enemy["sprite"].texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	enemy["hp"]=hp
	enemy["max_hp"]=hp
	enemy["alive"]=true
	enemy["species"]=species
	enemy["attack_damage"]=damage
	enemy["speed"]=speed
	enemy["xp"]=xp
	enemy["gold"]=gold
	enemy["drop"]=loot
	enemy["home"]=where
	enemy["state"]="wander"
	enemy["roam_dir"]=Vector2.RIGHT.rotated(float(mobs.size())*1.8)
	enemy["roam_timer"]=1.3
	enemy["attack_cd"]=1.2
	enemy["windup"]=0.0
	enemy["retreat_left"]=0.0
	enemy["retreat_cd"]=0.0
	enemy["hit_reaction"]=0.0
	var indicator=Node2D.new()
	indicator.name="EnemyHealthIndicator"
	indicator.set_script(load("res://scripts/slime_combat_indicator.gd"))
	enemy["node"].add_child(indicator)
	indicator.call("update_health",hp,hp)
	enemy["indicator"]=indicator
	mobs.append(enemy)
	return enemy

func _spawn_extended_forest_enemies()->void:
	_spawn_custom_enemy("wolf",Vector2(810,410),52,7,135.0,42,6,"Wolf Pelt")
	_spawn_custom_enemy("goblin",Vector2(1270,690),49,6,112.0,45,8,"Iron Ore")
	_spawn_custom_enemy("fungus",Vector2(1640,850),43,5,72.0,40,5,"Herb")

func _spawn_ruins_enemies()->void:
	_spawn_custom_enemy("goblin",Vector2(610,460),62,8,120.0,58,11,"Iron Ore")
	_spawn_custom_enemy("wolf",Vector2(1030,720),67,9,142.0,60,10,"Wolf Pelt")
	_spawn_custom_enemy("fungus",Vector2(1460,435),55,7,83.0,52,9,"Herb")

func _spawn_sanctum_guardian()->void:
	if bool(data.get("guardian_defeated",false)):return
	_spawn_custom_enemy("guardian",Vector2(1110,640),300,12,88.0,250,65,"")

# A side request from the registrar: earn supplies by defeating wilderness
# creatures. Required kills occur only while the quest is active.
func _expedition_state()->String:
	return str(data.get("expedition_state",""))

func _expedition_quest_hint()->String:
	match _expedition_state():
		"active":return "Thornbrook Field Notes: %d/2 wild creatures defeated." % mini(2,int(data.get("expedition_kills",0)))
		"ready":return "Field Notes complete — report to Ilyan Crest at the Guild."
		"complete":return "Field Notes complete — reward collected."
	return "Talk to Ilyan Crest after Guild training for a side quest."

func _interact_expedition_quest(n:Dictionary)->bool:
	var state:String=_expedition_state()
	if state=="complete":return false
	if state=="ready":
		data["expedition_state"]="complete"
		data["gold"]=int(data["gold"])+30
		data["inventory"]["Health Potion"]=int(data["inventory"].get("Health Potion",0))+2
		_save()
		_refresh_hud()
		_show_npc_chat(n,"Excellent field notes! Here's 30 gold and two potions. Oldstone's ruins lie beyond Thornbrook's eastern trail.")
		return true
	if state=="active":
		_show_npc_chat(n,_expedition_quest_hint())
		return true
	_show_npc_chat(n,"I need observations of creatures beyond the beginner trail. Defeat two wild creatures in Thornbrook or Oldstone, then return for a reward. Take the job?")
	popup.offer_quest_accept(_accept_expedition)
	return true

func _accept_expedition()->void:
	if not bool(data.get("guild_training_completed",false)) or _expedition_state()!="":return
	data["expedition_state"]="active"
	data["expedition_kills"]=0
	_save()
	_show_journal("SIDE QUEST  /  THORNBROOK FIELD NOTES",[
		"Registrar Ilyan asks for field observations beyond the green slimes. Wolves, goblin scouts and Thorncaps now roam the wilderness.",
		"Defeat two non-slime wild creatures while this quest is active. You may travel east from Thornbrook into Oldstone Ruins after Guild training.",
		"Return to Ilyan Crest for 30 gold and two Health Potions. Quest completion is saved."
	])

func _record_expedition_kill(species:String)->void:
	if _expedition_state()!="active" or not species in ["wolf","goblin","fungus"]:return
	data["expedition_kills"]=mini(2,int(data.get("expedition_kills",0))+1)
	if int(data["expedition_kills"])>=2:
		data["expedition_state"]="ready"
		if hint_label!=null and is_instance_valid(hint_label):
			hint_label.text="FIELD NOTES COMPLETE! Return to Ilyan Crest."
'''
p.write_text(s,encoding="utf-8")
print("AO WORLD PATCH OK: new forest enemies, Oldstone exploration, boss and side quest.")
