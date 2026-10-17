extends SceneTree
func _initialize() -> void: call_deferred("run")
func snap(path: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
func run() -> void:
	root.size = Vector2i(1536,1024)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var canvas := Control.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color=Color("eee5d2")
	bg.size=Vector2(1536,1024)
	canvas.add_child(bg)
	for row in range(4):
		for phase in range(6):
			var a=preload("res://src/layered_avatar.gd").new()
			canvas.add_child(a)
			a.configure("male","Warrior",{"hair":"male_hair_%02d" % [1,6,11,15][row],"hair_color":["Brown","Silver","Auburn","Blonde"][row],"skin":["warm","blue","deep","red"][row],"eyes":"Green"})
			a.set_equipped_weapon("warrior_01_weapon")
			a.advance(1,true,0)
			a.elapsed=(phase+0.01)/9.0
			a.advance(1,true,0)
			assert(a.uses_painted_pilot() and a.palette_ready and a.hair_renderer.ready and a.weapon_back.visible)
			a.position=Vector2(phase*256+128,row*256+248)
			var label:=Label.new()
			label.text="Style %02d / pose %d" % [[1,6,11,15][row],phase+1]
			label.position=Vector2(phase*256+8,row*256+6)
			label.add_theme_color_override("font_color",Color("30291e"))
			canvas.add_child(label)
	await snap("res://screenshots/painted_walk_customization.png")
	canvas.queue_free()
	await process_frame
	root.size=Vector2i(1280,720)
	var room=preload("res://src/bedroom.gd").new()
	var draft=preload("res://src/creator/character_draft.gd").new()
	draft.username="PaintedWalkQA"
	room.state.path="user://painted_walk_capture.json"
	assert(room.state.create(draft.payload()))
	assert(room.state.transfer("warrior_01_weapon",false))
	assert(room.state.equip("warrior_01_weapon"))
	root.add_child(room)
	room.set_process(false)
	room.player=Vector2(820,820)
	room.touch_direction=Vector2.LEFT
	for frame in range(72):
		room._process(1.0/36.0)
		await snap("res://screenshots/painted_walk_motion_%02d.png" % frame)
	quit()
