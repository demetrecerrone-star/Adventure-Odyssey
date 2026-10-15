#!/usr/bin/env python3
"""Install modular starter-home artwork and save its selected furniture styles.

Run AFTER tools/apply_dialogue_ui.py on the unpacked Godot project.
The archived ZIP and existing character, chest, and mirror logic stay untouched.
"""
from pathlib import Path

GAME = Path("scripts/game.gd")
source = GAME.read_text(encoding="utf-8")

def replace_once(before: str, after: str) -> None:
    global source
    count = source.count(before)
    if count != 1:
        raise SystemExit(f"HOME FURNITURE PATCH FAILED ({count}): {before[:90]!r}")
    source = source.replace(before, after, 1)

replace_once('const NPCS = [', '''const HOME_STARTER = {"Bed":"oak_green", "Mirror":"tall_oak", "Chest":"plain_wood"}
const NPCS = [''')
replace_once('"tutorial_stage":"wake", "storage":{}, "stats":', '''"tutorial_stage":"wake", "storage":{}, "home_styles":{"Bed":"oak_green","Mirror":"tall_oak","Chest":"plain_wood"}, "home_owned":{"Bed":["oak_green"],"Mirror":["tall_oak"],"Chest":["plain_wood"]}, "stats":''')
replace_once('"Bed": Vector2(870, 672)', '"Bed": Vector2(520, 600)')
replace_once('"Chest": Vector2(1350, 856)', '"Chest": Vector2(1515, 920)')
replace_once('"Mirror": Vector2(1430, 645)', '"Mirror": Vector2(1615, 655)')
replace_once('"Door": Vector2(1040, 1006)', '"Door": Vector2(1024, 1100)')
replace_once('''\t\tworld.add_child(bedroom_art)
\telse:
\t\tvar image=Sprite2D.new()''', '''\t\tworld.add_child(bedroom_art)
\t\t_ensure_home_styles()
\t\tbedroom_art.call("apply_styles", data["home_styles"])
\telse:
\t\tvar image=Sprite2D.new()''')
replace_once('''\t\tif where.x<530 or where.x>1520 or where.y<347 or where.y>1008:return false
\t\tfor furniture in [Rect2(613,378,295,302),Rect2(1149,340,301,197),Rect2(1245,730,221,125),Rect2(1442,470,89,231),Rect2(526,737,109,130)]:''', '''\t\tif where.x<300 or where.x>1745 or where.y<425 or where.y>1135:return false
\t\t# Collision follows the currently placed bed, storage chest, and mirror.
\t\tfor furniture in [Rect2(390,480,250,260),Rect2(1432,850,190,125),Rect2(1554,545,124,174)]:''')
replace_once('''\t_button(popup,"CLOSE",508,569,260,53,_dismiss_message)''', '''\t_button(popup,"CLOSE",332,569,260,53,_dismiss_message)
\t_button(popup,"ROOM STYLE",677,569,280,53,_open_home_decor)''')
source += '''
# -- Modular home appearance, separate from all gameplay inventory systems --
func _ensure_home_styles()->void:
\tif typeof(data.get("home_styles",null))!=TYPE_DICTIONARY:
\t\tdata["home_styles"]={}
\tif typeof(data.get("home_owned",null))!=TYPE_DICTIONARY:
\t\tdata["home_owned"]={}
\tvar chosen:Dictionary=data["home_styles"]
\tvar owned:Dictionary=data["home_owned"]
\tfor slot in HOME_STARTER.keys():
\t\tif str(chosen.get(slot,"")).is_empty():
\t\t\tchosen[slot]=HOME_STARTER[slot]
\t\tif typeof(owned.get(slot,null))!=TYPE_ARRAY:
\t\t\towned[slot]=[HOME_STARTER[slot]]
\t\telif not owned[slot].has(HOME_STARTER[slot]):
\t\t\towned[slot].append(HOME_STARTER[slot])
\t\tif not owned[slot].has(chosen[slot]):
\t\t\tchosen[slot]=HOME_STARTER[slot]

func _open_home_decor()->void:
\t_ensure_home_styles()
\tif popup!=null and is_instance_valid(popup):popup.queue_free()
\tpopup=Control.new()
\tpopup.size=Vector2(1280,720)
\tui.add_child(popup)
\tvar shade=ColorRect.new()
\tshade.color=Color(0,0,0,0.72)
\tshade.size=Vector2(1280,720)
\tpopup.add_child(shade)
\t_panel(popup,Rect2(246,89,786,555),Color("#183044"))
\t_label(popup,"YOUR HOME  /  FURNITURE",300,108,682,49,29,Color("#f0d18b"),true)
\t_label(popup,"Starter furnishings are yours permanently and cost nothing.",298,162,688,48,19,Color("#d9e0d7"),true)
\tvar slots=["Bed","Mirror","Chest"]
\tfor i in range(slots.size()):
\t\tvar slot=slots[i]
\t\tvar y=240+i*82
\t\t_label(popup,slot.to_upper(),308,y,188,42,25,Color("#f0d18b"))
\t\t_label(popup,str(data["home_styles"].get(slot,HOME_STARTER[slot])).replace("_"," ").capitalize(),521,y,441,41,22,Color("#f4e5bf"))
\t_label(popup,"More designs will be earnable with in-game gold in a future update.",290,511,703,42,17,Color("#b9cfd8"),true)
\t_button(popup,"BACK TO CHEST",477,570,326,55,_open_home_chest)
'''
GAME.write_text(source, encoding="utf-8")

