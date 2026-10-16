#!/usr/bin/env python3
"""Oldstone's illustrated entrance, three explorable dungeon floors and boss hall.

Run after apply_guardian_weapon_quest.py. Preserve existing quest/currency/
Guardian respawn logic and original Forest return. No Android export is needed.
"""
from pathlib import Path
path=Path("scripts/game.gd")
s=path.read_text(encoding="utf-8")
def rep(a,b):
    global s
    n=s.count(a)
    if n!=1:
        raise SystemExit(f"OLDSTONE DUNGEON PATCH ANCHOR FAILED ({n}): {a[:120]!r}")
    s=s.replace(a,b,1)

rep('''const ADVENTURE_ZONE_ART={
	"ruins":"res://assets/world/oldstone_ruins.svg",
	"sanctum":"res://assets/world/guardian_sanctum.svg"
}''',
'''const ADVENTURE_ZONE_ART={
	"ruins":"res://assets/world/oldstone_entrance.svg",
	"halls":"res://assets/world/oldstone_halls.svg",
	"library":"res://assets/world/oldstone_library.svg",
	"chapel":"res://assets/world/oldstone_chapel.svg",
	"sanctum":"res://assets/world/oldstone_sanctum.svg"
}''')
rep('''"ruins":"OLDSTONE RUINS","sanctum":"GUARDIAN SANCTUM"''',
''' "ruins":"OLDSTONE ENTRANCE","halls":"CRUMBLED HALLS  /  FLOOR 1","library":"ANCIENT LIBRARY  /  FLOOR 2","chapel":"FORGOTTEN CHAPEL  /  FLOOR 3","sanctum":"GUARDIAN SANCTUM  /  FLOOR 4"''')
rep('''if current_map in ["ruins","sanctum"]:
		return where.x>=62.0 and where.x<=2000.0 and where.y>=175.0 and where.y<=1120.0''',
'''if current_map in ["ruins","halls","library","chapel","sanctum"]:
		# Keep the center road, interior encounter zones, and both portals clear.
		return where.x>=62.0 and where.x<=2000.0 and where.y>=175.0 and where.y<=1120.0''')
rep('''return current_map in ["forest","ruins","sanctum"]''',
'''return current_map in ["forest","ruins","halls","library","chapel","sanctum"]''')
rep('''elif map_name=="ruins":_spawn_ruins_enemies()
	elif map_name=="sanctum":_spawn_sanctum_guardian()''',
'''elif map_name=="ruins":_spawn_ruins_enemies()
	elif map_name in ["halls","library","chapel"]:_spawn_oldstone_floor(map_name)
	elif map_name=="sanctum":_spawn_sanctum_guardian()''')
rep('''if current_map=="ruins" and player.position.x>1940 and player.position.y>510 and player.position.y<840 and int(data.get("level",1))>=3:
		_enter_world("sanctum",Vector2(175,650))
		return
	if current_map=="sanctum" and player.position.x<95:
		_enter_world("ruins",Vector2(1850,655))
		return''',
'''if current_map=="ruins" and player.position.x>1940 and player.position.y>510 and player.position.y<840 and int(data.get("level",1))>=3:
		_enter_world("halls",Vector2(175,650))
		return
	if current_map in ["halls","library","chapel"] and player.position.y>510 and player.position.y<840:
		if player.position.x<95:
			_enter_world(_oldstone_previous_room(current_map),Vector2(1840,650))
			return
		if player.position.x>1940:
			_enter_world(_oldstone_next_room(current_map),Vector2(175,650))
			return
	if current_map=="sanctum" and player.position.x<95:
		_enter_world("chapel",Vector2(1840,655))
		return''')
rep('''func _spawn_ruins_enemies()->void:
	_spawn_custom_enemy("goblin",Vector2(610,460),62,8,120.0,58,11,"Iron Ore")
	_spawn_custom_enemy("wolf",Vector2(1030,720),67,9,142.0,60,10,"Wolf Pelt")
	_spawn_custom_enemy("fungus",Vector2(1460,435),55,7,83.0,52,9,"Herb")''',
'''func _spawn_ruins_enemies()->void:
	_oldstone_spawn("goblin","stone_goblin",Vector2(610,460),62,8,120.0,58,11,"Iron Ore")
	_oldstone_spawn("wolf","ruins_wolf",Vector2(1030,720),67,9,142.0,60,10,"Wolf Pelt")
	_oldstone_spawn("fungus","cursed_fungus",Vector2(1460,435),55,7,83.0,52,9,"Herb")''')
