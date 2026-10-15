#!/usr/bin/env python3
"""Apply the Adventure Odyssey v0.3 compact title layout after extracting its ZIP."""
from pathlib import Path

path = Path("scripts/game.gd")
source = path.read_text(encoding="utf-8")
begin = "func _show_title() -> void:"
end = "func _start_title_chase() -> void:"
if source.count(begin) != 1 or source.count(end) != 1:
    raise SystemExit("Title scene patch aborted: unsupported scripts/game.gd structure.")
assert "goblin_rogue_walk" in source and "skeleton_warrior_walk" in source
assert "func _play_guest()" in source and "func _open_creator()" in source
assert "func _continue()" in source and "func _show_settings()" in source

new_title = '''func _show_title() -> void:
\t_clear_world()
\t_clear_ui()
\t# The background and both animated actors are separate layers.
\t_picture(ui,"res://assets/world/title.png",Vector2.ZERO,Vector2(1280,720))
\t_start_title_chase()

\t# Open composition: no large sign-in panel obscuring the illustration.
\t# This typography can be replaced with final title art without changing buttons.
\tvar top_title=_label(ui,"ADVENTURE",226,26,826,82,62,Color("f7dfa0"),true)
\ttop_title.add_theme_color_override("font_outline_color",Color("28202b"))
\ttop_title.add_theme_constant_override("outline_size",5)
\tvar bottom_title=_label(ui,"ODYSSEY",225,98,830,90,74,Color("fff1cf"),true)
\tbottom_title.add_theme_color_override("font_outline_color",Color("261c26"))
\tbottom_title.add_theme_constant_override("outline_size",6)

\t# Individually interactive buttons in a single horizontal row under the title.
\t_title_button("PLAY AS GUEST",170,217,225,59,_play_guest)
\t_title_button("NEW ADVENTURE",408,217,225,59,_open_creator)
\tvar continue_button=_title_button("CONTINUE",646,217,225,59,_continue)
\tcontinue_button.disabled=not _has_save()
\t_title_button("SETTINGS",884,217,225,59,_show_settings)
\tvar tagline=_label(ui,"YOUR STORY BEGINS IN ELMWATCH",350,298,580,35,18,Color("f3e4c7"),true)
\ttagline.add_theme_color_override("font_outline_color",Color("202530"))
\ttagline.add_theme_constant_override("outline_size",3)

\t# Keep secondary functionality discreet, away from the chase lane at y=629.
\tvar credits=_title_button("CREDITS",1115,32,132,44,_show_credits)
\tcredits.add_theme_font_size_override("font_size",16)
\tvar exit_button=_title_button("EXIT",1133,83,114,43,_quit_game)
\texit_button.add_theme_font_size_override("font_size",16)
\tvar studio=_label(ui,"DABSKY",28,676,186,30,17,Color("efd5a1"),false)
\tstudio.add_theme_color_override("font_outline_color",Color("1a1d27"))
\tstudio.add_theme_constant_override("outline_size",3)

func _title_button(text_value:String, x:float, y:float, w:float, h:float, cb:Callable) -> Button:
\tvar b=Button.new()
\tb.text=text_value
\tb.position=Vector2(x,y)
\tb.size=Vector2(w,h)
\tb.focus_mode=Control.FOCUS_ALL
\tb.add_theme_font_size_override("font_size",19)
\tb.add_theme_color_override("font_color",Color("ffe7b2"))
\tb.add_theme_color_override("font_hover_color",Color("fff9e7"))
\tb.add_theme_color_override("font_pressed_color",Color("ffdd93"))
\tb.add_theme_color_override("font_disabled_color",Color("b0ab9b"))
\tvar normal=StyleBoxFlat.new()
\tnormal.bg_color=Color(0.02,0.05,0.10,0.12)
\tnormal.border_color=Color(0.93,0.78,0.49,0.78)
\tnormal.set_border_width_all(2)
\tnormal.set_corner_radius_all(10)
\tb.add_theme_stylebox_override("normal",normal)
\tvar hover=normal.duplicate() as StyleBoxFlat
\thover.bg_color=Color(0.09,0.15,0.25,0.62)
\thover.border_color=Color("ffe3a1")
\tb.add_theme_stylebox_override("hover",hover)
\tvar pressed=normal.duplicate() as StyleBoxFlat
\tpressed.bg_color=Color(0.10,0.12,0.20,0.78)
\tb.add_theme_stylebox_override("pressed",pressed)
\tvar disabled=normal.duplicate() as StyleBoxFlat
\tdisabled.bg_color=Color(0.03,0.05,0.08,0.19)
\tdisabled.border_color=Color(0.48,0.47,0.42,0.55)
\tb.add_theme_stylebox_override("disabled",disabled)
\tb.add_theme_stylebox_override("focus",hover)
\tui.add_child(b)
\tb.pressed.connect(cb)
\treturn b

'''
patched = source[:source.index(begin)] + new_title + source[source.index(end):]
assert "func _advance_title_chase(delta:float)" in patched
assert "_sprite_path(\"monsters\",\"goblin_rogue_walk\"" in patched
assert "_sprite_path(\"monsters\",\"skeleton_warrior_walk\"" in patched
assert "func _show_creator()" in patched
path.write_text(patched, encoding="utf-8")
print("TITLE PATCH OK: compact row; all six actions kept; existing chase code unchanged.")
