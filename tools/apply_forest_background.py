#!/usr/bin/env python3
"""Place the approved, illustrated Thornbrook map into the reconstructed game.

After the Guild training patch: replace only the forest texture reference and
keep the existing hero, movement, monsters, NPCs, rewards and homes intact.
The archived v0.3 base project remains unmodified.
"""
from pathlib import Path

game=Path("scripts/game.gd")
src=game.read_text(encoding="utf-8")

def rep(before:str,after:str)->None:
    global src
    n=src.count(before)
    if n!=1:
        raise SystemExit(f"FOREST BACKGROUND PATCH ANCHOR FAILED ({n}): {before[:110]!r}")
    src=src.replace(before,after,1)

rep('''var art_path = ELMWATCH_TOWN_ART if map_name=="town" else str(BUILDING_ART.get(map_name,"res://assets/world/thornbrook_forest.png"))''',
    '''var art_path = ELMWATCH_TOWN_ART if map_name=="town" else str(BUILDING_ART.get(map_name,"res://assets/world/thornbrook_forest_approved.jpg"))''')

# Four familiar slime opponents, distributed in the open grassy clearings
# rather than overlapping the center log or a rocky border.
rep('''var placements=[Vector2(590,490),Vector2(1040,675),Vector2(1460,520),Vector2(1810,805)]''',
    '''var placements=[Vector2(590,490),Vector2(1030,775),Vector2(1460,520),Vector2(1700,670)]''')

rep('''func _walkable(where:Vector2)->bool:
\tif BUILDING_ART.has(current_map):''',
'''func _walkable(where:Vector2)->bool:
\tif current_map=="forest":
\t\t# The approved 1586 x 992 painting is stretched to 2048 x 1280.
\t\t# The lower and upper tree walls are solid, while its broad central
\t\t# west-east dirt trail remains fully walkable.
\t\tif where.x<24 or where.x>2024 or where.y<170 or where.y>1115:
\t\t\treturn false
\t\t# Only the forest-trail gaps open through the west/east borders.
\t\tif where.x<128 and (where.y<510 or where.y>775):
\t\t\treturn false
\t\tif where.x>1910 and (where.y<535 or where.y>810):
\t\t\treturn false
\t\t# Trunks and large rock masses, not decorative grass or flowers.
\t\tfor obstacle in [Rect2(108,185,245,270),Rect2(825,155,355,345),Rect2(1170,795,270,225),Rect2(1800,190,224,260),Rect2(1820,920,204,190)]:
\t\t\tif obstacle.has_point(where):
\t\t\t\treturn false
\t\treturn true
\tif BUILDING_ART.has(current_map):''')
game.write_text(src,encoding="utf-8")
print("FOREST BACKGROUND PATCH OK: approved Thornbrook painting, walkable paths and four slime clearings.")
