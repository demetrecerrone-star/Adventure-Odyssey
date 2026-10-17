extends SceneTree
var failures := []
var report := {"renderer_visual_pass":false,"scope":"Bounded corridor only; no navmesh, no buildings, no APK","routes":[],"checks":[]}
func check(ok: bool, label: String) -> void:
	report.checks.append({"check":label,"pass":ok})
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://src/corridor.gd").new()
	root.add_child(scene)
	scene.interactive = false
	await physics_frame
	await physics_frame
	check(is_equal_approx(scene.actor.texture.get_height()*scene.actor.scale.y,96.0),"Actor visible bounding box 96 world px")
	check(scene.layout.chunks.size()==12,"12 chunk definitions")
	# Engine collision sweeps use a full corridor half-width circle, including end caps.
	var wide := CircleShape2D.new()
	wide.radius = 36
	var space = scene.get_world_2d().direct_space_state
	for route in scene.layout.routes:
		var route_clear := true
		var length := 0.0
		for i in range(route.points.size()-1):
			var a: Vector2 = scene.origin + scene.vec(route.points[i])
			var b: Vector2 = scene.origin + scene.vec(route.points[i+1])
			length += a.distance_to(b)
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = wide
			query.transform = Transform2D(0,a)
			query.motion = b-a
			query.exclude = [scene.player.get_rid()]
			var initial = space.intersect_shape(query)
			var cast = space.cast_motion(query)
			if not initial.is_empty() or cast[0]<0.99999: route_clear=false
		check(route_clear,route.id+" 72 px width swept by Godot physics")
		scene.player.position=scene.origin+scene.vec(route.points[0])
		var steps := 0
		var hits := 0
		for i in range(1,route.points.size()):
			var target: Vector2=scene.origin+scene.vec(route.points[i])
			while scene.player.position.distance_to(target)>0.01 and steps<3000:
				var motion: Vector2=(target-scene.player.position).limit_length(135.0/60)
				if scene.player.move_and_collide(motion)!=null: hits+=1; break
				scene.camera.position=scene.player.position
				scene.update_chunks()
				steps+=1
		check(hits==0 and scene.player.position.distance_to(scene.origin+scene.vec(route.points[-1]))<0.02,route.id+" CharacterBody2D traversal 135 px/s")
		report.routes.append({"id":route.id,"length_px":length,"ideal_seconds":length/135,"fixed_steps":steps,"collisions":hits})
	# Check real colliders reject entry, not merely route non-intersection.
	var probe := PhysicsRayQueryParameters2D.create(scene.origin+Vector2(800,500),scene.origin+Vector2(800,250))
	probe.exclude=[scene.player.get_rid()]
	check(not space.intersect_ray(probe).is_empty(),"Upper water bank blocks direct crossing")
	probe.from=scene.origin+Vector2(850,550); probe.to=scene.origin+Vector2(900,750)
	check(not space.intersect_ray(probe).is_empty(),"Lower water bank blocks direct crossing")
	probe.from=scene.origin+Vector2(50,250); probe.to=scene.origin+Vector2(50,100)
	check(not space.intersect_ray(probe).is_empty(),"Forest cliff blocks direct crossing")
	# Sweep camera across entire supplied strip to exercise every texture's decode/eviction.
	for x in range(0,2881,32):
		scene.camera.position=scene.origin+Vector2(x,512)
		scene.update_chunks()
	check(scene.load_events>=12 and scene.unload_events>0,"Streaming loads all chunks and evicts outside window")
	report.streaming={"peak_resident_chunks":scene.peak_count,"peak_rgba_bytes":scene.peak_bytes,"peak_rgba_mib":scene.peak_bytes/1048576.0,"loads":scene.load_events,"unloads":scene.unload_events,"viewport":[1280,720],"zoom":1,"margin":128,"measurement":"Decoded RGBA estimate only, not VRAM or process peak"}
	scene.joystick.set_position_input(scene.joystick.size/2+Vector2(62,0))
	check(scene.touch_direction.is_equal_approx(Vector2.RIGHT),"Current joystick full deflection reaches unit speed")
	scene.joystick.reset()
	check(scene.touch_direction==Vector2.ZERO,"Joystick release resets movement")
	report.failures=failures
	FileAccess.open("res://results/headless.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
