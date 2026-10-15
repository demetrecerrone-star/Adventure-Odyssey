#!/usr/bin/env python3
"""Apply and test safe character creator upgrades to the archived Godot v0.3 source.

Designed to run after title patches, without modifying the approved title view.
"""
from pathlib import Path

game = Path("scripts/game.gd")
tests = Path("tests/smoke_test.gd")
source = game.read_text(encoding="utf-8")

def replace_once(old: str, new: str) -> None:
    global source
    if source.count(old) != 1:
        raise SystemExit("Creator patch aborted: expected source anchor not found exactly once: " + old[:110])
    source = source.replace(old, new, 1)

replace_once("const NPCS = [", '''const CLASS_DESCRIPTIONS = [
    "Warrior: close combat, resilience and frontline skills.",
    "Ranger: precision, mobility and ranged techniques.",
    "Mage: elemental spells and powerful magical attacks.",
    "Necromancer: curses, soul magic and undead allies.",
    "Assassin: stealth, critical strikes and swift attacks.",
    "Paladin: holy magic, protection and healing."
]
# Tint is separate from hairstyle; legacy hair sprites are already colored.
const HAIR_TINT_NAMES = ["Original", "Ash", "Copper", "Gold", "Violet", "Teal"]
const HAIR_TINTS = [
    Color(1.0, 1.0, 1.0),
    Color(0.75, 0.77, 0.84),
    Color(1.0, 0.66, 0.53),
    Color(1.0, 0.89, 0.49),
    Color(0.80, 0.56, 1.0),
    Color(0.49, 0.93, 0.88)
]
const PREVIEW_DIRECTIONS = ["down", "left", "up", "right"]
const PREVIEW_DIRECTION_NAMES = ["Front", "Left", "Back", "Right"]
const NAME_PATTERN = "^[\\\\p{L}\\\\p{N}][\\\\p{L}\\\\p{N} '-]{1,19}$"
const NPCS = [''')

replace_once('var current_map := "town"', '''var hair_tint_index := 0
var preview_direction_index := 0
var preview_class_description: Label
var preview_hair_tint: Label
var preview_direction_label: Label
var creator_error: Label
var creator_confirm_layer: Control
var current_map := "town"''')

replace_once('"hair":0, "level":1', '"hair":0, "hair_tint":0, "level":1')

replace_once('''func _save() -> void:
\tif player != null and is_instance_valid(player):
\t\tdata["map"] = current_map
\t\tdata["pos"] = [player.position.x, player.position.y]
\tvar file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
\tif file != null:
\t\tfile.store_string(JSON.stringify(data, "\\t"))
\t\tfile.close()

''', '''func _save() -> bool:
\tif player != null and is_instance_valid(player):
\t\tdata["map"] = current_map
\t\tdata["pos"] = [player.position.x, player.position.y]
\tvar file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
\tif file == null:
\t\tpush_error("Character save could not be opened.")
\t\treturn false
\tfile.store_string(JSON.stringify(data, "\\t"))
\tfile.close()
\treturn true

''')

replace_once('''\tdata = parsed
\treturn data.has("class") and data.has("stats") and data.has("body")
''', '''\tif not parsed.has("class") or not parsed.has("stats") or not parsed.has("body"):
\t\treturn false
\tif not CLASSES.has(str(parsed["class"])):
\t\treturn false
\tif typeof(parsed["stats"]) != TYPE_DICTIONARY:
\t\treturn false
\tfor attribute in STATS:
\t\tif not parsed["stats"].has(attribute):
\t\t\treturn false
\tparsed["body"] = clampi(int(parsed["body"]), 0, 7)
\tparsed["hair"] = clampi(int(parsed.get("hair", 0)), 0, HAIR.size()-1)
\tparsed["hair_tint"] = clampi(int(parsed.get("hair_tint", 0)), 0, HAIR_TINTS.size()-1)
\tdata = parsed
\treturn true
''')

replace_once('''\thair_index=0
\t_show_creator()
''','''\thair_index=0
\thair_tint_index=0
\tpreview_direction_index=0
\t_show_creator()
''')

begin = 'func _show_creator() -> void:'
end = 'func _select_class(delta:int)->void:'
if source.count(begin) != 1 or source.count(end) != 1:
    raise SystemExit("Creator layout not found.")
