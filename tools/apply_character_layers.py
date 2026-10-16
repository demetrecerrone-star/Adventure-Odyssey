#!/usr/bin/env python3
"""Enable preview-safe layered starter appearance after generation.

The original 96 character sprites remain untouched; the starter outfit is
pixel-reconstructed on independent transparent Sprite2D layers. Existing gear
mechanics and saves are preserved. Worn-item art is a subsequent milestone.
"""
from pathlib import Path
p=Path('scripts/game.gd')
s=p.read_text(encoding='utf8')
def rep(before,after):
    global s
    n=s.count(before)
    if n!=1:raise SystemExit(f'CHARACTER LAYER PATCH ANCHOR FAILED ({n}): {before[:140]!r}')
    s=s.replace(before,after,1)
rep('var hair_sprite: Sprite2D', '''var hair_sprite: Sprite2D
var starter_clothes_sprites: Dictionary={}
'''.rstrip())
rep('''\tplayer.add_child(hair_sprite)
\tcamera=Camera2D.new()''','''\tplayer.add_child(hair_sprite)
\t_create_starter_clothing_layers()
\tcamera=Camera2D.new()''')
rep('''\tbase_sprite.texture=load(_sprite_path("characters","base_variant_%02d" % (int(data["body"])+1),facing,anim_frame))
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''','''\tbase_sprite.texture=load(_layer_sprite_path("underwear_base",facing,anim_frame))
\t_update_starter_clothing_layers()
\thair_sprite.texture=load(_sprite_path("hair",HAIR[int(data["hair"])],facing,anim_frame))''')
s+='''
# -- Four-direction modest base + removable starter outfit -------------------
# Worn gear sprite art is not yet finalized; the starting clothes stay visible
# until proper per-equipment sprite overlays exist. Never fake item art by
# magnifying its inventory icon on top of the character.
const STARTER_CLOTHES_LAYERS=["starter_pants","starter_top","starter_shoes"]

func _layer_sprite_path(layer:String,direction:String,frame:int)->String:
	return "res://assets/character_layers/%s/base_variant_%02d/%s_%02d.png" % [layer,int(data["body"])+1,direction,frame]

func _create_starter_clothing_layers()->void:
	starter_clothes_sprites.clear()
	if player==null or base_sprite==null:return
	for layer in STARTER_CLOTHES_LAYERS:
		var sprite=Sprite2D.new()
		sprite.name="Clothing_"+layer
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position=base_sprite.position
		sprite.centered=base_sprite.centered
		player.add_child(sprite)
		# Keep hair rendered on top of clothing, as in the old merged sprites.
		player.move_child(sprite,hair_sprite.get_index())
		starter_clothes_sprites[layer]=sprite
	_update_starter_clothing_layers()

func _update_starter_clothing_layers()->void:
	for layer in STARTER_CLOTHES_LAYERS:
		if not starter_clothes_sprites.has(layer):continue
		var sprite:Sprite2D=starter_clothes_sprites[layer]
		if sprite==null or not is_instance_valid(sprite):continue
		var path:String=_layer_sprite_path(layer,facing,anim_frame)
		if ResourceLoader.exists(path):
			sprite.texture=load(path)
			sprite.visible=true
		else:
			# Never render a naked frame when a missing layer fails to import.
			sprite.visible=false
			push_warning("Starter clothing sprite unavailable: "+path)
'''
p.write_text(s,encoding='utf8')
print('AO CHARACTER LAYERS APPLIED: PASS / 8 bodies / 4 facings / 3 frames / starter clothes as separate transparent overlays')