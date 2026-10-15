#!/usr/bin/env python3
"""Install v0.3 creator improvements into the unpacked Godot project.

Run after apply_title_screen.py and apply_dabsky_title.py. Source archive and
the user's approved title art are never modified.
"""
from pathlib import Path
import re

game_path = Path("scripts/game.gd")
s = game_path.read_text(encoding="utf-8")
assert "func _show_creator() -> void:" in s
assert "func _make_actor(" in s
assert "var hair_index := 0" in s
assert "func _load_save() -> bool:" in s
assert "func _random_default() -> void:" in s

s = s.replace(
    'const NPCS = [',
    '''const CREATOR_DIRECTIONS = ["down", "left", "up", "right"]
const HAIR_COLORS = ["Natural", "Black", "Chestnut", "Blonde", "Copper", "Silver", "Blue", "Violet", "Green"]
const HAIR_COLOR_HEX = ["ffffff", "272335", "8f5739", "e8c46e", "c46e46", "c6d5e0", "528de3", "a97cdc", "5dbb83"]
const SKIN_TONES = ["Original", "Fair", "Light", "Medium", "Tan", "Deep", "Dark"]
const SKIN_TONE_HEX = ["ffffff", "f8d8bc", "e7b997", "c58d69", "a87551", "81523a", "57382e"]
const EYE_COLORS = ["Brown", "Hazel", "Blue", "Green", "Gray", "Violet", "Amber"]
const EYE_COLOR_HEX = ["68452e", "997b48", "548ac2", "5e9f6e", "8295a1", "9b72bb", "bb9148"]
const CLASS_GUIDES = [
    "WARRIOR  |  Steady melee combat and defensive techniques.",
    "RANGER  |  Ranged skills, traps, and wilderness awareness.",
    "MAGE  |  Elemental spells and tactical magic.",
    "NECROMANCER  |  Shadow magic and summoned allies.",
    "ASSASSIN  |  Swift strikes, stealth, and critical damage.",
    "PALADIN  |  Protective magic, healing, and frontline combat."
]
const NPCS = [''',
    1,
)
s = s.replace(
    'var hair_index := 0',
    '''var hair_index := 0
var skin_index := 0
var eye_index := 0
var hair_color_index := 0
var preview_direction_index := 0
var preview_class_guide: Label
var preview_skin: Label
var preview_eye: Label
var preview_hair_color: Label
var preview_facing: Label
var creator_error: Label''',
    1,
)
# Backward-compatible saves: old characters use their original skin and hair.
s = s.replace(
    '"hair":0, "level":1',
    '"hair":0, "skin_tone":0, "eye_color":0, "hair_color":0, "level":1',
    1,
)
s = s.replace(
    '\tdata = parsed\n\treturn data.has("class") and data.has("stats") and data.has("body")',
    '''\tif not parsed.has("class") or not parsed.has("stats") or not parsed.has("body"):
\t\treturn false
\tdata = parsed
\tif not data.has("hair"):data["hair"]=0
\tif not data.has("skin_tone"):data["skin_tone"]=0
\tif not data.has("eye_color"):data["eye_color"]=0
\tif not data.has("hair_color"):data["hair_color"]=0
\treturn true''',
    1,
)

