extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Capture requires a rendered display; headless cannot certify visual output.")
		quit(2)
		return
	var scene = load("res://src/corridor.gd").new()
	root.add_child(scene)
	scene.interactive=false
	await settle()
	var composed := Image.create(2880,1023,false,Image.FORMAT_RGBA8)
	for entry in scene.layout.chunks:
		var img := Image.load_from_file("res://"+entry.file)
		img.convert(Image.FORMAT_RGBA8)
		var r: Array=entry.local_rect
		composed.blit_rect(img,Rect2i(2,2,r[2],r[3]),Vector2i(r[0],r[1]))
	var reference := Sprite2D.new()
	reference.texture=ImageTexture.create_from_image(composed)
	reference.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	reference.centered=false
	reference.position=scene.origin
	reference.visible=false
	scene.add_child(reference)
	var comparisons := []
	for point in [{"id":"home_native","p":Vector2(600,550),"zoom":1.0},{"id":"join_native","p":Vector2(1344,512),"zoom":1.0},{"id":"join_fractional","p":Vector2(1344.375,511.625),"zoom":1.0},{"id":"join_zoom_150","p":Vector2(1344.375,511.625),"zoom":1.5},{"id":"join_zoom_200","p":Vector2(1344.375,511.625),"zoom":2.0},{"id":"plaza_native","p":Vector2(1800,500),"zoom":1.0}]:
		scene.player.position=scene.origin+point.p
		scene.camera.position=scene.player.position
		scene.camera.zoom=Vector2.ONE*point.zoom
		scene.update_chunks()
		scene.actor.visible=true
		await settle()
		root.get_texture().get_image().save_png("res://results/"+point.id+".png")
		scene.actor.visible=false
		await settle()
		var chunk_image := root.get_texture().get_image()
		for sprite in scene.chunks.values(): sprite.visible=false
		reference.visible=true
		await settle()
		var ref_image := root.get_texture().get_image()
		var changed := 0
		var max_delta := 0.0
		for y in range(chunk_image.get_height()):
			for x in range(chunk_image.get_width()):
				var a := chunk_image.get_pixel(x,y)
				var b := ref_image.get_pixel(x,y)
				var d := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
				max_delta=maxf(max_delta,d)
				if d>2.0/255: changed+=1
		comparisons.append({"id":point.id,"pixels_diff_gt_2":changed,"max_channel_delta_255":max_delta*255})
		reference.visible=false
		for sprite in scene.chunks.values(): sprite.visible=true
	# Deterministic 60 rendered frames crossing the repaired join at 135 px/s.
	scene.actor.visible=true
	scene.camera.zoom=Vector2.ONE
	for frame in range(60):
		scene.player.position=scene.origin+Vector2(1276.5+frame*2.25,500)
		scene.camera.position=scene.player.position
		scene.update_chunks()
		await settle()
		if frame in [0,29,59]:
			root.get_texture().get_image().save_png("res://results/motion_%02d.png" % frame)
	var result := {"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"comparison":"Chunked render versus reconstructed single texture, identical camera; threshold 2/255","comparisons":comparisons,"device_performance_test":false}
	FileAccess.open("res://results/render-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit()
