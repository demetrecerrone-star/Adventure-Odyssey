extends SceneTree
# Real Godot-rendered reference grid (not concept art) of reconstructed AO sprites.
func _initialize()->void:
	call_deferred("_run")

func _label(parent:Node,text:String,x:float,y:float,size:int=16)->void:
	var l=Label.new()
	l.position=Vector2(x,y)
	l.text=text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("#f2d9aa"))
	parent.add_child(l)

func _capture(name:String)->bool:
	for i in range(12):await process_frame
	var pic:Image=root.get_texture().get_image()
	if pic==null or pic.get_width()<1000:return false
	return pic.save_png("res://screenshots/"+name)==OK

func _grid(use_clothes:bool)->Node2D:
	var canvas=Node2D.new()
	root.add_child(canvas)
	var bg=ColorRect.new()
	bg.size=Vector2(1280,720)
	bg.color=Color("#192433")
	canvas.add_child(bg)
	_label(canvas,"ADVENTURE ODYSSEY: 8 ORIGINAL CHARACTER VARIANTS / 4 DIRECTIONS",34,12,24)
	_label(canvas,"Base underlayers + independent starting clothes" if use_clothes else "Opaque underlayers only: source-derived appearance prototype",36,46,18)
	var directions=["down","left","up","right"]
	for row in range(4):
		_label(canvas,directions[row].to_upper(),18,110+row*147,15)
		for index in range(8):
			var variant=index+1
			var rel="base_variant_%02d/%s_00.png" % [variant,directions[row]]
			var center=Vector2(109+index*144,122+row*145)
			var texture=load("res://assets/appearance/base/"+rel)
			var body=Sprite2D.new()
			body.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			body.texture=texture
			body.position=center
			body.scale=Vector2(1.03,1.03)
			canvas.add_child(body)
			if use_clothes:
				for type in ["shirt","pants","shoes"]:
					var s=Sprite2D.new()
					s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
					s.position=center
					s.scale=body.scale
					s.texture=load("res://assets/appearance/starter/%s/%s" % [type,rel])
					canvas.add_child(s)
			if row==0:
				_label(canvas,"BODY "+str(variant),center.x-28,76,12)
	return canvas

func _run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var base=_grid(false)
	if not await _capture("appearance_underlayer_8x4.png"):
		push_error("AO UNDERLAYER VISUAL CAPTURE FAILED");quit(1);return
	base.queue_free()
	await process_frame
	var dressed=_grid(true)
	if not await _capture("appearance_starter_8x4.png"):
		push_error("AO STARTER VISUAL CAPTURE FAILED");quit(1);return
	print("AO APPEARANCE VISUAL CAPTURE: PASS")
	quit(0)
