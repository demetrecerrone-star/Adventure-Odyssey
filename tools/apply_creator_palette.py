#!/usr/bin/env python3
"""Add independently saved skin and eye palettes to the verified creator patch.

The existing sprites have no independent eye/skin masks. Skin shading is
palette-based and provisional; eye choice is stored and swatched until there
are pixel masks for a faithful avatar iris recolor.
"""
from pathlib import Path

game = Path("scripts/game.gd")
tests = Path("tests/smoke_test.gd")
src = game.read_text(encoding="utf-8")
def rep(old,new):
    global src
    if src.count(old) != 1:
        raise SystemExit("Palette upgrade could not find unique anchor: "+old[:95])
    src=src.replace(old,new,1)

rep("const NPCS = [", '''const SKIN_NAMES = ["Original", "Fair", "Light", "Medium", "Tan", "Deep", "Dark"]
const SKIN_HEX = ["ffffff","f8d8bc","e7b997","c58d69","a87551","81523a","57382e"]
const EYE_NAMES = ["Brown", "Hazel", "Blue", "Green", "Gray", "Violet", "Amber"]
const EYE_HEX = ["68452e","997b48","548ac2","5e9f6e","8295a1","9b72bb","bb9148"]
const NPCS = [''')
rep('var hair_tint_index := 0', '''var skin_index := 0
var eye_index := 0
var preview_skin: Label
var preview_eye: Label
var hair_tint_index := 0''')
rep('"hair_tint":0, "level":1', '"hair_tint":0, "skin_tone":0, "eye_color":0, "level":1')
rep('''\tparsed["hair_tint"] = clampi(int(parsed.get("hair_tint", 0)), 0, HAIR_TINTS.size()-1)
\tdata = parsed''', '''\tparsed["hair_tint"] = clampi(int(parsed.get("hair_tint", 0)), 0, HAIR_TINTS.size()-1)
\tparsed["skin_tone"] = clampi(int(parsed.get("skin_tone",0)),0,SKIN_NAMES.size()-1)
\tparsed["eye_color"] = clampi(int(parsed.get("eye_color",0)),0,EYE_NAMES.size()-1)
\tdata = parsed''')
rep('''\thair_tint_index=0
\tpreview_direction_index=0
\t_show_creator()''','''\thair_tint_index=0
\tskin_index=0
\teye_index=0
\tpreview_direction_index=0
\t_show_creator()''')
rep('''\t_label(ui,"Class abilities are unique; equipment is unrestricted.",607,506,597,33,17,Color("b9ced3"),true)
\tcreator_error=_label(ui,"",602,535,600,34,17,Color("ffaba5"),true)
\t_button(ui,"BACK",600,574,210,60,_show_title)
\t_button(ui,"BEGIN ADVENTURE",834,574,369,60,_confirm_character)''','''\t_label(ui,"Skin tone",617,501,260,30,17)
\t_label(ui,"Eye color",906,501,260,30,17)
\t_button(ui,"<",604,531,45,37,func():_select_skin(-1))
\tpreview_skin=_label(ui,"",650,532,195,35,17,Color("f4e5bf"),true)
\t_button(ui,">",843,531,45,37,func():_select_skin(1))
\t_button(ui,"<",905,531,45,37,func():_select_eye(-1))
\tpreview_eye=_label(ui,"",950,532,186,35,17,Color("f4e5bf"),true)
\t_button(ui,">",1137,531,45,37,func():_select_eye(1))
\tcreator_error=_label(ui,"",603,573,591,23,15,Color("ffaba5"),true)
\t_button(ui,"BACK",600,601,210,52,_show_title)
\t_button(ui,"BEGIN ADVENTURE",834,601,369,52,_confirm_character)''')
rep('func _valid_character_name(candidate:String)->bool:', '''func _select_skin(delta:int)->void:
\tskin_index=posmod(skin_index+delta,SKIN_NAMES.size())
\t_update_preview()

func _select_eye(delta:int)->void:
\teye_index=posmod(eye_index+delta,EYE_NAMES.size())
\t_update_preview()

func _skin_palette_material(value:int)->ShaderMaterial:
\tvar material=ShaderMaterial.new()
\tvar shader=Shader.new()
\tshader.code="""shader_type canvas_item;
uniform vec4 skin : source_color = vec4(1.0);
uniform float strength = 0.0;
void fragment() {
    vec4 original = texture(TEXTURE,UV);
    float flesh = step(original.b*1.12, original.r) * step(original.g*0.72,original.r);
    flesh *= step(0.2,original.r)*(1.0-step(0.98,original.r))*original.a;
    float light = dot(original.rgb,vec3(0.299,0.587,0.114));
    vec3 shaded = skin.rgb * (0.36+0.9*light);
    COLOR=vec4(mix(original.rgb,shaded,flesh*strength),original.a);
}"""
\tmaterial.shader=shader
\tmaterial.set_shader_parameter("skin",Color(SKIN_HEX[value]))
\tmaterial.set_shader_parameter("strength",0.0 if value==0 else 0.88)
\treturn material

func _valid_character_name(candidate:String)->bool:''')
rep('''\tpreview_hair.modulate=HAIR_TINTS[hair_tint_index]
\tpreview_class.text''','''\tpreview_hair.modulate=HAIR_TINTS[hair_tint_index]
\tpreview_base.material=_skin_palette_material(skin_index)
\tpreview_skin.text=SKIN_NAMES[skin_index]
\tpreview_skin.add_theme_color_override("font_color",Color(SKIN_HEX[skin_index]))
\tpreview_eye.text=EYE_NAMES[eye_index]
\tpreview_eye.add_theme_color_override("font_color",Color(EYE_HEX[eye_index]))
\tpreview_class.text''')
rep('''\tdata["hair_tint"]=hair_tint_index
\tif not _save():''','''\tdata["hair_tint"]=hair_tint_index
\tdata["skin_tone"]=skin_index
\tdata["eye_color"]=eye_index
\tif not _save():''')
rep('''\t_label(creator_confirm_layer,"Hair tint: %s" % HAIR_TINT_NAMES[hair_tint_index],610,357,590,32,19,Color("d8e5df"),true)''', '''\t_label(creator_confirm_layer,"Hair tint: %s" % HAIR_TINT_NAMES[hair_tint_index],610,352,590,32,19,Color("d8e5df"),true)
\t_label(creator_confirm_layer,"Skin: %s    Eyes: %s" % [SKIN_NAMES[skin_index],EYE_NAMES[eye_index]],610,388,590,32,19,Color("d8e5df"),true)''')
rep('''\tbase_sprite=player_actor["sprite"]
\thair_sprite=Sprite2D.new()''','''\tbase_sprite=player_actor["sprite"]
\tbase_sprite.material=_skin_palette_material(clampi(int(data.get("skin_tone",0)),0,SKIN_NAMES.size()-1))
\thair_sprite=Sprite2D.new()''')
game.write_text(src,encoding="utf-8")