begin = s.index('func _open_creator() -> void:')
end = s.index('func _make_actor(', begin)
s = s[:begin] + '''func _open_creator() -> void:
\t_random_default()
\tclass_index=0
\tbody_index=0
\thair_index=0
\tskin_index=0
\teye_index=0
\thair_color_index=0
\tpreview_direction_index=0
\t_show_creator()

func _show_creator() -> void:
\t_clear_world()
\t_clear_ui()
\t_picture(ui,"res://assets/menus/character_blank_1280x720.png",Vector2.ZERO,Vector2(1280,720))
\t_panel(ui,Rect2(38,38,525,620),Color(0.04,0.10,0.17,0.90))
\t_panel(ui,Rect2(575,38,661,620),Color(0.04,0.10,0.17,0.90))
\t_label(ui,"CREATE YOUR ADVENTURER",49,48,1160,58,37,Color("f0cd85"),true)

\tpreview_base=Sprite2D.new()
\tpreview_base.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tpreview_base.position=Vector2(0,-64)
\tpreview_hair=Sprite2D.new()
\tpreview_hair.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tpreview_hair.position=Vector2(0,-101)
\tpreview_hair.scale=Vector2(0.60,0.58)
\tvar preview_actor=Node2D.new()
\tpreview_actor.position=Vector2(300,562)
\tpreview_actor.scale=Vector2(2.55,2.55)
\tui.add_child(preview_actor)
\tpreview_actor.add_child(preview_base)
\tpreview_actor.add_child(preview_hair)
\t_label(ui,"Live character preview",90,153,415,36,25,Color("eed29d"),true)
\t_button(ui,"<",118,600,72,49,func():_rotate_preview(-1))
\tpreview_facing=_label(ui,"",196,608,210,34,22,Color("d6e8ee"),true)
\t_button(ui,">",414,600,72,49,func():_rotate_preview(1))

\t_label(ui,"Character Name",606,112,230,33,23)
\tchar_input=LineEdit.new()
\tchar_input.position=Vector2(835,112)
\tchar_input.size=Vector2(352,45)
\tchar_input.placeholder_text="2-20 characters"
\tchar_input.text="Adventurer"
\tchar_input.max_length=20
\tchar_input.add_theme_font_size_override("font_size",22)
\tchar_input.text_changed.connect(func(_new_text:String):_reset_creator_error())
\tui.add_child(char_input)

\t_label(ui,"Class",611,166,145,32,21)
\t_button(ui,"<",602,200,50,46,func():_select_class(-1))
\tpreview_class=_label(ui,"",656,204,470,42,26,Color("f0cd85"),true)
\t_button(ui,">",1137,200,50,46,func():_select_class(1))
\tpreview_class_guide=_label(ui,"",610,250,590,50,17,Color("d5dee6"),true)

\t_label(ui,"Base appearance",612,302,280,33,20)
\t_label(ui,"Hairstyle",907,302,270,33,20)
\t_button(ui,"<",605,337,46,46,func():_select_body(-1))
\tpreview_body=_label(ui,"",652,341,194,39,19,Color("ffffff"),true)
\t_button(ui,">",844,337,46,46,func():_select_body(1))
\t_button(ui,"<",904,337,46,46,func():_select_hair(-1))
\tpreview_hairstyle=_label(ui,"",953,341,181,39,17,Color("ffffff"),true)
\t_button(ui,">",1138,337,46,46,func():_select_hair(1))

\t_label(ui,"Skin tone",612,393,250,31,20)
\t_label(ui,"Hair color",908,393,250,31,20)
\t_button(ui,"<",605,427,46,43,func():_select_skin(-1))
\tpreview_skin=_label(ui,"",653,431,192,36,19,Color("ffffff"),true)
\t_button(ui,">",844,427,46,43,func():_select_skin(1))
\t_button(ui,"<",904,427,46,43,func():_select_hair_color(-1))
\tpreview_hair_color=_label(ui,"",955,431,178,36,19,Color("ffffff"),true)
\t_button(ui,">",1138,427,46,43,func():_select_hair_color(1))

\t_label(ui,"Eye color",612,478,250,31,20)
\t_button(ui,"<",605,511,46,43,func():_select_eye(-1))
\tpreview_eye=_label(ui,"",653,516,192,33,19,Color("ffffff"),true)
\t_button(ui,">",844,511,46,43,func():_select_eye(1))
\t_label(ui,"Any class can equip any gear.",913,487,280,58,17,Color("b9ced3"),true)
\tcreator_error=_label(ui,"",614,558,568,32,17,Color("ff9b85"),true)
\t_button(ui,"BACK",603,596,235,58,_show_title)
\t_button(ui,"BEGIN ADVENTURE",852,596,334,58,_create_character)
\t_update_preview()

func _reset_creator_error() -> void:
\tif creator_error != null and is_instance_valid(creator_error):
\t\tcreator_error.text=""

func _select_class(delta:int)->void:
\tclass_index=posmod(class_index+delta,CLASSES.size())
\t_update_preview()

func _select_body(delta:int)->void:
\tbody_index=posmod(body_index+delta,8)
\t_update_preview()

func _select_hair(delta:int)->void:
\thair_index=posmod(hair_index+delta,HAIR.size())
\t_update_preview()

func _select_skin(delta:int)->void:
\tskin_index=posmod(skin_index+delta,SKIN_TONES.size())
\t_update_preview()

func _select_hair_color(delta:int)->void:
\thair_color_index=posmod(hair_color_index+delta,HAIR_COLORS.size())
\t_update_preview()

func _select_eye(delta:int)->void:
\teye_index=posmod(eye_index+delta,EYE_COLORS.size())
\t_update_preview()

func _rotate_preview(delta:int)->void:
\tpreview_direction_index=posmod(preview_direction_index+delta,CREATOR_DIRECTIONS.size())
\t_update_preview()

func _sprite_path(group:String, variant:String, direction:String, frame:int)->String:
\treturn "res://assets/%s/%s/%s_%02d.png" % [group,variant,direction,frame]

func _skin_material(skin:int, eye:int) -> ShaderMaterial:
\t# Recolors warm skin-tone pixels while retaining base sprite shading/gear.
\t# Eye palettes are saved independently; final per-pixel eye masks require dedicated art.
\tvar mat=ShaderMaterial.new()
\tvar shader=Shader.new()
\tshader.code="""shader_type canvas_item;
uniform vec4 chosen_skin : source_color = vec4(1.0);
uniform float strength = 0.0;
void fragment() {
    vec4 pix = texture(TEXTURE, UV);
    float warm = step(pix.b * 1.12, pix.r) * step(pix.g * 0.73, pix.r);
    float light = step(0.21, pix.r) * (1.0 - step(0.97, pix.r));
    float mask = warm * light * strength * pix.a;
    float value = dot(pix.rgb, vec3(0.299, 0.587, 0.114));
    vec3 painted = chosen_skin.rgb * (0.35 + 0.95 * value);
    COLOR = vec4(mix(pix.rgb, painted, mask), pix.a);
}"""
\tmat.shader=shader
\tmat.set_shader_parameter("chosen_skin",Color(SKIN_TONE_HEX[clampi(skin,0,SKIN_TONES.size()-1)]))
\tmat.set_shader_parameter("strength",0.0 if skin==0 else 0.88)
\treturn mat

func _hair_material(hair_color:int) -> ShaderMaterial:
\tvar mat=ShaderMaterial.new()
\tvar shader=Shader.new()
\tshader.code="""shader_type canvas_item;
uniform vec4 chosen_hair : source_color = vec4(1.0);
uniform float strength = 0.0;
void fragment() {
    vec4 pix = texture(TEXTURE, UV);
    float value = dot(pix.rgb, vec3(0.299, 0.587, 0.114));
    vec3 dyed = chosen_hair.rgb * (0.25 + 1.25 * value);
    COLOR = vec4(mix(pix.rgb, dyed, strength), pix.a);
}"""
\tmat.shader=shader
\tmat.set_shader_parameter("chosen_hair",Color(HAIR_COLOR_HEX[clampi(hair_color,0,HAIR_COLORS.size()-1)]))
\tmat.set_shader_parameter("strength",0.0 if hair_color==0 else 0.92)
\treturn mat

func _update_preview()->void:
\tvar direction=CREATOR_DIRECTIONS[preview_direction_index]
\tpreview_base.texture=load(_sprite_path("characters","base_variant_%02d" % (body_index+1),direction,0))
\tpreview_hair.texture=load(_sprite_path("hair",HAIR[hair_index],direction,0))
\tpreview_base.material=_skin_material(skin_index,eye_index)
\tpreview_hair.material=_hair_material(hair_color_index)
\tpreview_class.text=CLASSES[class_index]
\tpreview_class_guide.text=CLASS_GUIDES[class_index]
\tpreview_body.text="%d / 8" % (body_index+1)
\tpreview_hairstyle.text=HAIR[hair_index].replace("_"," ").capitalize()
\tpreview_skin.text=SKIN_TONES[skin_index]
\tpreview_skin.add_theme_color_override("font_color",Color(SKIN_TONE_HEX[skin_index]))
\tpreview_hair_color.text=HAIR_COLORS[hair_color_index]
\tpreview_hair_color.add_theme_color_override("font_color",Color(HAIR_COLOR_HEX[hair_color_index]))
\tpreview_eye.text=EYE_COLORS[eye_index]
\tpreview_eye.add_theme_color_override("font_color",Color(EYE_COLOR_HEX[eye_index]))
\tpreview_facing.text=direction.capitalize()

func _valid_creator_name(name:String) -> bool:
\tif name.length()<2 or name.length()>20:
\t\treturn false
\tfor forbidden in ["\\n","\\r","\\t","/","\\\\",":","<",">","{","}","[","]"]:
\t\tif name.contains(forbidden):return false
\treturn true

func _create_character()->void:
\tvar char_name=char_input.text.strip_edges()
\tif not _valid_creator_name(char_name):
\t\tcreator_error.text="Name must be 2-20 characters; no special control characters."
\t\treturn
\tdata["name"]=char_name
\tdata["class"]=CLASSES[class_index]
\tdata["body"]=body_index
\tdata["hair"]=hair_index
\tdata["skin_tone"]=skin_index
\tdata["eye_color"]=eye_index
\tdata["hair_color"]=hair_color_index
\t_save()
\t_enter_world("town",Vector2(1030,980))

''' + s[end:]

# Skin/hair dye must remain consistent after map changes, loading and player animation.
# Decorate existing gameplay Sprite2D instances when they are created, without
# changing the player's original textures or the NPC and title animations.
for variable, method, key in (
    ("base_sprite", "_skin_material", 'int(data.get("skin_tone",0)),int(data.get("eye_color",0))'),
    ("hair_sprite", "_hair_material", 'int(data.get("hair_color",0))'),
):
    pattern = re.compile(r'^(?P<indent>[\t ]*)' + variable + r'\s*=\s*Sprite2D\.new\(\)\s*$', re.MULTILINE)
    def decorate(match):
        indent = match.group("indent")
        return match.group(0).rstrip() + "\n" + indent + variable + ".material=" + method + "(" + key + ")"
    s, count = pattern.subn(decorate, s)
    if count == 0:
        print("WARNING: player sprite initialization not found for " + variable)

# Keep old save files and the approved title screen unchanged.
assert 'func _show_title() -> void:' in s
assert '_title_button("NEW ADVENTURE"' in s
assert 'func _create_character()->void:' in s
game_path.write_text(s, encoding="utf-8")
print("CREATOR PATCH OK: descriptions, 4-way preview, palette choices, validation, save/load.")
