#!/usr/bin/env python3
"""Polish the rendered two-panel character creator after applying palette patch."""
from pathlib import Path

path=Path("scripts/game.gd")
s=path.read_text(encoding="utf-8")

def rep(old:str,new:str)->None:
    global s
    if s.count(old)!=1:
        raise SystemExit("Creator polish aborted; anchor mismatch: "+old[:100])
    s=s.replace(old,new,1)

rep('var preview_eye: Label', '''var preview_eye: Label
var preview_eye_swatch: ColorRect
var preview_skin_swatch: ColorRect''')
rep('''\t_label(ui,"CREATE YOUR ADVENTURER",49,50,1160,54,38,Color("f0cd85"),true)''',
'''\t_label(ui,"CHARACTER PREVIEW",69,53,470,53,28,Color("f0cd85"),true)
\t_label(ui,"CREATE YOUR ADVENTURER",591,53,630,53,30,Color("f0cd85"),true)''')
rep('''\tpreview_actor.position=Vector2(300,625)''','''\t# Leave room below the feet for the camera-direction controls.
\tpreview_actor.position=Vector2(300,560)''')
rep('''\t_label(ui,"Base appearance / skin tone",619,281,450,31,20)''',
'''\t_label(ui,"Base appearance",619,281,450,31,20)''')
rep('''\tpreview_eye=_label(ui,"",950,532,186,35,17,Color("f4e5bf"),true)''',
'''\tpreview_eye=_label(ui,"",950,532,186,35,17,Color("f4e5bf"),true)
\t# Color samples are separate from text so even dark shades remain readable.
\tpreview_skin_swatch=ColorRect.new()
\tpreview_skin_swatch.position=Vector2(669,540)
\tpreview_skin_swatch.size=Vector2(18,18)
\tpreview_skin_swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tui.add_child(preview_skin_swatch)
\tpreview_eye_swatch=ColorRect.new()
\tpreview_eye_swatch.position=Vector2(972,540)
\tpreview_eye_swatch.size=Vector2(18,18)
\tpreview_eye_swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tui.add_child(preview_eye_swatch)''')
rep('''\tpreview_skin.add_theme_color_override("font_color",Color(SKIN_HEX[skin_index]))
\tpreview_eye.text=EYE_NAMES[eye_index]
\tpreview_eye.add_theme_color_override("font_color",Color(EYE_HEX[eye_index]))''',
'''\tpreview_skin.add_theme_color_override("font_color",Color("f4e5bf"))
\tpreview_skin_swatch.color=Color(SKIN_HEX[skin_index])
\tpreview_eye.text=EYE_NAMES[eye_index]
\tpreview_eye.add_theme_color_override("font_color",Color("f4e5bf"))
\tpreview_eye_swatch.color=Color(EYE_HEX[eye_index])''')
path.write_text(s,encoding="utf-8")
print("CREATOR VISUAL POLISH OK: readable color choices, framed headings and unobstructed feet.")
