#!/usr/bin/env python3
"""Apply after all existing source overlays, including save reliability."""
from pathlib import Path
p = Path('scripts/game.gd')
s = p.read_text()
if 'func _reset_gameplay_input()' in s:
    print('AO TOUCH INPUT OVERLAY: ALREADY APPLIED')
    raise SystemExit(0)
assert 'func _input(' not in s, 'Review existing input handler before applying'
old = '\t\t_save_active_character()\n\nfunc _combat_target_prompt'
assert s.count(old) == 1, 'Apply save reliability overlay first'
s = s.replace(old, '\t\t_reset_gameplay_input()\n\t\t_save_active_character()\n\nfunc _combat_target_prompt', 1)
s = s.replace('func _clear_ui() -> void:\n', 'func _clear_ui() -> void:\n\t_reset_gameplay_input()\n', 1)
s += '\n' + Path('tools/input_routing.gd.txt').read_text()
p.write_text(s)
p = Path('scripts/joystick.gd')
s = p.read_text()
s = s.replace('func _release() -> void:\n', 'func reset_input() -> void:\n\tfinger=-1\n\tmouse_held=false\n\t_release()\n\nfunc _release() -> void:\n', 1)
s = s.replace('func _gui_input(event: InputEvent) -> void:\n', 'func _gui_input(event: InputEvent) -> void:\n\tif event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:return\n', 1)
s = s.replace('if event.pressed and finger < 0:', 'if event.pressed and not event.canceled and finger < 0:')
s = s.replace('elif not event.pressed and event.index==finger:', 'elif (not event.pressed or event.canceled) and event.index==finger:')
p.write_text(s)
print('AO TOUCH INPUT OVERLAY: PASS')