layout = '''func _show_creator() -> void:
\t_clear_ui()
\tcreator_confirm_layer=null
\t_picture(ui,"res://assets/menus/character_blank_1280x720.png",Vector2.ZERO,Vector2(1280,720))
\t_panel(ui,Rect2(38,38,525,620),Color(0.04,0.10,0.17,0.83))
\t_panel(ui,Rect2(575,38,661,620),Color(0.04,0.10,0.17,0.83))
\t_label(ui,"CREATE YOUR ADVENTURER",49,50,1160,54,38,Color("f0cd85"),true)
\tpreview_base=Sprite2D.new()
\tpreview_base.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tpreview_base.position=Vector2(0,-64)
\tpreview_hair=Sprite2D.new()
\tpreview_hair.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tpreview_hair.position=Vector2(0,-101)
\tpreview_hair.scale=Vector2(0.60,0.58)
\tvar preview_actor=Node2D.new()
\tpreview_actor.position=Vector2(300,625)
\tpreview_actor.scale=Vector2(2.7,2.7)
\tui.add_child(preview_actor)
\tpreview_actor.add_child(preview_base)
\tpreview_actor.add_child(preview_hair)
\t_button(ui,"<",72,580,57,51,func():_rotate_preview(-1))
\t_button(ui,">",465,580,57,51,func():_rotate_preview(1))
\tpreview_direction_label=_label(ui,"",166,583,264,40,21,Color("f4e5bf"),true)

\t_label(ui,"Character Name",619,116,205,38,22)
\tchar_input=LineEdit.new()
\tchar_input.position=Vector2(824,119)
\tchar_input.size=Vector2(340,42)
\tchar_input.text="Adventurer"
\tchar_input.max_length=20
\tchar_input.add_theme_font_size_override("font_size",22)
\tchar_input.placeholder_text="2-20 letters/numbers"
\tui.add_child(char_input)

\t_label(ui,"Class",626,168,240,33,20)
\tpreview_class=_label(ui,"",659,195,466,38,29,Color("f0cd85"),true)
\t_button(ui,"<",600,197,52,44,func():_select_class(-1))
\t_button(ui,">",1134,197,52,44,func():_select_class(1))
\tpreview_class_description=_label(ui,"",620,243,567,36,17,Color("d2d7cf"),true)

\t_label(ui,"Base appearance / skin tone",619,281,450,31,20)
\tpreview_body=_label(ui,"",654,309,471,36,25,Color("f4e5bf"),true)
\t_button(ui,"<",600,307,52,44,func():_select_body(-1))
\t_button(ui,">",1134,307,52,44,func():_select_body(1))

\t_label(ui,"Hairstyle",619,356,450,31,20)
\tpreview_hairstyle=_label(ui,"",653,383,474,37,24,Color("f4e5bf"),true)
\t_button(ui,"<",600,382,52,44,func():_select_hair(-1))
\t_button(ui,">",1134,382,52,44,func():_select_hair(1))

\t_label(ui,"Hair tint",619,431,450,31,20)
\tpreview_hair_tint=_label(ui,"",653,460,474,37,23,Color("f4e5bf"),true)
\t_button(ui,"<",600,455,52,44,func():_select_hair_tint(-1))
\t_button(ui,">",1134,455,52,44,func():_select_hair_tint(1))

\t_label(ui,"Class abilities are unique; equipment is unrestricted.",607,506,597,33,17,Color("b9ced3"),true)
\tcreator_error=_label(ui,"",602,535,600,34,17,Color("ffaba5"),true)
\t_button(ui,"BACK",600,574,210,60,_show_title)
\t_button(ui,"BEGIN ADVENTURE",834,574,369,60,_confirm_character)
\t_update_preview()

'''
source = source[:source.index(begin)] + layout + source[source.index(end):]

replace_once('func _sprite_path(group:String, variant:String, direction:String, frame:int)->String:', '''func _select_hair_tint(delta:int)->void:
\thair_tint_index=posmod(hair_tint_index+delta,HAIR_TINT_NAMES.size())
\t_update_preview()

func _rotate_preview(delta:int)->void:
\tpreview_direction_index=posmod(preview_direction_index+delta,PREVIEW_DIRECTIONS.size())
\t_update_preview()

func _valid_character_name(candidate:String)->bool:
\tvar name=candidate.strip_edges()
\tif name.length()<2 or name.length()>20:
\t\treturn false
\tvar expression=RegEx.new()
\tif expression.compile(NAME_PATTERN)!=OK:
\t\treturn false
\treturn expression.search(name)!=null

func _confirm_character()->void:
\tif not _valid_character_name(char_input.text):
\t\tcreator_error.text="Use 2-20 letters or numbers; spaces, hyphens and apostrophes are OK."
\t\tchar_input.grab_focus()
\t\treturn
\tcreator_error.text=""
\tif creator_confirm_layer!=null and is_instance_valid(creator_confirm_layer):
\t\treturn
\tcreator_confirm_layer=Control.new()
\tcreator_confirm_layer.size=Vector2(1280,720)
\tcreator_confirm_layer.mouse_filter=Control.MOUSE_FILTER_STOP
\tui.add_child(creator_confirm_layer)
\t_panel(creator_confirm_layer,Rect2(584,182,641,346),Color(0.03,0.09,0.16,0.98))
\t_label(creator_confirm_layer,"CONFIRM YOUR ADVENTURER",616,197,572,43,29,Color("f0cd85"),true)
\tvar name=char_input.text.strip_edges()
\t_label(creator_confirm_layer,"%s  -  %s" % [name,CLASSES[class_index]],610,260,590,38,25,Color("f4e5bf"),true)
\t_label(creator_confirm_layer,"Appearance %d  /  %s" % [body_index+1,HAIR[hair_index].replace("_"," ").capitalize()],610,319,590,33,19,Color("d8e5df"),true)
\t_label(creator_confirm_layer,"Hair tint: %s" % HAIR_TINT_NAMES[hair_tint_index],610,357,590,32,19,Color("d8e5df"),true)
\t_button(creator_confirm_layer,"EDIT",621,429,245,63,_cancel_creator_confirmation)
\t_button(creator_confirm_layer,"CONFIRM",898,429,290,63,_create_character)

func _cancel_creator_confirmation()->void:
\tif creator_confirm_layer!=null and is_instance_valid(creator_confirm_layer):
\t\tcreator_confirm_layer.queue_free()
\tcreator_confirm_layer=null

func _sprite_path(group:String, variant:String, direction:String, frame:int)->String:''')

