#!/usr/bin/env python3
"""Wire derived player base/starter clothing into optional in-engine visual QA.

Appearance preview is disabled by default until original visual designs are
approved. Equipment stats and save formats remain untouched.
"""
from pathlib import Path

path=Path("scripts/game.gd")
src=path.read_text(encoding="utf-8")

def once(old,new):
    global src
    n=src.count(old)
    if n!=1:
        raise SystemExit(f"AO APPEARANCE LAYER ANCHOR ERROR ({n}): {old[:100]!r}")
    src=src.replace(old,new,1)

once('var gear_shop_page:int=0', '''var use_layered_appearance:bool=false
var starter_appearance_sprites:Dictionary={}
var gear_shop_page:int=0''')

once('''\tplayer.add_child(hair_sprite)
\tcamera=Camera2D.new()''','''\tplayer.add_child(hair_sprite)
\t_init_player_appearance_layers()
\tcamera=Camera2D.new()''')

once('''\tbase_sprite.texture=load(_sprite_path("characters","base_variant_%02d" % (int(data["body"])+1),facing,anim_frame))
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''','''\tif use_layered_appearance:
\t\t_set_layered_appearance_frame()
\telse:
\t\tbase_sprite.texture=load(_sprite_path("characters","base_variant_%02d" % (int(data["body"])+1),facing,anim_frame))
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''')

src += '''
# -- AO layered character appearance prototype (opt-in; original safe) --
# Original 8 variants/12 hairstyles are not overwritten.
func _init_player_appearance_layers()->void:
\tstarter_appearance_sprites={}
\tif not use_layered_appearance or player==null:return
\t# Shirt, pants and shoes share the exact base PNG frame dimensions/anchor.
\tfor layer in ["shirt","pants","shoes"]:
\t\tvar sprite=Sprite2D.new()
\t\tsprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\t\tsprite.position=base_sprite.position
\t\tsprite.z_index=1
\t\tsprite.name="Starter"+layer.capitalize()
\t\tplayer.add_child(sprite)
\t\tstarter_appearance_sprites[layer]=sprite
\t# Hair is intentionally above torso layers; headgear will require masks.
\thair_sprite.z_index=5
\t_set_layered_appearance_frame()

func _set_layered_appearance_frame()->void:
\tif base_sprite==null or not is_instance_valid(base_sprite):return
\tvar relative:String="base_variant_%02d/%s_%02d.png" % [int(data["body"])+1,facing,anim_frame]
\tvar base_path:String="res://assets/appearance/base/"+relative
\tif ResourceLoader.exists(base_path):
\t\tbase_sprite.texture=load(base_path)
\telse:
\t\tbase_sprite.texture=load(_sprite_path("characters","base_variant_%02d" % (int(data["body"])+1),facing,anim_frame))
\tfor layer in ["shirt","pants","shoes"]:
\t\tif not starter_appearance_sprites.has(layer):continue
\t\tvar sprite:Sprite2D=starter_appearance_sprites[layer]
\t\tif not is_instance_valid(sprite):continue
\t\tvar path:String="res://assets/appearance/starter/%s/%s" % [layer,relative]
\t\tsprite.texture=load(path) if ResourceLoader.exists(path) else null
\t\tsprite.position=base_sprite.position
'''
path.write_text(src,encoding="utf-8")
print("AO APPEARANCE LAYER PATCH OK: optional exact-frame rendered starter layers")
