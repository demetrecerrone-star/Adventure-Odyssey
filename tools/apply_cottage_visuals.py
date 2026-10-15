#!/usr/bin/env python3
"""Install the user-approved painted cottage foyer without altering tutorial logic.

Archive source is kept intact. Must run after the modular furniture and cottage
patches. The foyer image is intentionally its own scenery layer, not baked with
bed/chest/mirror; those remain separate and functional in the bedroom.
"""
from pathlib import Path

image=Path("assets/interiors/starter_cottage_foyer.jpg")
if not image.is_file() or image.stat().st_size<35000:
    raise SystemExit("APPROVED COTTAGE IMAGE MISSING: commit starter_cottage_foyer.jpg before enabling this patch")

scene=Path("scripts/cottage_scene.gd")
s=scene.read_text(encoding="utf-8")

if s.count("func _rect(")!=1 or s.count("func _draw()->void:")!=1:
    raise SystemExit("COTTAGE VISUAL PATCH ANCHOR FAILED")

insert='''const APPROVED_ART = "res://assets/interiors/starter_cottage_foyer.jpg"
var approved_background:Sprite2D

func _ready()->void:
    approved_background=Sprite2D.new()
    approved_background.name="ApprovedFoyerBackground"
    approved_background.texture=load(APPROVED_ART)
    if approved_background.texture==null:
        push_error("Missing approved cottage foyer texture")
        return
    approved_background.centered=false
    approved_background.position=Vector2.ZERO
    approved_background.scale=Vector2(2048.0/float(approved_background.texture.get_width()),1280.0/float(approved_background.texture.get_height()))
    approved_background.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    approved_background.z_index=-10
    add_child(approved_background)
    queue_redraw()

'''
s=s.replace("func _rect(",insert+"func _rect(",1)
# The approved room artwork replaces the previous colored-placeholder floor.
# The existing interactable tutorial hotspots are game state, not drawn fixtures.
s=s.replace("func _draw()->void:\n",'''func _draw()->void:
    if approved_background!=null and approved_background.texture!=null:
        return # The approved illustration is used instead of code-painted scenery.
''',1)
scene.write_text(s,encoding="utf-8")
print("COTTAGE VISUAL PATCH OK: approved illustrated starter foyer displayed.")

# Staging visual art in a separate layer must not change the existing
# cottage bedroom/chest/appearance/potion/door logic, only the painted floor.
