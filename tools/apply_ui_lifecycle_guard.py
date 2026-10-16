#!/usr/bin/env python3
"""Avoid use-after-free of gameplay HUD prompt during scene/screenshot changes.

Runs after other game.gd overlays. Godot queue_free() can invalidate the old
prompt while the scene's actor is still alive in the current frame.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
old='\tvar nearby = _nearest_npc()\n\tif current_map=="bedroom":'
new='\t# The HUD can be freed during scene swaps before the actor disappears.\n\tif prompt==null or not is_instance_valid(prompt):return\n\tvar nearby = _nearest_npc()\n\tif current_map=="bedroom":'
if s.count(old)!=1:
    raise SystemExit("HUD PROMPT GUARD ANCHOR FAILED: "+str(s.count(old)))
p.write_text(s.replace(old,new,1),encoding="utf8")
print("AO HUD PROMPT LIFECYCLE GUARD: PASS")
