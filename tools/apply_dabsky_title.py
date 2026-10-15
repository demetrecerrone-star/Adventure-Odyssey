#!/usr/bin/env python3
"""Apply the user's purple-and-silver 'by Dabsky' brand image to Adventure Odyssey."""
from pathlib import Path

source = Path("scripts/game.gd")
asset = Path("assets/ui/dabsky_logo.webp")
assert source.is_file(), "First reconstruct Godot and apply tools/apply_title_screen.py"
assert asset.is_file(), "Missing approved Dabsky transparent logo"
s = source.read_text(encoding="utf-8")
old = '''\tvar credits=_title_button("CREDITS",1115,32,132,44,_show_credits)
\tcredits.add_theme_font_size_override("font_size",16)
\tvar exit_button=_title_button("EXIT",1133,83,114,43,_quit_game)
\texit_button.add_theme_font_size_override("font_size",16)
\tvar studio=_label(ui,"DABSKY",28,676,186,30,17,Color("efd5a1"),false)
\tstudio.add_theme_color_override("font_outline_color",Color("1a1d27"))
\tstudio.add_theme_constant_override("outline_size",3)
'''
new = '''\t# User's original purple/silver by Dabsky artwork, in a small transparent upper-right layer.
\tvar dabsky_logo=TextureRect.new()
\tdabsky_logo.texture=load("res://assets/ui/dabsky_logo.webp")
\tdabsky_logo.position=Vector2(1050,18)
\tdabsky_logo.size=Vector2(198,66)
\tdabsky_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
\tdabsky_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\tdabsky_logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tui.add_child(dabsky_logo)
\t# Maintain visible Credits and Exit actions, clear of the logo and sprite lane.
\tvar credits=_title_button("CREDITS",518,473,116,38,_show_credits)
\tcredits.add_theme_font_size_override("font_size",16)
\tvar exit_button=_title_button("EXIT",650,473,114,38,_quit_game)
\texit_button.add_theme_font_size_override("font_size",16)
'''
if s.count(old) != 1:
    raise SystemExit("Unexpected title screen layout; Dabsky logo patch not applied.")
updated = s.replace(old,new,1)
for name in ('_start_title_chase()', 'goblin_rogue_walk', 'skeleton_warrior_walk', '_title_button("PLAY AS GUEST"'):
    assert name in updated, f"Missing preserved feature: {name}"
source.write_text(updated,encoding="utf-8")
print("BY DABSKY LOGO OK: transparent upper-right, controls and chase preserved")
