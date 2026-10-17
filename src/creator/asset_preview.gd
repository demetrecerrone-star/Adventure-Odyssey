extends VBoxContainer
# Aligned RGBA layers must already be authored in angled top-down 2.5D.
# We never distort side-view art into a purported finished preview.
var manifest: Dictionary = {}
var allow_test_fixtures := false
var allow_starter_outfit := true
var status: Label
var stage: Control
func _ready() -> void:
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(220, 250)
	add_child(stage)
func update_preview(draft) -> void:
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	var entry: Dictionary = manifest.get("bases", {}).get(draft.base, {})
	var layers: Dictionary = entry.get("layers", {})
	# Each palette must be baked or composited with an approved mask by the asset
	# pipeline. Global tinting would incorrectly recolor underwear and eye whites.
	var hair_key: String = draft.hair + "/" + draft.hair_color.to_lower()
	var keys := ["rear_hair/" + hair_key, "body/" + draft.skin, "eyes/" + draft.eyes.to_lower(), "front_hair/" + hair_key]
	var fixture: bool = entry.get("status", "") == "test_fixture" and allow_test_fixtures
	if (entry.get("status", "missing") != "approved" and not fixture) or entry.get("view", "") != "angled_top_down_2_5d":
		if allow_starter_outfit and _starter_preview(draft):
			return
		status.text = "Live preview unavailable: approved %s body and layered artwork are pending. Selections below are editable." % draft.base
		return
	for key in keys:
		if not layers.has(key) or not ResourceLoader.exists(str(layers[key])):
			status.text = "Live preview incomplete: missing approved layer %s. No finished character is shown." % key
			return
	var textures: Array[Texture2D] = []
	for key in keys:
		var asset = load(layers[key])
		if not asset is Texture2D:
			status.text = "Live preview incomplete: invalid texture layer."
			return
		textures.append(asset)
	if textures[0].get_size() != Vector2(256, 256):
		status.text = "Live preview incomplete: expected a 256×256 aligned frame."
		return
	for texture in textures:
		if texture.get_size() != textures[0].get_size():
			status.text = "Live preview incomplete: layer canvases do not align."
			return
	for texture in textures:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(image)
	status.text = "TEST FIXTURE ONLY • Not character artwork" if fixture else "Approved static appearance preview. Animation is not integrated."

func _starter_preview(draft) -> bool:
	var avatar = preload("res://src/layered_avatar.gd").new()
	stage.add_child(avatar)
	if not avatar.configure(draft.base, draft.character_class):
		stage.remove_child(avatar)
		avatar.queue_free()
		return false
	avatar.position = Vector2(110, 240)
	avatar.scale = Vector2.ONE * 0.9
	status.text = "Dressed starter preview. Selected hairstyles, eye colors and skin palettes are not rendered yet."
	return true
