extends SceneTree
# Visual QA for actual Godot on-character gear layer textures (not concept art).
func _initialize()->void:
	call_deferred("_run")

func _sprite(parent:Node,path:String,center:Vector2,z:int)->Sprite2D:
	var s=Sprite2D.new()
	s.position=center
	s.scale=Vector2(1.52,1.52)
	s.z_index=z
	s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture=load(path)
	parent.add_child(s)
	return s

func _label(parent:Node,label:String,x:float,y:float,sz:int)->void:
	var l=Label.new()
	l.text=label
	l.position=Vector2(x,y)
	l.add_theme_font_size_override("font_size",sz)
	l.add_theme_color_override("font_color",Color("#f8dba5"))
	parent.add_child(l)

func _run()->void:
	var canvas=Node2D.new()
	root.add_child(canvas)
	var bg=ColorRect.new()
	bg.color=Color("#1b2735")
	bg.size=Vector2(1280,720)
	canvas.add_child(bg)
	_label(canvas,"ADVENTURE ODYSSEY / FIRST WEARABLE EQUIPMENT PREVIEW",38,20,26)
	_label(canvas,"Original icon-derived colors and item designs; production polish pending",38,54,17)
	var sets=[
		{"class":"WARRIOR","body":4,"armor":"Guard Breastplate","head":"Leather Hood","cloak":"Forest Cloak","gloves":"Padded Gloves","boots":"Steel Boots","weapon":"Iron Axe","accessory":"Copper Ring"},
		{"class":"MAGE","body":6,"armor":"Apprentice Robe","head":"","cloak":"Forest Cloak","gloves":"Padded Gloves","boots":"Steel Boots","weapon":"Ember Staff","accessory":"Moon Brooch"}
	]
	var directions=["down","left","up","right"]
	for row in range(2):
		var equip:Dictionary=sets[row]
		var variant:String="base_variant_%02d" % int(equip["body"])
		_label(canvas,str(equip["class"])+(" / heavy armor + axe" if row==0 else " / robe + staff"),44,112+row*302,19)
		for col in range(4):
			var face:String=directions[col]
			var frame:String=face+"_00.png"
			var rel:String=variant+"/"+frame
			var center=Vector2(225+col*280,220+row*302)
			_label(canvas,face.to_upper(),center.x-30,128+row*302,15)
			if equip["cloak"]!="":
				var slug:String=str(equip["cloak"]).to_lower().replace(" ","_")
				_sprite(canvas,"res://assets/worn_gear/"+slug+"/"+rel,center,0 if face=="up" else -1)
			_sprite(canvas,"res://assets/character_layers/underwear_base/"+rel,center,1)
			_sprite(canvas,"res://assets/character_layers/starter_pants/"+rel,center,2)
			for slot in ["armor","boots","gloves","accessory","weapon","head"]:
				var item:String=str(equip.get(slot,""))
				if item=="":continue
				var slug:String=item.to_lower().replace("'","").replace(" ","_")
				var layer:int=4 if slot=="armor" else 5 if slot in ["boots","gloves"] else 7 if slot in ["head","weapon"] else 6
				_sprite(canvas,"res://assets/worn_gear/"+slug+"/"+rel,center,layer)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for i in range(16):await process_frame
	var shot=root.get_texture().get_image()
	if shot==null or shot.save_png("res://screenshots/worn_equipment_previews.png")!=OK:
		push_error("AO WORN GEAR SCREENSHOT FAILED");quit(1);return
	print("AO WORN GEAR SCREENSHOT: PASS")
	quit(0)
