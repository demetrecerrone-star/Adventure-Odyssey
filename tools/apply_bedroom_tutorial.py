#!/usr/bin/env python3
"""Install the playable starter bedroom after all character-creator patches.

The v0.3 source archive is never modified; patches are applied after unpacking.
Run after tools/apply_creator_visual_polish.py.
"""
from pathlib import Path

game = Path("scripts/game.gd")
src = game.read_text(encoding="utf-8")

def rep(old: str, new: str) -> None:
    global src
    occurrences = src.count(old)
    if occurrences != 1:
        raise SystemExit(f"BEDROOM PATCH ANCHOR FAILED ({occurrences}): {old[:110]!r}")
    src = src.replace(old, new, 1)

rep('const NPCS = [', '''const BEDROOM_SPAWN = Vector2(1024, 790)
const BEDROOM_OBJECTS = {
    "Bed": Vector2(870, 672),
    "Chest": Vector2(1350, 856),
    "Mirror": Vector2(1430, 645),
    "Door": Vector2(1040, 1006)
}
const NPCS = [''')
rep('var current_map := "town"', '''var bedroom_art: Node2D
var mirror_backup: Dictionary = {}
var current_map := "town"''')
rep('"map":"town", "pos":[1030.0,980.0]', '"map":"bedroom", "pos":[1024.0,790.0], "tutorial_stage":"wake", "storage":{}')
rep('''\tworld=null
\tplayer=null''', '''\tworld=null
\tbedroom_art=null
\tplayer=null''')
rep('''\tif not _save():
\t\tcreator_error.text="Could not save this character. Please try again."
\t\treturn
\t_enter_world("town",Vector2(1030,980))''',
'''\tdata["map"]="bedroom"
\tdata["pos"]=[BEDROOM_SPAWN.x,BEDROOM_SPAWN.y]
\tdata["tutorial_stage"]="wake"
\tdata["storage"]={}
\tif not _save():
\t\tcreator_error.text="Could not save this character. Please try again."
\t\treturn
\t_enter_world("bedroom",BEDROOM_SPAWN)''')
rep('''\tvar image=Sprite2D.new()
\timage.texture=load("res://assets/world/elmwatch_village.png" if map_name=="town" else "res://assets/world/thornbrook_forest.png")
\timage.centered=false
\timage.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tworld.add_child(image)
\t# Populate scene first. Everything uses coordinates in the 2048 x 1280 top-down image.
\tif map_name=="town":_spawn_npcs()
\telse:_spawn_mobs()''',
'''\tif map_name=="bedroom":
\t\tbedroom_art=Node2D.new()
\t\tbedroom_art.set_script(load("res://scripts/bedroom_scene.gd"))
\t\tworld.add_child(bedroom_art)
\telse:
\t\tvar image=Sprite2D.new()
\t\timage.texture=load("res://assets/world/elmwatch_village.png" if map_name=="town" else "res://assets/world/thornbrook_forest.png")
\t\timage.centered=false
\t\timage.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\t\tworld.add_child(image)
\t# Existing town/forest behavior is unchanged.
\tif map_name=="town":_spawn_npcs()
\telif map_name=="forest":_spawn_mobs()''')
rep('''\tcamera.limit_bottom=1280
\tcamera.enabled=true''',
'''\tcamera.limit_bottom=1280
\tif map_name=="bedroom":camera.zoom=Vector2(0.9,0.9)
\tcamera.enabled=true''')
rep('''\tvar town_label="ELMWATCH VILLAGE" if current_map=="town" else "THORNBROOK FOREST"''',
'''\tvar town_label="YOUR BEDROOM" if current_map=="bedroom" else ("ELMWATCH VILLAGE" if current_map=="town" else "THORNBROOK FOREST")''')
rep('''\thint_label=_label(hud,"Walk east to Thornbrook Forest",265,654,700,47,20,Color("fff2ce"),true)''',
'''\tvar first_hint="Your first day as an adventurer! Look around your room." if current_map=="bedroom" else "Walk east to Thornbrook Forest"
\thint_label=_label(hud,first_hint,265,654,700,47,20,Color("fff2ce"),true)''')
rep('''func _walkable(where:Vector2)->bool:
\tif current_map != "town":return true''',
'''func _walkable(where:Vector2)->bool:
\tif current_map=="bedroom":
\t\tif where.x<530 or where.x>1520 or where.y<347 or where.y>1008:return false
\t\tfor furniture in [Rect2(613,378,295,302),Rect2(1149,340,301,197),Rect2(1245,730,221,125),Rect2(1442,470,89,231),Rect2(526,737,109,130)]:
\t\t\tif furniture.has_point(where):return false
\t\treturn true
\tif current_map != "town":return true''')
rep('''\tif current_map=="town" and nearby.size()>0:prompt.text="Talk: %s" % nearby["name"]
\telif current_map=="forest":prompt.text="Attack nearby slimes!  |  Walk west to return"
\telse:prompt.text=""''',
'''\tif current_map=="bedroom":
\t\tvar target=_bedroom_target()
\t\tprompt.text="Use: "+target if not target.is_empty() else "Explore your room and try TALK / USE"
\telif current_map=="town" and nearby.size()>0:prompt.text="Talk: %s" % nearby["name"]
\telif current_map=="forest":prompt.text="Attack nearby slimes!  |  Walk west to return"
\telse:prompt.text=""''')
rep('''func _interact()->void:
\tif current_map!="town":return''',
'''func _interact()->void:
\tif current_map=="bedroom":
\t\t_interact_bedroom()
\t\treturn
\tif current_map!="town":return''')
src += '''
# -- Starter home, milestone one: a playable bedroom --
func _bedroom_target()->String:
\tif current_map!="bedroom" or player==null:return ""
\tvar best := ""
\tvar nearest := 154.0
\tfor key in BEDROOM_OBJECTS.keys():
\t\tvar distance=player.position.distance_to(BEDROOM_OBJECTS[key])
\t\tif distance<nearest:
\t\t\tbest=key
\t\t\tnearest=distance
\treturn best

func _interact_bedroom()->void:
\tmatch _bedroom_target():
\t\t"Bed":
\t\t\tdata["hp"]=int(data["max_hp"])
\t\t\t_refresh_hud()
\t\t\t_save()
\t\t\t_message("A good night's rest. Today is your first day as an adventurer!\\n\\nThe Elmwatch Guild is waiting beyond your home.")
\t\t"Chest":
\t\t\t_open_home_chest()
\t\t"Mirror":
\t\t\t_open_home_mirror()
\t\t"Door":
\t\t\tdata["tutorial_stage"]="door"
\t\t\t_save()
\t\t\t_message("The doorway leads to your cottage hallway. We'll connect the kitchen, living room, and front entrance in the next home-building stage.")
\t\t_:
\t\t\t_message("Move close to the bed, storage chest, mirror, or door, then tap TALK / USE.")

func _open_home_chest()->void:
\tif not data.has("storage") or typeof(data["storage"])!=TYPE_DICTIONARY:
\t\tdata["storage"]={}
\tif popup!=null and is_instance_valid(popup):popup.queue_free()
\tpopup=Control.new()
\tpopup.size=Vector2(1280,720)
\tui.add_child(popup)
\tvar shade=ColorRect.new()
\tshade.color=Color(0.0,0.0,0.0,0.68)
\tshade.size=Vector2(1280,720)
\tpopup.add_child(shade)
\t_panel(popup,Rect2(192,77,896,565),Color("#183044"))
\t_label(popup,"HOME STORAGE CHEST",260,91,770,52,33,Color("#f0d18b"),true)
\t_label(popup,"BACKPACK - STORE ONE",229,159,397,42,22,Color("#f4e5bf"),true)
\t_label(popup,"CHEST - TAKE ONE",660,159,396,42,22,Color("#f4e5bf"),true)
\tvar index=0
\tfor key in data["inventory"].keys():
\t\tvar qty=int(data["inventory"][key])
\t\tif qty<=0:continue
\t\tif index>=6:break
\t\t_label(popup,"%s  x%d" % [str(key),qty],238,215+index*55,267,42,18)
\t\t_button(popup,"STORE",520,213+index*55,105,44,_move_chest_item.bind(str(key),true))
\t\tindex+=1
\tindex=0
\tfor key in data["storage"].keys():
\t\tvar qty=int(data["storage"][key])
\t\tif qty<=0:continue
\t\tif index>=6:break
\t\t_label(popup,"%s  x%d" % [str(key),qty],657,215+index*55,260,42,18)
\t\t_button(popup,"TAKE",936,213+index*55,106,44,_move_chest_item.bind(str(key),false))
\t\tindex+=1
\t_button(popup,"CLOSE",508,569,260,53,_dismiss_message)

func _move_chest_item(item:String,to_storage:bool)->void:
\tvar source:Dictionary=data["inventory"] if to_storage else data["storage"]
\tvar destination:Dictionary=data["storage"] if to_storage else data["inventory"]
\tif int(source.get(item,0))<=0:return
\tsource[item]=int(source[item])-1
\tif int(source[item])<=0:source.erase(item)
\tdestination[item]=int(destination.get(item,0))+1
\t_save()
\t_open_home_chest()

func _open_home_mirror()->void:
\tif mirror_backup.is_empty():
\t\tfor key in ["body","hair","hair_tint","skin_tone","eye_color"]:
\t\t\tmirror_backup[key]=int(data.get(key,0))
\tif popup!=null and is_instance_valid(popup):popup.queue_free()
\tpopup=Control.new()
\tpopup.size=Vector2(1280,720)
\tui.add_child(popup)
\tvar dim=ColorRect.new()
\tdim.color=Color(0,0,0,0.67)
\tdim.size=Vector2(1280,720)
\tpopup.add_child(dim)
\t_panel(popup,Rect2(289,66,702,590),Color("#183044"))
\t_label(popup,"DRESSING MIRROR",348,84,588,53,31,Color("#f0d18b"),true)
\t_label(popup,"Adjust your look - no class or gear restrictions.",337,136,616,29,17,Color("#d9e0d7"),true)
\tvar types=["body","hair","hair_tint","skin_tone","eye_color"]
\tfor i in range(types.size()):
\t\tvar key=types[i]
\t\tvar y=181+i*70
\t\tvar title=""
\t\tvar value=""
\t\tmatch key:
\t\t\t"body":
\t\t\t\ttitle="Appearance"
\t\t\t\tvalue="%d / 8" % (int(data[key])+1)
\t\t\t"hair":
\t\t\t\ttitle="Hairstyle"
\t\t\t\tvalue=HAIR[int(data[key])].replace("_"," ").capitalize()
\t\t\t"hair_tint":
\t\t\t\ttitle="Hair color"
\t\t\t\tvalue=HAIR_TINT_NAMES[int(data[key])]
\t\t\t"skin_tone":
\t\t\t\ttitle="Skin tone"
\t\t\t\tvalue=SKIN_NAMES[int(data[key])]
\t\t\t"eye_color":
\t\t\t\ttitle="Eye color*"
\t\t\t\tvalue=EYE_NAMES[int(data[key])]
\t\t_label(popup,title,348,y,185,37,20)
\t\t_button(popup,"<",541,y-2,51,41,_mirror_adjust.bind(key,-1))
\t\t_label(popup,value,599,y,270,37,18,Color("#f4e5bf"),true)
\t\t_button(popup,">",886,y-2,51,41,_mirror_adjust.bind(key,1))
\t_label(popup,"*Eye tint is saved; sprite iris masks are still being made.",331,530,632,26,15,Color("#b9cfd8"),true)
\t_button(popup,"CANCEL",359,574,249,55,_mirror_cancel)
\t_button(popup,"SAVE LOOK",677,574,245,55,_mirror_accept)

func _mirror_adjust(key:String,delta:int)->void:
\tvar count=8
\tmatch key:
\t\t"hair":count=HAIR.size()
\t\t"hair_tint":count=HAIR_TINT_NAMES.size()
\t\t"skin_tone":count=SKIN_NAMES.size()
\t\t"eye_color":count=EYE_NAMES.size()
\tdata[key]=posmod(int(data.get(key,0))+delta,count)
\tif is_instance_valid(base_sprite):
\t\tbase_sprite.material=_skin_palette_material(clampi(int(data.get("skin_tone",0)),0,SKIN_NAMES.size()-1))
\t_set_player_frame()
\t_open_home_mirror()

func _mirror_cancel()->void:
\tfor key in mirror_backup.keys():
\t\tdata[key]=mirror_backup[key]
\tif is_instance_valid(base_sprite):
\t\tbase_sprite.material=_skin_palette_material(clampi(int(data.get("skin_tone",0)),0,SKIN_NAMES.size()-1))
\t_set_player_frame()
\tmirror_backup.clear()
\t_dismiss_message()

func _mirror_accept()->void:
\t_save()
\tmirror_backup.clear()
\t_dismiss_message()
'''
game.write_text(src, encoding="utf-8")

smoke=Path("tests/smoke_test.gd")
t=smoke.read_text(encoding="utf-8")
old='''\tif not _check(scene.current_map == "town" and scene.npcs.size() == 8,"Town/NPC population"):
\t\treturn'''
assert t.count(old)==1,"smoke expected town anchor missing"
t=t.replace(old,'''\tif not _check(scene.current_map == "bedroom" and scene.bedroom_art != null,"New hero wakes in bedroom"):
\t\treturn
\tscene._enter_world("town",Vector2(1030,980))
\tawait process_frame
\tif not _check(scene.current_map == "town" and scene.npcs.size() == 8,"Town/NPC population"):
\t\treturn''',1)
smoke.write_text(t,encoding="utf-8")

deep=Path("tests/creator_deep_test.gd")
t=deep.read_text(encoding="utf-8")
old='''\tif not _check(scene.player != null and scene.current_map == "town", "new character enters town"):return'''
assert t.count(old)==1,"creator expected town anchor missing"
t=t.replace(old,'''\tif not _check(scene.player != null and scene.current_map == "bedroom", "new character awakens in bedroom"):return''',1)
deep.write_text(t,encoding="utf-8")
print("BEDROOM PATCH OK: custom room, new-game spawn, collision, interactions, storage and mirror.")
