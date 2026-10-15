#!/usr/bin/env python3
"""Align indoor gameplay collision and resident positions to the approved paintings.

The current four interior images are flat backgrounds; actual counter and
furniture collisions must be explicit so the player can't walk through them.
Runs after apply_npc_presence.py.
"""
from pathlib import Path

path=Path("scripts/game.gd")
s=path.read_text(encoding="utf-8")
def rep(a,b):
    global s
    count=s.count(a)
    if count!=1:raise SystemExit(f"INTERIOR COLLISION ANCHOR FAILED ({count}): {a[:100]!r}")
    s=s.replace(a,b,1)

rep('''\tif BUILDING_ART.has(current_map):
\t\treturn where.x>=320 and where.x<=1728 and where.y>=310 and where.y<=1140''',
'''\tif BUILDING_ART.has(current_map):
\t\treturn _inside_building_walkable(where)''')

rep('''    "Ilyan Crest":Vector2(1010,560),
    "Captain Elara Voss":Vector2(1410,670),
    "Mara Fenwick":Vector2(1050,595),
    "Tamsin Reed":Vector2(1380,540),
    "Brann Ironhand":Vector2(1220,590)''',
'''    "Ilyan Crest":Vector2(1000,785),
    "Captain Elara Voss":Vector2(1500,795),
    "Mara Fenwick":Vector2(1040,715),
    "Tamsin Reed":Vector2(1170,845),
    "Brann Ironhand":Vector2(1080,825)''')

s+='''
# Painted counters are part of the texture; give them gameplay collision.
# These are first-pass generous rectangles, safe enough for touch controls.
const INTERIOR_OBSTACLES = {
\t"guild":[Rect2(610,589,760,142),Rect2(290,590,260,160),Rect2(1510,550,240,140)],
\t"market":[Rect2(545,365,900,250),Rect2(285,400,245,540),Rect2(1580,445,215,365)],
\t"inn":[Rect2(1250,465,560,305),Rect2(630,380,470,185),Rect2(240,690,575,160)],
\t"blacksmith":[Rect2(1115,390,425,290),Rect2(1320,710,270,210),Rect2(290,460,305,315)]
}

func _inside_building_walkable(at:Vector2)->bool:
\tif not BUILDING_ART.has(current_map):return false
\tif at.x<320 or at.x>1728 or at.y<310 or at.y>1140:return false
\tfor obstacle:Rect2 in INTERIOR_OBSTACLES.get(current_map,[]):
\t\tif obstacle.has_point(at):return false
\treturn true
'''
path.write_text(s,encoding="utf-8")
print("INTERIOR COLLISION PATCH OK: visible furniture obstruction and reachable staff.")
