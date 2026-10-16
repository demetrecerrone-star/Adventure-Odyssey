#!/usr/bin/env python3
"""Add coordinate-aligned, non-destructive hood/hairstyle masks to the Godot player.

Run after apply_equipment_visuals.py. This operates on the *source* hair texture
and the generated worn hood alpha (not on previously clipped hair). When headgear
is removed the original hair texture, tint and original transform return.
"""
from pathlib import Path

path=Path("scripts/game.gd")
source=path.read_text(encoding="utf8")

def replace_once(old,new):
    global source
    count=source.count(old)
    if count!=1:
        raise SystemExit(f"HEADGEAR HAIR MASK ANCHOR FAILED ({count}): {old[:110]!r}")
    source=source.replace(old,new,1)

replace_once(
    "var worn_equipment_sprites: Dictionary={}",
    "var worn_equipment_sprites: Dictionary={}\nvar headgear_hair_texture_cache: Dictionary={}"
)
replace_once(
    "\thair_sprite.modulate=HAIR_TINTS[clampi(int(data.get(\"hair_tint\",0)),0,HAIR_TINTS.size()-1)]",
    "\thair_sprite.modulate=HAIR_TINTS[clampi(int(data.get(\"hair_tint\",0)),0,HAIR_TINTS.size()-1)]\n\t_apply_headgear_hair_mask()"
)
replace_once(
    '\t\thair_sprite.visible=not (worn_equipment_sprites.has("head") and worn_equipment_sprites["head"].visible and facing=="up")',
    '\t\t_apply_headgear_hair_mask()'
)
source += '''
# -- Source-preserving headgear occlusion ------------------------------------
# Hair is stored at a different PNG size and Sprite2D transform than the body.
# Convert each original hair texel into the hood's body-frame coordinates,
# then allow only exposed bangs/face tufts; never allow hair through hood fabric.
# The original hairstyle/color data and save format are never modified.
func _masked_hair_for_hood(hair_texture:Texture2D,hood_texture:Texture2D,direction:String)->Texture2D:
    var original:Image=hair_texture.get_image()
    var hood:Image=hood_texture.get_image()
    if original==null or hood==null or original.is_empty() or hood.is_empty():
        return null
    var clipped:Image=original.duplicate()
    var hair_width:int=original.get_width()
    var hair_height:int=original.get_height()
    var hood_width:int=hood.get_width()
    var hood_height:int=hood.get_height()
    var middle:float=float(hood_width)*0.5
    var local_offset:Vector2=hair_sprite.position-base_sprite.position
    for py in range(hair_height):
        var body_y:float=(float(py)+0.5-float(hair_height)*0.5)*hair_sprite.scale.y+local_offset.y+float(hood_height)*0.5
        for px in range(hair_width):
            var color:Color=original.get_pixel(px,py)
            if color.a<=0.001:
                continue
            var body_x:float=(float(px)+0.5-float(hair_width)*0.5)*hair_sprite.scale.x+local_offset.x+middle
            var visible_area:bool=false
            if direction=="down":
                # Fringe inside the open face, plus narrow face-framing strands.
                var edge:float=12.0 if body_y<37.0 else 9.0
                visible_area=body_y>=19.0 and body_y<=48.0 and absf(body_x-middle)<=edge
            elif direction=="left":
                visible_area=body_y>=25.0 and body_y<=49.0 and body_x>=middle-17.0 and body_x<=middle+7.0
            elif direction=="right":
                visible_area=body_y>=25.0 and body_y<=49.0 and body_x>=middle-7.0 and body_x<=middle+17.0
            # Back-facing hair is fully concealed; outside the face opening
            # there is no visible hair. Fabric alpha also wins inside it.
            var ix:int=int(floor(body_x))
            var iy:int=int(floor(body_y))
            if ix<0 or ix>=hood_width or iy<0 or iy>=hood_height:
                visible_area=false
            elif hood.get_pixel(ix,iy).a>0.10:
                visible_area=false
            if not visible_area:
                clipped.set_pixel(px,py,Color.TRANSPARENT)
    return ImageTexture.create_from_image(clipped)

func _apply_headgear_hair_mask()->void:
    if hair_sprite==null or not is_instance_valid(hair_sprite):
        return
    var hair_index:int=clampi(int(data.get("hair",0)),0,HAIR.size()-1)
    var original_path:String=_sprite_path("hair",HAIR[hair_index],facing,anim_frame)
    var source_texture:Texture2D=load(original_path)
    if source_texture==null:
        hair_sprite.texture=null
        hair_sprite.visible=false
        return
    # Always reload the untouched original first: equip/unequip never stacks
    # clipping on an earlier frame or contaminates another hairstyle.
    hair_sprite.texture=source_texture
    hair_sprite.visible=true
    if not worn_equipment_sprites.has("head"):
        return
    var head_sprite:Sprite2D=worn_equipment_sprites["head"]
    if head_sprite==null or not is_instance_valid(head_sprite) or not head_sprite.visible or head_sprite.texture==null:
        return
    # Conservative fallback for future opaque helmets until they have an
    # explicitly approved opening mask. Hood is the first supported design.
    if facing=="up" or _equipped("head")!="Leather Hood":
        hair_sprite.visible=false
        return
    var key:String="%d/%s/%s/%d/%s" % [int(data.get("body",0)),HAIR[hair_index],facing,anim_frame,_equipped("head")]
    if not headgear_hair_texture_cache.has(key):
        # The current player only needs a small cache of its recent poses.
        if headgear_hair_texture_cache.size()>=160:
            headgear_hair_texture_cache.clear()
        var masked:Texture2D=_masked_hair_for_hood(source_texture,head_sprite.texture,facing)
        if masked!=null:
            headgear_hair_texture_cache[key]=masked
    if headgear_hair_texture_cache.has(key):
        hair_sprite.texture=headgear_hair_texture_cache[key]
    else:
        # Never fall back to hair sticking through opaque hood fabric.
        hair_sprite.visible=false
'''
path.write_text(source,encoding="utf8")
print("AO HEADGEAR HAIR MASK: PASS / source-aligned, reversible, four directions")
