#!/usr/bin/env python3
"""Use matching, wearable-art-derived icons for equipped items in item UI.

The 39 approved original icon SVG files are never deleted or altered. Equipable
items prefer the new 96px matched preview, with original SVG fallback. Materials
continue to use their existing original icons.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
old='var path:String="res://assets/items/%s.svg" % item.to_lower().replace("\'","").replace(" ","_")'
new='''var slug:String=item.to_lower().replace("'","").replace(" ","_")
\tvar matched:String="res://assets/equipment_item_icons/%s.png" % slug
\tvar path:String=matched if ResourceLoader.exists(matched) else "res://assets/items/%s.svg" % slug'''
if s.count(old)!=1:
    raise SystemExit(f"MATCHED ICON PATCH ANCHOR FAILED ({s.count(old)}): {old}")
s=s.replace(old,new,1)
p.write_text(s,encoding="utf8")
print("AO MATCHED EQUIPMENT ICONS: PASS / retained original source icons, wearable-item fallback resolver")