smoke=tests.read_text(encoding="utf-8")
anchor='''\tscene._select_hair_tint(3)
\tscene._rotate_preview(1)'''
if smoke.count(anchor) != 1:
    raise SystemExit("Palette regression anchor not found")
smoke=smoke.replace(anchor, '''\tscene._select_hair_tint(3)
\tscene._select_skin(2)
\tscene._select_eye(4)
\tif not _check(scene.preview_skin.text=="Light" and scene.preview_eye.text=="Gray" and scene.preview_base.material!=null,"Independent skin and eye choices"):
\t\treturn
\tscene._rotate_preview(1)''',1)
anchor='''\tif not _check(scene._load_save() and int(scene.data["hair_tint"]) == 3 and scene.data["name"] == "Valid Tester", "Creator selections persist after reload"):
\t\treturn'''
if smoke.count(anchor)!=1:
    raise SystemExit("Palette save regression anchor not found")
smoke=smoke.replace(anchor, anchor+'''
\tif not _check(int(scene.data["skin_tone"])==2 and int(scene.data["eye_color"])==4, "Skin and eye selections persist after reload"):
\t\treturn''',1)
tests.write_text(smoke,encoding="utf-8")
print("PALETTE PATCH OK: independent skin/eye selection, live skin shading, swatches and save persistence.")
