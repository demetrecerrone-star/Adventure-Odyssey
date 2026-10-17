extends SceneTree
func _initialize()->void:call_deferred("run")
func snap(path:String)->void:
	for tick in range(3):await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func run()->void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var batches=JSON.parse_string(FileAccess.get_file_as_string("res://tests/painted_migration_batch.json"))
	for batch in batches:
		var base:String=batch.base
		var cls:String=batch.class_id
		var weapon:String=cls.to_lower()+"_01_weapon"
		for direction in batch.directions:
			var name:String=["down","left","right","up"][direction]
			var prefix:String="res://screenshots/migration_%s_%s_%s" % [base,cls.to_lower(),name]
			root.size=Vector2i(1536,1024)
			var canvas:=Control.new()
			root.add_child(canvas)
			var bg:=ColorRect.new()
			bg.color=Color("eee5d2")
			bg.size=Vector2(1536,1024)
			canvas.add_child(bg)
			for row in range(4):
				for phase in range(6):
					var a=preload("res://src/layered_avatar.gd").new()
					canvas.add_child(a)
					a.configure(base,cls,{"hair":base+"_hair_%02d" % [1,6,11,15][row],"hair_color":["Brown","Silver","Auburn","Blonde"][row],"skin":["warm","blue","deep","red"][row],"eyes":"Green"})
					a.set_equipped_weapon(weapon)
					a.advance(direction,true,0)
					a.elapsed=(phase+0.01)/9.0
					a.advance(direction,true,0)
					assert(a.uses_painted_pilot() and a.palette_ready and a.hair_renderer.ready and a.weapon_back.visible)
					a.position=Vector2(phase*256+128,row*256+248)
					var label:=Label.new()
					label.text="%s %s / pose%d" % [base,cls,phase+1]
					label.position=Vector2(phase*256+8,row*256+6)
					label.add_theme_color_override("font_color",Color("30291e"))
					canvas.add_child(label)
			await snap(prefix+"_palette.png")
			canvas.queue_free()
			await process_frame
			root.size=Vector2i(1280,720)
			var room=preload("res://src/bedroom.gd").new()
			var draft=preload("res://src/creator/character_draft.gd").new()
			draft.username="MigrationQA"
			draft.set_base(base)
			draft.character_class=cls
			room.state.path="user://migration_capture.json"
			DirAccess.remove_absolute(room.state.path)
			assert(room.state.create(draft.payload()))
			assert(room.state.transfer(weapon,false) and room.state.equip(weapon))
			root.add_child(room)
			room.set_process(false)
			room.player=Vector2(820,650)
			room.actor.advance(direction,false,0)
			room.touch_direction=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][direction]
			for frame in range(24):
				room._process(1.0/36.0)
				await snap(prefix+"_motion_%02d.png" % frame)
			room.queue_free()
			await process_frame
	quit()
