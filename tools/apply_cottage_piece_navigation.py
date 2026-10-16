#!/usr/bin/env python3
"""Expose optional individual furniture styles in the existing cottage collection UI.

Must run immediately after apply_cottage_collections.py. The existing complete
Queen/King/Unisex tier purchases remain identical.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
def rep(old,new):
    global s
    if s.count(old)!=1:
        raise SystemExit("COTTAGE PIECE NAV ANCHOR FAILED (%d): %r"%(s.count(old),old[:100]))
    s=s.replace(old,new,1)

rep(
    '\t_button(popup,"CLOSE",979,616,199,48,_dismiss_message)',
    '\t_button(popup,"INDIVIDUAL PIECES",686,616,274,48,_open_cottage_piece_boutique)\n\t_button(popup,"CLOSE",979,616,199,48,_dismiss_message)'
)
rep(
    '\tif not COTTAGE_COLLECTION_TIERS.has(active) or not data["cottage_tiers_owned"].has(active):\n\t\tactive="starter"',
    '\tif active!="custom" and (not COTTAGE_COLLECTION_TIERS.has(active) or not data["cottage_tiers_owned"].has(active)):\n\t\tactive="starter"'
)
p.write_text(s,encoding="utf8")
print("AO COTTAGE NAVIGATION PASS: original three premium collection tiers and individual-piece boutique available together.")