ROOM = '''extends Node2D
# The empty room is one background and each functional furnishing is its own sprite.
const BACKGROUND = "res://assets/home/empty_bedroom.jpg"
const HOME_DIR = "res://assets/home/"
const DEFAULT_STYLE = {"Bed":"oak_green", "Mirror":"tall_oak", "Chest":"plain_wood"}
const SLOT_DATA = {
    "Bed":{"folder":"beds", "pos":Vector2(520,600), "size":Vector2(248,258)},
    "Mirror":{"folder":"mirrors", "pos":Vector2(1615,655), "size":Vector2(143,220)},
    "Chest":{"folder":"chests", "pos":Vector2(1515,920), "size":Vector2(194,139)}
}
var sprites:Dictionary={}

func _ready()->void:
    var backdrop=Sprite2D.new()
    backdrop.name="EmptyRoomBackground"
    backdrop.centered=false
    backdrop.texture=load(BACKGROUND)
    backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    backdrop.scale=Vector2(2048.0/float(backdrop.texture.get_width()),1280.0/float(backdrop.texture.get_height()))
    backdrop.z_index=-10
    add_child(backdrop)
    for slot in ["Bed","Mirror","Chest"]:
        var sprite=Sprite2D.new()
        sprite.name=slot
        sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.centered=true
        sprite.position=SLOT_DATA[slot]["pos"]
        sprite.z_index=1
        add_child(sprite)
        sprites[slot]=sprite
    apply_styles(DEFAULT_STYLE)

func apply_styles(styles:Dictionary)->void:
    for slot in ["Bed","Mirror","Chest"]:
        var variant=str(styles.get(slot,DEFAULT_STYLE[slot]))
        var prefix=HOME_DIR+SLOT_DATA[slot]["folder"]+"/"
        var path=prefix+variant+".png"
        if not ResourceLoader.exists(path):
            path=prefix+DEFAULT_STYLE[slot]+".png"
        if not ResourceLoader.exists(path):
            push_error("Missing starter furniture sprite: "+path)
            continue
        var sprite:Sprite2D=sprites[slot]
        sprite.texture=load(path)
        var requested:Vector2=SLOT_DATA[slot]["size"]
        sprite.scale=Vector2(requested.x/float(sprite.texture.get_width()),requested.y/float(sprite.texture.get_height()))
'''
Path("scripts/bedroom_scene.gd").write_text(ROOM, encoding="utf-8")

bedroom_test = Path("tests/bedroom_test.gd")
test = bedroom_test.read_text(encoding="utf-8")
needle = 'not scene._walkable(Vector2(670,470)) and scene._walkable(Vector2(1010,870))'
if test.count(needle) != 1:
    raise SystemExit("Home collision test anchor did not match")
test = test.replace(needle, 'not scene._walkable(Vector2(510,600)) and scene._walkable(Vector2(1010,870))', 1)
# Existing bedroom proximity regression tests follow the newly placed furniture.
test = test.replace("scene.player.position=Vector2(1340,877)", "scene.player.position=Vector2(1410,930)", 1)
test = test.replace("scene.player.position=Vector2(1393,676)", "scene.player.position=Vector2(1540,710)", 1)
bedroom_test.write_text(test, encoding="utf-8")
print("HOME FURNITURE PATCH OK: starter sprites, save persistence, and style preview.")
