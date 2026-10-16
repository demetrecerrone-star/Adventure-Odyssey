extends SceneTree
# Visual QA built from the actual playable character Sprite2D state.
# Preview clones preserve visibility, textures and draw order established by
# the seven-slot equipment renderer. They do not redraw item art by hand.
func _initialize() -> void:
	call_deferred("_run")

func _label(parent:Node, value:String, at:Vector2, size:int=16) -> void:
	var node=Label.new()
	node.text=value
	node.position=at
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("#f4dfb9"))
	parent.add_child(node)

func _canvas(title:String, subtitle:String) -> Dictionary:
	var overlay=CanvasLayer.new()
	overlay.layer=99
	root.add_child(overlay)
	var canvas=Control.new()
	canvas.size=Vector2(1280,720)
	overlay.add_child(canvas)
	var bg=ColorRect.new()
	bg.size=Vector2(1280,720)
	bg.color=Color("#192634")
	canvas.add_child(bg)
	_label(canvas,title,Vector2(32,16),23)
	_label(canvas,subtitle,Vector2(34,50),15)
	return {"overlay":overlay,"canvas":canvas}

func _copy_visible_sprite(parent:Node2D, source:Sprite2D) -> void:
	if source==null or not is_instance_valid(source) or not source.visible or source.texture==null:
		return
	var clone=Sprite2D.new()
	clone.texture=source.texture
	clone.position=source.position
	clone.offset=source.offset
	clone.scale=source.scale
	clone.rotation=source.rotation
	clone.modulate=source.modulate
	clone.self_modulate=source.self_modulate
	clone.centered=source.centered
	clone.flip_h=source.flip_h
	clone.flip_v=source.flip_v
	clone.z_index=source.z_index
	clone.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(clone)

func _player_cell(game:Node, parent:Node, center:Vector2, magnification:float) -> void:
	var anchor=Node2D.new()
	anchor.position=center
	anchor.scale=Vector2(magnification,magnification)
	parent.add_child(anchor)
	var selected:Array=[game.base_sprite,game.hair_sprite]
	for slot in game.STARTER_CLOTHES_LAYERS:
		selected.append(game.starter_clothes_sprites[slot])
	for slot in game.WORN_EQUIPMENT_SLOTS:
		selected.append(game.worn_equipment_sprites[slot])
	# Match actual player child order for sprites sharing a z_index.
	for child in game.player.get_children():
		if child is Sprite2D and selected.has(child):
			_copy_visible_sprite(anchor,child)

func _loadout(game:Node, equipment:Dictionary, body:int, hair:int) -> void:
	game._ensure_gear()
	for slot in game.WORN_EQUIPMENT_SLOTS:
		if game._equipped(slot)!="":
			game._unequip_slot(slot)
	game.data["body"]=body
	game.data["hair"]=clampi(hair,0,game.HAIR.size()-1)
	for slot in equipment.keys():
		var item:String=str(equipment[slot])
		game.data["inventory"][item]=1
		game._equip_item(item)
	game._set_player_frame()

func _capture(name:String) -> bool:
	for i in range(15):
		await process_frame
	var picture:Image=root.get_texture().get_image()
	return picture!=null and picture.get_width()>=1280 and picture.get_height()>=720 and picture.save_png("res://screenshots/"+name)==OK

func _run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	game._enter_world("town",Vector2(1030,980))
	await process_frame
	game._clear_ui()
	var warrior={"armor":"Guard Breastplate","head":"Leather Hood","cloak":"Forest Cloak","gloves":"Padded Gloves","boots":"Steel Boots","weapon":"Iron Axe","accessory":"Copper Ring"}
	var mage={"armor":"Apprentice Robe","cloak":"Forest Cloak","gloves":"Padded Gloves","boots":"Steel Boots","weapon":"Ember Staff","accessory":"Moon Brooch"}
	var facings=["down","left","up","right"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var layout=_canvas("ADVENTURE ODYSSEY / LIVE EQUIPMENT RENDERER", "Two equipped loadouts • four directions • gameplay sprite depth and hairstyle")
	var canvas:Control=layout["canvas"]
	for row in range(2):
		var gear:Dictionary=warrior if row==0 else mage
		_loadout(game,gear,3 if row==0 else 5,2 if row==0 else 5)
		_label(canvas,"WARRIOR / breastplate + axe + hood" if row==0 else "MAGE / robe + staff + visible hair",Vector2(38,100+row*300),18)
		for col in range(4):
			game.facing=facings[col]
			game.anim_frame=0
			game._set_player_frame()
			var center=Vector2(208+col*290,224+row*300)
			_label(canvas,str(facings[col]).to_upper(),Vector2(center.x-24,129+row*300),14)
			_player_cell(game,canvas,center,1.46)
	if not await _capture("worn_equipment_previews.png"):
		push_error("LIVE EQUIPMENT PREVIEW CAPTURE FAILED")
		quit(1)
		return
	layout["overlay"].queue_free()
	await process_frame
	var walk=_canvas("ADVENTURE ODYSSEY / EQUIPPED WALK FRAMES", "Live renderer • warrior equipment • 4 directions × 3 walking frames • check grip and clipping")
	var walk_canvas:Control=walk["canvas"]
	_loadout(game,warrior,3,2)
	for frame in range(3):
		for col in range(4):
			game.facing=facings[col]
			game.anim_frame=frame
			game._set_player_frame()
			var center=Vector2(190+col*290,175+frame*181)
			_label(walk_canvas,str(facings[col]).to_upper()+"  /  FRAME "+str(frame),Vector2(center.x-68,94+frame*181),14)
			_player_cell(game,walk_canvas,center,1.20)
	if not await _capture("equipment_walk_pose_grid.png"):
		push_error("LIVE WALK POSE GRID CAPTURE FAILED")
		quit(1)
		return
	walk["overlay"].queue_free()
	await process_frame
	var fit=_canvas("ADVENTURE ODYSSEY / EQUIPMENT FIT CHECK", "Live renderer • 8 appearances × 4 directions • armor, hood, cloak, boots, weapon")
	var fit_canvas:Control=fit["canvas"]
	_loadout(game,warrior,0,2)
	for row in range(4):
		_label(fit_canvas,str(facings[row]).to_upper(),Vector2(18,135+row*147),14)
		for body in range(8):
			game.data["body"]=body
			game.facing=facings[row]
			game.anim_frame=0
			game._set_player_frame()
			var center=Vector2(116+body*145,164+row*147)
			if row==0:
				_label(fit_canvas,"BODY "+str(body+1),Vector2(center.x-27,83),12)
			_player_cell(game,fit_canvas,center,0.99)
	if not await _capture("equipment_fit_8x4.png"):
		push_error("LIVE EIGHT-BODY FIT GRID CAPTURE FAILED")
		quit(1)
		return
	print("ADVENTURE ODYSSEY LIVE EQUIPMENT PREVIEWS: PASS / two loadouts, twelve walking poses, thirty-two fit poses")
	quit(0)
