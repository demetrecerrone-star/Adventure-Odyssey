#!/usr/bin/env python3
"""Wire approved Elmwatch artwork and building interiors into the playable game.
Run after apply_cottage_tutorial.py; leave archived v0.3 source and cosmetics intact.
"""
from pathlib import Path

file = Path("scripts/game.gd")
src = file.read_text(encoding="utf-8")

def rep(old: str, new: str) -> None:
    global src
    count = src.count(old)
    if count != 1:
        raise SystemExit(f"ELMWATCH ART PATCH ANCHOR FAILED ({count}): {old[:120]!r}")
    src = src.replace(old, new, 1)

rep('const HOME_STARTER =', '''const ELMWATCH_TOWN_ART = "res://assets/world/elmwatch_village_new.jpg"
const BUILDING_ART = {
    "guild":"res://assets/interiors/adventurers_guild.jpg",
    "market":"res://assets/interiors/market_shop.jpg",
    "inn":"res://assets/interiors/lantern_inn.jpg",
    "blacksmith":"res://assets/interiors/blacksmith.jpg"
}
# Door coordinates are first-pass entry markers near the existing NPC districts.
# After visual QA on the approved map, refine them to match the illustrated doors.
const ELMWATCH_DOORS = {
    "guild":Vector2(915,735),
    "market":Vector2(1380,560),
    "inn":Vector2(778,1060),
    "blacksmith":Vector2(1875,1010)
}
const BUILDING_LABELS = {
    "guild":"ADVENTURERS GUILD",
    "market":"MARKET SHOP",
    "inn":"LANTERN INN",
    "blacksmith":"BLACKSMITH"
}
const HOME_STARTER =''')

rep('''		image.texture=load("res://assets/world/elmwatch_village.png" if map_name=="town" else "res://assets/world/thornbrook_forest.png")
		image.centered=false''', '''		var art_path = ELMWATCH_TOWN_ART if map_name=="town" else str(BUILDING_ART.get(map_name,"res://assets/world/thornbrook_forest.png"))
		image.texture=load(art_path)
		if image.texture==null:
			push_error("Missing map artwork: "+art_path)
		else:
			image.scale=Vector2(2048.0 / float(image.texture.get_width()),1280.0 / float(image.texture.get_height()))
		image.name="MapArtwork"
		image.centered=false''')

rep('''	if map_name=="town":_spawn_npcs()
	elif map_name=="forest":_spawn_mobs()''', '''	if map_name=="town":
		_spawn_npcs()
		_add_elmwatch_signposts()
	elif map_name=="forest":_spawn_mobs()''')

rep('''	if map_name=="bedroom" or map_name=="cottage":camera.zoom=Vector2(0.9,0.9)''', '''	if map_name=="bedroom" or map_name=="cottage" or BUILDING_ART.has(map_name):camera.zoom=Vector2(0.9,0.9)''')

rep('''	var town_label="YOUR BEDROOM" if current_map=="bedroom" else ("STARTER COTTAGE" if current_map=="cottage" else ("ELMWATCH VILLAGE" if current_map=="town" else "THORNBROOK FOREST"))''',
'''	var town_label="YOUR BEDROOM" if current_map=="bedroom" else ("STARTER COTTAGE" if current_map=="cottage" else ("ELMWATCH VILLAGE" if current_map=="town" else (str(BUILDING_LABELS[current_map]) if BUILDING_LABELS.has(current_map) else "THORNBROOK FOREST")))''')

rep('''	var first_hint="Your first day as an adventurer! Look around your room." if current_map=="bedroom" else ("Explore the cottage and find the front door." if current_map=="cottage" else ("Visit the Adventurers Guild." if current_map=="town" else "Walk west to return to Elmwatch."))''',
'''	var first_hint="Your first day as an adventurer! Look around your room." if current_map=="bedroom" else ("Explore the cottage and find the front door." if current_map=="cottage" else ("Visit the Adventurers Guild." if current_map=="town" else ("Explore the building; use the front exit to return to Elmwatch." if BUILDING_ART.has(current_map) else "Walk west to return to Elmwatch.")))''')

rep('''func _walkable(where:Vector2)->bool:
	if current_map=="cottage":''',
'''func _walkable(where:Vector2)->bool:
	if BUILDING_ART.has(current_map):
		return where.x>=320 and where.x<=1728 and where.y>=310 and where.y<=1140
	if current_map=="cottage":''')

rep('''	elif current_map=="town" and _near_cottage_entry():prompt.text="Use: Cottage Entrance"''', '''	elif BUILDING_ART.has(current_map):
		prompt.text="Use: Return to Elmwatch" if player.position.distance_to(Vector2(1024,1090))<175.0 else "Explore the building and find the exit."
	elif current_map=="town" and _near_cottage_entry():prompt.text="Use: Cottage Entrance"
	elif current_map=="town" and not _nearest_building_entry().is_empty():prompt.text="Enter: "+str(BUILDING_LABELS[_nearest_building_entry()])''')

rep('''	if current_map=="cottage":
		_interact_cottage()
		return
	if current_map!="town":return''', '''	if current_map=="cottage":
		_interact_cottage()
		return
	if BUILDING_ART.has(current_map):
		if player.position.distance_to(Vector2(1024,1090))<175.0:
			var saved_pos=data.get("town_return_pos",[1030.0,980.0])
			_enter_world("town",Vector2(float(saved_pos[0]),float(saved_pos[1])))
		else:
			_message("Move toward the south entrance and press TALK / USE to return to Elmwatch.")
		return
	if current_map!="town":return''')

rep('''	if _near_cottage_entry():
		_enter_world("cottage",Vector2(1024,984))
		return
	var n=_nearest_npc()''', '''	if _near_cottage_entry():
		_enter_world("cottage",Vector2(1024,984))
		return
	var entry = _nearest_building_entry()
	if not entry.is_empty():
		data["town_return_pos"]=[player.position.x,player.position.y]
		_enter_world(entry,Vector2(1024,980))
		return
	var n=_nearest_npc()''')

src += '''
# -- Approved Elmwatch art, addressable building doors and future NPC staging --
func _nearest_building_entry()->String:
	if current_map!="town" or player==null:return ""
	var best:=""
	var nearest:=118.0
	for key in ELMWATCH_DOORS.keys():
		var d:float=player.position.distance_to(ELMWATCH_DOORS[key])
		if d<nearest:
			best=key
			nearest=d
	return best

func _add_elmwatch_signposts()->void:
	var marker_layer=Node2D.new()
	marker_layer.name="BuildingMarkers"
	world.add_child(marker_layer)
	for key in ELMWATCH_DOORS.keys():
		var sign=Label.new()
		sign.name=str(key).capitalize()+"Entry"
		sign.text="▼ "+str(BUILDING_LABELS[key])
		sign.position=ELMWATCH_DOORS[key]-Vector2(114,85)
		sign.size=Vector2(228,39)
		sign.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		sign.add_theme_font_size_override("font_size",17)
		sign.add_theme_color_override("font_color",Color("#ffe2a4"))
		sign.add_theme_color_override("font_outline_color",Color("#1c2730"))
		sign.add_theme_constant_override("outline_size",5)
		marker_layer.add_child(sign)
'''
file.write_text(src,encoding="utf-8")
print("ELMWATCH ART PATCH OK: approved village, four interiors, entry markers and safe return.")
