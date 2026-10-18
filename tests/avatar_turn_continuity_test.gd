extends SceneTree
var checks := 0
var failures := 0
const Avatar = preload("res://src/layered_avatar.gd")
const Catalog = preload("res://src/creator/catalog.gd")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TURN CONTINUITY: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for base in ["male", "female"]:
		for cls in Catalog.CLASSES:
			var avatar = Avatar.new()
			root.add_child(avatar)
			check(avatar.configure(base, cls, {"hair":base + "_hair_11", "skin":"deep", "eyes":"Green"}), "Identity loads")
			for armed in [false, true]:
				avatar.set_equipped_weapon(cls.to_lower() + "_01_weapon" if armed else "")
				for source in range(4):
					for target in range(4):
						if source == target: continue
						for phase in range(6):
							avatar.advance(source, false, 0)
							var time := (phase + 0.37) / 9.0
							avatar.advance(source, true, time)
							avatar.advance(target, true, 0)
							check(is_equal_approx(avatar.elapsed, time), "A turn retains fractional stride progress")
							check(avatar.body.frame == phase and avatar.armor.frame == phase, "Body and armor retain stride phase on every turn")
							check(avatar.facing == target and avatar.current_animation == "walk_" + ["down", "left", "right", "up"][target], "Facing responds immediately")
							check(avatar.palette_ready and avatar.hair_renderer.ready, "Appearance stays active")
							check(avatar.weapon_front.visible == armed and avatar.weapon_back.visible == armed, "Equipment visibility follows saved choice")
							if armed and not (base == "male" and cls == "Warrior" and target == 1):
								check(avatar.weapon_front.frame == phase and avatar.weapon_back.frame == phase, "Dedicated weapon layers follow retained phase")
							avatar.advance(target, true, 0.7 / 9.0)
							check(avatar.body.frame == (phase + 1) % 6, "Turning retains sub-frame progress for the next drawing")
			# Stress steering at 36Hz: direction changes faster than drawings.
			avatar.advance(0, false, 0)
			for tick in range(72):
				avatar.advance(tick % 4, true, 1.0 / 36.0)
				check(is_equal_approx(avatar.elapsed, (tick + 1) / 36.0), "Repeated steering cannot restart or stall stride time")
			avatar.advance(2, false, 0)
			check(avatar.current_animation == "idle" and avatar.body.frame == 2 and avatar.elapsed == 0, "Stopping restores exact directional idle")
			avatar.advance(1, true, 0)
			check(avatar.body.frame == 0 and avatar.elapsed == 0, "A fresh walk still starts on the approved first drawing")
			avatar.configure(base, cls)
			check(avatar.current_animation == "idle" and avatar.elapsed == 0, "Reconfiguration clears prior walk state")
			avatar.queue_free()
			await process_frame
	# Fallback sets can have different frame counts/cadence. Preserve normalized
	# progress rather than interpreting the old seconds in the new cycle.
	var mixed = Avatar.new()
	root.add_child(mixed)
	mixed.configure("male", "Warrior")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character-outfits/manifest.json"))
	mixed.outfit.walk.right = manifest.bases.male.classes.Warrior.walk.right
	mixed.painted_directions.erase("right")
	mixed.advance(0, false, 0)
	mixed.advance(0, true, 0.25)
	mixed.advance(2, true, 0)
	var fallback: Dictionary = mixed.outfit.walk.right
	var expected: float = 0.375 * float(fallback.frames) / float(fallback.fps)
	check(is_equal_approx(mixed.elapsed, expected), "Mixed drawing counts preserve normalized progress")
	mixed.advance(0, true, 0)
	check(is_equal_approx(mixed.elapsed, 0.25), "Return from fallback preserves normalized progress")
	mixed.queue_free()
	await process_frame
	print("AVATAR TURN CONTINUITY: %d checks; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
