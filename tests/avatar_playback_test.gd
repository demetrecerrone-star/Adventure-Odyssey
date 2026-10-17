extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("AVATAR TEST FAILED: " + description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character-outfits/manifest.json"))
	var count := 0
	for base in manifest.bases:
		for selected_class in manifest.bases[base].classes:
			count += 1
			var avatar = preload("res://src/layered_avatar.gd").new()
			root.add_child(avatar)
			check(avatar.configure(base, selected_class), "Real dressed outfit loads")
			check(avatar.suggested_speed == 60, "Calibrated movement speed loaded")
			for direction in range(4):
				avatar.advance(direction, false, 0)
				check(avatar.body.frame == direction and avatar.armor.frame == direction, "Idle facing matches both layers")
				var pair: Dictionary = avatar.outfit.walk[["down", "left", "right", "up"][direction]]
				var frame_count := int(pair.frames)
				var fps := float(pair.fps)
				check((frame_count == 6 and fps == 9) if base == "male" and selected_class == "Warrior" else (frame_count == 8 and fps == 16), "Approved bounded pilot or existing eight-phase manifest")
				avatar.advance(direction, true, 0)
				for phase in range(frame_count):
					check(avatar.body.frame == phase and avatar.armor.frame == phase, "Manifest phase shared by body and outfit")
					check(avatar.body.hframes == frame_count and avatar.armor.hframes == frame_count, "Frame grid follows manifest")
					avatar.advance(direction, true, 1.0 / fps)
				check(avatar.body.frame == 0 and avatar.armor.frame == 0, "Cycle wraps after the manifest duration")
				avatar.advance(direction, false, 0)
				check(avatar.body.frame == direction and avatar.armor.frame == direction, "Stopping restores dressed idle")
			avatar.queue_free()
			await process_frame
	check(count > 0, "At least one real paired outfit tested")
	print("AVATAR PLAYBACK: %d outfits; %d checks; failures: %d" % [count, checks, failures])
	quit(1 if failures else 0)
