extends SceneTree
# Auditable overview of the ORIGINAL pixel sprites, without repainting them.
# Columns = eight appearance variants. Every three rows = one facing direction
# (down / left / up / right); subrows show original frames 00, 01, 02.
const FACINGS = ["down", "left", "up", "right"]
const CELL_W = 148
const CELL_H = 158
const BODY_COUNT = 8
const FRAMES = 3
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var canvas = Image.create(BODY_COUNT * CELL_W, FACINGS.size() * FRAMES * CELL_H, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("#16222e"))
	var count := 0
	for facing_index in range(FACINGS.size()):
		for anim_index in range(FRAMES):
			for body_index in range(BODY_COUNT):
				var path: String = "res://assets/characters/base_variant_%02d/%s_%02d.png" % [body_index + 1, FACINGS[facing_index], anim_index]
				if not FileAccess.file_exists(path):
					push_error("MISSING ORIGINAL SPRITE: " + path)
					quit(1)
					return
				var original: Image = Image.load_from_file(path)
				if original == null or original.is_empty():
					push_error("COULD NOT LOAD ORIGINAL SPRITE: " + path)
					quit(1)
					return
				var dx: int = body_index * CELL_W
				var dy: int = (facing_index * FRAMES + anim_index) * CELL_H
				canvas.fill_rect(Rect2i(dx + 3, dy + 3, CELL_W - 6, CELL_H - 6), Color("#2c3d4e") if anim_index == 0 else Color("#263847"))
				var scale_factor: float = minf(116.0 / float(original.get_width()), 136.0 / float(original.get_height()))
				scale_factor = maxf(0.1, scale_factor)
				var scaled: Image = original.duplicate()
				scaled.resize(maxi(1,int(round(float(original.get_width()) * scale_factor))), maxi(1,int(round(float(original.get_height()) * scale_factor))), Image.INTERPOLATE_NEAREST)
				var at := Vector2i(dx + int((CELL_W - scaled.get_width()) / 2), dy + int((CELL_H - scaled.get_height()) / 2))
				canvas.blend_rect(scaled, Rect2i(Vector2i.ZERO,scaled.get_size()), at)
				count += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var output = "res://screenshots/ao_original_character_contact_sheet.png"
	if canvas.save_png(output) != OK:
		push_error("COULD NOT SAVE ORIGINAL CHARACTER CONTACT SHEET")
		quit(1)
		return
	if count != 96:
		push_error("EXPECTED 96 ORIGINAL CHARACTER FRAMES")
		quit(1)
		return
	print("ADVENTURE ODYSSEY ORIGINAL CHARACTER CONTACT SHEET: PASS / 96 frames / 8 bodies / 4 directions / 3 animations")
	print("CONTACT SHEET ORDER: columns 1-8 body variants; rows [down_00, down_01, down_02, left_00, left_01, left_02, up_00, up_01, up_02, right_00, right_01, right_02]")
	quit(0)