replace_once('''func _update_preview()->void:
\tpreview_base.texture=load(_sprite_path("characters","base_variant_%02d" % (body_index+1),"down",0))
\tpreview_hair.texture=load(_sprite_path("hair",HAIR[hair_index],"down",0))
\tpreview_class.text=CLASSES[class_index]
\tpreview_body.text="Appearance %d of 8" % (body_index+1)
\tpreview_hairstyle.text=HAIR[hair_index].replace("_"," ").capitalize()
''','''func _update_preview()->void:
\tvar direction=PREVIEW_DIRECTIONS[preview_direction_index]
\tpreview_base.texture=load(_sprite_path("characters","base_variant_%02d" % (body_index+1),direction,0))
\tpreview_hair.texture=load(_sprite_path("hair",HAIR[hair_index],direction,0))
\tpreview_hair.modulate=HAIR_TINTS[hair_tint_index]
\tpreview_class.text=CLASSES[class_index]
\tpreview_class_description.text=CLASS_DESCRIPTIONS[class_index]
\tpreview_body.text="Appearance %d of 8" % (body_index+1)
\tpreview_hairstyle.text=HAIR[hair_index].replace("_"," ").capitalize()
\tpreview_hair_tint.text=HAIR_TINT_NAMES[hair_tint_index]
\tpreview_direction_label.text=PREVIEW_DIRECTION_NAMES[preview_direction_index]
''')

replace_once('''func _create_character()->void:
\tvar char_name=char_input.text.strip_edges()
\tif char_name.is_empty():char_name="Adventurer"
\tdata["name"]=char_name
\tdata["class"]=CLASSES[class_index]
\tdata["body"]=body_index
\tdata["hair"]=hair_index
\t_save()
\t_enter_world("town",Vector2(1030,980))
''','''func _create_character()->void:
\tif not _valid_character_name(char_input.text):
\t\tcreator_error.text="Please enter a valid character name (2-20 characters)."
\t\tchar_input.grab_focus()
\t\treturn
\tdata["name"]=char_input.text.strip_edges()
\tdata["class"]=CLASSES[class_index]
\tdata["body"]=body_index
\tdata["hair"]=hair_index
\tdata["hair_tint"]=hair_tint_index
\tif not _save():
\t\tcreator_error.text="Could not save this character. Please try again."
\t\treturn
\t_enter_world("town",Vector2(1030,980))
''')

replace_once('''\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))
''','''\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))
\thair_sprite.modulate=HAIR_TINTS[clampi(int(data.get("hair_tint",0)),0,HAIR_TINTS.size()-1)]
''')

game.write_text(source, encoding="utf-8")
smoke=tests.read_text(encoding="utf-8")
anchor='''\tscene.char_input.text = "SmokeTester"
\tscene._create_character()
'''
assert smoke.count(anchor)==1, "Smoke test update requires known test source"
smoke=smoke.replace(anchor, '''\t# Creator checks: blank names cannot start or save a character.
\tscene.char_input.text = "   "
\tscene._create_character()
\tif not _check(scene.player == null and not scene.creator_error.text.is_empty(), "Blank name rejected"):
\t\treturn
\tscene.char_input.text = "Valid Tester"
\tscene._select_body(7)
\tscene._select_hair(5)
\tscene._select_hair_tint(3)
\tscene._rotate_preview(1)
\tif not _check(scene.preview_body.text == "Appearance 8 of 8" and scene.preview_direction_label.text == "Left", "Creator appearance and preview rotation"):
\t\treturn
\tif not _check(scene.preview_base.texture != null and scene.preview_hair.texture != null and scene.preview_hair_tint.text == "Gold", "Creator hair and tint preview"):
\t\treturn
\tscene._confirm_character()
\tif not _check(scene.creator_confirm_layer != null, "Final confirmation shown"):
\t\treturn
\tscene._cancel_creator_confirmation()
\tscene._create_character()
\tif not _check(scene.data["name"] == "Valid Tester" and int(scene.data["body"]) == 7 and int(scene.data["hair"]) == 5 and int(scene.data["hair_tint"]) == 3, "Creator selections recorded"):
\t\treturn
\tif not _check(scene._load_save() and int(scene.data["hair_tint"]) == 3 and scene.data["name"] == "Valid Tester", "Creator selections persist after reload"):
\t\treturn
''',1)
tests.write_text(smoke,encoding="utf-8")
print("CREATOR PATCH OK: class guidance, four-direction preview, hair tint, name validation, confirmation, persistence and regression tests")