rep('''	_spawn_custom_enemy("guardian",Vector2(1110,640),300,12,88.0,250,65,"")''',
'''	_oldstone_spawn("guardian","guardian",Vector2(1110,640),300,12,88.0,250,65,"")''')
# Newly introduced species have their own benign loot profiles and cannot produce Sigils.
rep('''	"guardian":{"coin_bonus":[8,16],"sigil_chance":0.10,"sigil_amount":5,"rolls":[["Ember Pendant",0.03]]}''',
'''	"skeleton":{"coin_bonus":[0,3],"sigil_chance":0.0,"rolls":[["Iron Ore",0.18],["Health Potion",0.05]]},
	"bat":{"coin_bonus":[0,2],"sigil_chance":0.0,"rolls":[["Enchanted Thread",0.24],["Health Potion",0.04]]},
	"archer":{"coin_bonus":[0,4],"sigil_chance":0.0,"rolls":[["Iron Ore",0.20],["Health Potion",0.06]]},
	"golem":{"coin_bonus":[0,5],"sigil_chance":0.0,"rolls":[["Iron Ore",0.52],["Ember Shard",0.04]]},
	"guardian":{"coin_bonus":[8,16],"sigil_chance":0.10,"sigil_amount":5,"rolls":[["Ember Pendant",0.03]]}''')

s+=r'''

# -- Five interconnected Oldstone maps, creature visuals and legal loot tables --
const OLDSTONE_FLOOR_PREVIOUS={"halls":"ruins","library":"halls","chapel":"library"}
const OLDSTONE_FLOOR_NEXT={"halls":"library","library":"chapel","chapel":"sanctum"}
const OLDSTONE_MONSTER_ART="res://assets/creatures/oldstone/"

func _oldstone_previous_room(room:String)->String:
	return str(OLDSTONE_FLOOR_PREVIOUS.get(room,"ruins"))

func _oldstone_next_room(room:String)->String:
	return str(OLDSTONE_FLOOR_NEXT.get(room,"sanctum"))

func _oldstone_spawn(species:String,appearance:String,where:Vector2,hp:int,damage:int,speed:float,xp:int,gold:int,loot:String="")->void:
	var enemy:Dictionary=_spawn_custom_enemy(species,where,hp,damage,speed,xp,gold,loot)
	var art:String=OLDSTONE_MONSTER_ART+appearance+".svg"
	if ResourceLoader.exists(art):
		var texture:Texture2D=load(art)
		if texture!=null:
			enemy["sprite"].texture=texture
			enemy["sprite"].texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	enemy["appearance"]=appearance

func _spawn_oldstone_floor(floor:String)->void:
	match floor:
		"halls":
			_oldstone_spawn("skeleton","ruins_skeleton",Vector2(585,555),78,10,95.0,70,11,"")
			_oldstone_spawn("goblin","stone_goblin",Vector2(1120,758),75,10,128.0,64,10,"Iron Ore")
			_oldstone_spawn("golem","stone_golem",Vector2(1550,450),145,13,70.0,104,18,"Iron Ore")
		"library":
			_oldstone_spawn("archer","ruins_archer",Vector2(640,452),72,11,127.0,67,11,"")
			_oldstone_spawn("bat","spore_bat",Vector2(1040,752),64,9,150.0,65,9,"")
			_oldstone_spawn("fungus","cursed_fungus",Vector2(1470,480),69,8,75.0,64,9,"Herb")
		"chapel":
			_oldstone_spawn("skeleton","ruins_skeleton",Vector2(620,750),92,11,108.0,84,13,"")
			_oldstone_spawn("fungus","cursed_fungus",Vector2(1040,430),80,11,94.0,72,11,"Herb")
			_oldstone_spawn("golem","stone_golem",Vector2(1520,725),155,15,75.0,118,20,"Iron Ore")
'''
path.write_text(s,encoding="utf-8")
print("AO OLDSTONE DUNGEON PATCH: 5 zones / 4 floors / unique monster visuals / 3 staged encounters / boss economy preserved.")
