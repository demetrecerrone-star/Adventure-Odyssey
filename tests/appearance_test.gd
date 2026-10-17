extends SceneTree
var checks := 0
var failures := 0
const Catalog = preload("res://src/creator/catalog.gd")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("APPEARANCE TEST FAILED: " + description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for base in ["male", "female"]:
		for selected_class in Catalog.CLASSES:
			var avatar = preload("res://src/layered_avatar.gd").new()
			root.add_child(avatar)
			for skin in Catalog.SKINS:
				check(avatar.configure(base, selected_class, {"skin":skin.id, "eyes":"Violet"}), "Dressed outfit remains available")
				check(avatar.palette_ready, "Idle palette mask is available")
				check(avatar.body.material == avatar.palette_material and avatar.armor.material == null, "Only body receives pigment material")
				check(avatar.palette_material.get_shader_parameter("skin_color") == Color(skin.color), "Selected skin reaches renderer")
				for direction in range(4):
					avatar.advance(direction, true, 0.125)
					check(avatar.palette_ready, "Walk palette mask matches actual atlas")
					var mask: Texture2D = avatar.palette_material.get_shader_parameter("appearance_mask")
					check(mask.get_size() == avatar.body.texture.get_size(), "Mask follows paired animation dimensions")
					check(avatar.body.frame == avatar.armor.frame, "Palette does not disturb paired frame")
			for eyes in Catalog.EYES:
				avatar.configure(base, selected_class, {"skin":"blue", "eyes":eyes})
				check(avatar.palette_material.get_shader_parameter("eye_color") == Color(avatar.EYE_COLORS[eyes]), "Selected eye reaches renderer")
			avatar.queue_free()
			await process_frame
	var draft = preload("res://src/creator/character_draft.gd").new()
	draft.skin = "teal"
	draft.eyes = "Amber"
	var preview = preload("res://src/creator/asset_preview.gd").new()
	root.add_child(preview)
	preview.update_preview(draft)
	var shown = preview.stage.get_child(0)
	check(shown.appearance.skin == "teal" and shown.appearance.eyes == "Amber", "Creator uses same selected appearance contract")
	check(shown.hair_renderer.ready and preview.status.text.contains("hairstyle"), "Selected fitted hair is rendered in creator")
	preview.queue_free()
	await process_frame
	print("APPEARANCE: %d checks; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
