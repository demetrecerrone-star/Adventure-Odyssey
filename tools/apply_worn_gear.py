#!/usr/bin/env python3
"""Hook first-pass wearable equipment sprite layers to real gear slots in Godot.

Worn pixels are separately authored/generated from the *approved original item
icon silhouettes and colors*. Gear is never class-gated. Art is provisional
pending visual review; no inventory icons are substituted by floating UI panels.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")

def rep(old,new):
    global s
    if s.count(old)!=1:
        raise SystemExit(f"AO WORN GEAR PATCH ANCHOR FAILED {s.count(old)}: {old[:75]}")
    s=s.replace(old,new,1)

rep('var starter_clothes_sprites: Dictionary={}', '''var starter_clothes_sprites: Dictionary={}
var worn_equipment_sprites: Dictionary={}''')

rep('''\t_create_starter_clothing_layers()
\tcamera=Camera2D.new()''','''\t_create_starter_clothing_layers()
\t_create_worn_equipment_layers()
\tcamera=Camera2D.new()''')

rep('''\t_update_starter_clothing_layers()
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''','''\t_update_starter_clothing_layers()
\t_update_worn_equipment()
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''')

rep('''\tdata["equipment"][str(definition["slot"])]=item
\t_save()''','''\tdata["equipment"][str(definition["slot"])]=item
\t_update_worn_equipment()
\t_save()''')

rep('''\tdata["equipment"].erase(slot)
\t_save()''','''\tdata["equipment"].erase(slot)
\t_update_worn_equipment()
\t_save()''')

s+='''
# -- Character-attached equipment visuals from real item IDs ----------------
const WORN_EQUIPMENT_SLOTS=["cloak","armor","boots","gloves","head","accessory","weapon"]

func _create_worn_equipment_layers()->void:
\tworn_equipment_sprites={}
\tif player==null:return
\tfor slot in WORN_EQUIPMENT_SLOTS:
\t\tvar sprite=Sprite2D.new()
\t\tsprite.name="Worn_"+slot
\t\tsprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\t\tsprite.position=base_sprite.position
\t\tsprite.centered=base_sprite.centered
\t\tsprite.z_index=-2 if slot=="cloak" else 3 if slot=="armor" else 4 if slot in ["gloves","boots"] else 6 if slot in ["head","weapon"] else 5
\t\tplayer.add_child(sprite)
\t\tworn_equipment_sprites[slot]=sprite
\t_update_worn_equipment()

func _worn_gear_path(item:String)->String:
\tvar slug:String=item.to_lower().replace("'","").replace(" ","_")
\treturn "res://assets/worn_gear/%s/base_variant_%02d/%s_%02d.png" % [slug,int(data["body"])+1,facing,anim_frame]

func _update_worn_equipment()->void:
\tif worn_equipment_sprites.is_empty():return
\t_ensure_gear()
\tvar equipped:Dictionary=data.get("equipment",{})
\tfor slot in WORN_EQUIPMENT_SLOTS:
\t\tif not worn_equipment_sprites.has(slot):continue
\t\tvar sprite:Sprite2D=worn_equipment_sprites[slot]
\t\tif sprite==null or not is_instance_valid(sprite):continue
\t\tvar item:String=str(equipped.get(slot,""))
\t\tvar path:String=_worn_gear_path(item)
\t\tsprite.position=base_sprite.position
\t\tsprite.z_index=(2 if facing=="up" else -2) if slot=="cloak" else (4 if facing=="up" else 6) if slot=="weapon" else 3 if slot=="armor" else 4 if slot in ["gloves","boots"] else 7 if slot=="head" else 5
\t\tif item!="" and ResourceLoader.exists(path):
\t\t\tsprite.texture=load(path)
\t\t\tsprite.visible=true
\t\telse:
\t\t\tsprite.texture=null
\t\t\tsprite.visible=false
\t# Starter shirt and shoes still exist underneath as independent layers.
\t# An equipped coat/plate and boots replace only what must be covered.
\tif starter_clothes_sprites.has("starter_top"):
\t\tstarter_clothes_sprites["starter_top"].visible=str(equipped.get("armor",""))==""
\tif starter_clothes_sprites.has("starter_shoes"):
\t\tstarter_clothes_sprites["starter_shoes"].visible=str(equipped.get("boots",""))==""
\tif hair_sprite!=null and is_instance_valid(hair_sprite):
\t\thair_sprite.visible=str(equipped.get("head",""))==""
'''
p.write_text(s,encoding="utf8")
print("AO WORN GEAR PATCH OK: seven visible equipment slots follow movement, equip, remove, and map changes")
