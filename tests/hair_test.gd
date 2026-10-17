extends SceneTree
var checks := 0
var failures := 0
const Catalog = preload("res://src/creator/catalog.gd")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HAIR: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for base in ["male", "female"]:
		for selected_class in Catalog.CLASSES:
			var avatar = preload("res://src/layered_avatar.gd").new()
			root.add_child(avatar)
			for id in Catalog.hair_ids(base):
				avatar.configure(base,selected_class,{"hair":id,"hair_color":"Auburn","skin":"blue","eyes":"Green"})
				check(avatar.hair_renderer.ready, "Fitted style exists: " + id)
				check(avatar.hair_renderer.rear.get_index() < avatar.body.get_index(), "Rear hair is behind body")
				check(avatar.hair_renderer.front.get_index() > avatar.armor.get_index(), "Front hair is over outfit")
				check(avatar.hair_renderer.front.material != avatar.body.material and avatar.armor.material == null, "Hair color is isolated")
				for direction in range(4):
					avatar.advance(direction,false,0)
					check(avatar.hair_renderer.ready and avatar.hair_renderer.front.frame == direction, "All four idle directions")
					for phase in range(8):
						avatar.advance(direction,true,0.0625)
						check(avatar.hair_renderer.ready, "Walking hair is available")
						check(avatar.hair_renderer.front.frame == avatar.body.frame and avatar.hair_renderer.rear.frame == avatar.body.frame, "Head motion stays paired")
						check(avatar.hair_renderer.front.hframes == avatar.body.hframes, "Hair atlas matches real frame count")
			for color in Catalog.HAIR_COLORS:
				avatar.configure(base,selected_class,{"hair":base+"_hair_01","hair_color":color})
				check(avatar.hair_renderer.front.material.get_shader_parameter("hair_color") == Color(avatar.hair_renderer.COLORS[color]), "Selected hair color reaches shader")
			avatar.configure(base,selected_class,{"hair":("female" if base == "male" else "male")+"_hair_01"})
			check(not avatar.hair_renderer.ready and not avatar.hair_renderer.front.visible, "Opposite catalog never leaks")
			check(avatar.artwork_ready, "Unavailable hair never hides body/outfit")
			avatar.configure(base,selected_class,{"hair":base+"_hair_01"})
			avatar.hair_renderer.entry.idle.frames=7
			avatar.advance(0,false,0)
			check(not avatar.hair_renderer.ready and not avatar.hair_renderer.rear.visible, "Malformed hair atlas fails closed")
			avatar.queue_free()
			await process_frame
	print("HAIR: %d checks; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
