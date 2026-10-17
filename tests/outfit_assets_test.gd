extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("OUTFIT TEST FAILED: " + description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "res://assets/character-outfits/manifest.json"
	check(FileAccess.file_exists(path), "Outfit manifest is packaged")
	for base in ["male", "female"]:
		for selected_class in preload("res://src/creator/catalog.gd").CLASSES:
			var avatar = preload("res://src/layered_avatar.gd").new()
			root.add_child(avatar)
			check(avatar.configure(base, selected_class), base + " " + selected_class + " has aligned body and actual armor")
			if avatar.artwork_ready:
				var armor_image: Image = avatar.armor.texture.get_image()
				if armor_image.is_compressed(): armor_image.decompress()
				for direction in range(4):
					var covered := 0
					for y in range(0, 256, 4):
						for x in range(direction * 256, (direction + 1) * 256, 4):
							if armor_image.get_pixel(x, y).a > 0.15: covered += 1
					check(covered > 40 and covered < 3500, "Armor layer contains visible clothing and transparent background")
					avatar.advance(direction, false, 0)
					check(avatar.body.frame == direction and avatar.armor.frame == direction and avatar.armor.texture != null, "Idle layer alignment")
					avatar.advance(direction, true, 0.25)
					check(avatar.armor.texture != null and avatar.body.frame == avatar.armor.frame, "Moving cannot expose unarmored body")
			avatar.queue_free()
			await process_frame
	for name in ["room", "bed", "bedside", "chest", "mirror", "dresser", "rug", "pictures", "chair", "bookshelf"]:
		var resource: String = "res://assets/bedroom/" + name + ".png"
		check(ResourceLoader.exists(resource), "Bedroom layer packaged: " + name)
	check(FileAccess.file_exists("res://assets/bedroom/runtime-layout.json"), "Runtime layout JSON packaged")
	print("OUTFIT ASSET CHECKS: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
