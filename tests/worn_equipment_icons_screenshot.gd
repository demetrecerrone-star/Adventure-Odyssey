extends SceneTree
# A genuine Godot screenshot showing the 34 worn-art-matched item icons.
func _initialize()->void:
	call_deferred("_capture")
func _label(parent:Node,value:String,at:Vector2,font:int)->void:
	var node=Label.new()
	node.text=value
	node.position=at
	node.add_theme_font_size_override("font_size",font)
	node.add_theme_color_override("font_color",Color("#f3deb5"))
	parent.add_child(node)
func _capture()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene._random_default()
	scene._enter_world("town",Vector2(1030,980))
	await process_frame
	scene._clear_ui()
	var canvas=Control.new()
	canvas.size=Vector2(1280,720)
	root.add_child(canvas)
	var bg=ColorRect.new()
	bg.color=Color("#192938")
	bg.size=Vector2(1280,720)
	canvas.add_child(bg)
	_label(canvas,"ADVENTURE ODYSSEY / MATCHING EQUIPMENT ITEM ICONS",Vector2(39,15),24)
	_label(canvas,"Derived from the actual wearable sprite artwork • 34 items • first-pass visual review",Vector2(39,51),15)
	var names:Array=scene.ITEM_CATALOG.keys()
	names.sort()
	for index in range(names.size()):
		var item:String=str(names[index])
		var col:int=index%7
		var row:int=int(index/7)
		var x:float=48+col*173
		var y:float=92+row*123
		var slug:String=item.to_lower().replace("'","").replace(" ","_")
		var path:String="res://assets/equipment_item_icons/"+slug+".png"
		if not ResourceLoader.exists(path):
			push_error("MISSING MATCHED ICON: "+path)
			quit(1)
			return
		var icon=TextureRect.new()
		icon.texture=load(path)
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position=Vector2(x+27,y)
		icon.size=Vector2(88,88)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		canvas.add_child(icon)
		_label(canvas,item.substr(0,21),Vector2(x,y+88),12)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for i in range(12):await process_frame
	var image=root.get_texture().get_image()
	if image==null or image.save_png("res://screenshots/worn_equipment_matching_icons.png")!=OK:
		push_error("MATCHED ICONS SCREENSHOT FAILED")
		quit(1)
		return
	print("ADVENTURE ODYSSEY MATCHING WORN ICONS SCREENSHOT: PASS")
	quit(0)
