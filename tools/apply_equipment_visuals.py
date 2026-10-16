#!/usr/bin/env python3
"""Seven-slot Godot worn-equipment renderer with safe missing-art fallbacks.

Worn sprite textures are intentionally not inferred from inventory icons. A
sprite is displayed only once a pose-aligned image really exists; otherwise
starter clothes stay on so characters never appear unclothed. This prepares
for matching inventory icon / worn-art pairs without changing item IDs.
"""
from pathlib import Path
p=Path('scripts/game.gd');s=p.read_text(encoding='utf8')
def rep(old,new):
    global s
    if s.count(old)!=1:raise SystemExit(f'EQUIPMENT VISUAL ANCHOR FAILED ({s.count(old)}): {old[:110]!r}')
    s=s.replace(old,new,1)
rep('var starter_clothes_sprites: Dictionary={}', '''var starter_clothes_sprites: Dictionary={}
var worn_equipment_sprites: Dictionary={}''')
rep('''\t_create_starter_clothing_layers()
\tcamera=Camera2D.new()''','''\t_create_starter_clothing_layers()
\t_create_worn_equipment_nodes()
\tcamera=Camera2D.new()''')
rep('''\t_update_starter_clothing_layers()
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''','''\t_update_starter_clothing_layers()
\t_update_worn_equipment_frames()
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''')
rep('''\tdata["equipment"][str(definition["slot"])]=item
\t_save()''','''\tdata["equipment"][str(definition["slot"])]=item
\t_update_worn_equipment_frames()
\t_save()''')
rep('''\tdata["equipment"].erase(slot)
\t_save()''','''\tdata["equipment"].erase(slot)
\t_update_worn_equipment_frames()
\t_save()''')
s+='''
# -- Equipment appearance controller: path-safe and save-compatible ----------
# No enlarged inventory icons are used as character art. Files must be
# purpose-drawn 128px-high sprites aligned to the underlayer pose.
const WORN_EQUIPMENT_SLOTS=["cloak","armor","gloves","boots","weapon","head","accessory"]
const WORN_DRAW_ORDER={"cloak":0,"armor":3,"gloves":4,"boots":4,"weapon":5,"head":8,"accessory":6}

func _worn_gear_texture_path(slot:String,item:String,direction:String,frame:int)->String:
	var slug:String=item.to_lower().replace("'","").replace(" ","_")
	return "res://assets/equipment_worn/%s/%s/base_variant_%02d/%s_%02d.png" % [slot,slug,int(data.get("body",0))+1,direction,frame]

func _create_worn_equipment_nodes()->void:
	worn_equipment_sprites.clear()
	if player==null or not is_instance_valid(player):return
	for slot in WORN_EQUIPMENT_SLOTS:
		var node=Sprite2D.new()
		node.name="Equipped_"+slot
		node.position=base_sprite.position
		node.centered=base_sprite.centered
		node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		node.z_index=int(WORN_DRAW_ORDER[slot])
		node.visible=false
		player.add_child(node)
		worn_equipment_sprites[slot]=node
	# Hair remains foremost except when future headgear artwork requests masking.
	base_sprite.z_index=1
	for layer in starter_clothes_sprites.values():
		if layer!=null and is_instance_valid(layer):layer.z_index=2
	hair_sprite.z_index=7
	_update_worn_equipment_frames()

func _update_worn_equipment_frames()->void:
	if player==null or not is_instance_valid(player):return
	var hide_top=false
	var hide_shoes=false
	for slot in WORN_EQUIPMENT_SLOTS:
		if not worn_equipment_sprites.has(slot):continue
		var node:Sprite2D=worn_equipment_sprites[slot]
		if node==null or not is_instance_valid(node):continue
		var item:String=_equipped(slot)
		var path:String=_worn_gear_texture_path(slot,item,facing,anim_frame) if item!="" else ""
		if path!="" and ResourceLoader.exists(path):
			var texture:Texture2D=load(path)
			if texture!=null and texture.get_height()==128 and texture.get_width()==base_sprite.texture.get_width():
				node.texture=texture
				node.visible=true
				if slot=="armor":hide_top=true
				if slot=="boots":hide_shoes=true
			else:
				node.visible=false
				node.texture=null
		else:
			# Never substitute huge HUD icons or render uncovered characters.
			node.visible=false
			node.texture=null
	if starter_clothes_sprites.has("starter_top"):
		starter_clothes_sprites["starter_top"].visible=not hide_top
	if starter_clothes_sprites.has("starter_shoes"):
		starter_clothes_sprites["starter_shoes"].visible=not hide_shoes
'''
p.write_text(s,encoding='utf8')
print('AO EQUIPMENT VISUAL CONTROLLER: PASS / seven slots / pose-aware asset lookup / modest missing-art fallback')