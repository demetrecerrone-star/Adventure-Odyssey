extends Control
signal exited
const Save = preload("res://src/bedroom_save.gd")
const Creator = preload("res://src/creator/creator_panel.gd")
const ROOM_SIZE = Vector2(1536, 1024)
const PLAYER_SPEED_MULTIPLIER := 1.5
var state = Save.new()
var stage: Node2D
var actor: Node2D
var player := Vector2(570, 650)
var wake_spawn := Vector2(625, 700)
var facing := 0
var target := Vector2.ZERO
var moving_to_target := false
var sleeping := false
var overlay: Control
var message: Label
var interact_button: Button
var joystick: Control
var status: Label
var prop_nodes := {}
var prop_rects := {"bed":Rect2(270, 380, 310, 315), "chest":Rect2(990, 445, 240, 100), "mirror":Rect2(850, 385, 133, 35)}
var anchors := {"bed":Vector2(590, 670), "chest":Vector2(1110, 585), "mirror":Vector2(925, 475), "door":Vector2(760, 395)}
var touch_direction := Vector2.ZERO
var movement_speed := 60.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/body.ttf")
	theme.default_font_size = 18
	var backdrop := ColorRect.new()
	backdrop.color = Color("111722")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	stage = Node2D.new()
	stage.z_index = 0
	add_child(stage)
	var plate := Sprite2D.new()
	plate.name = "PaintedRoomPlate"
	plate.centered = false
	if ResourceLoader.exists("res://assets/bedroom/room.png"):
		plate.texture = load("res://assets/bedroom/room.png")
		plate.scale = ROOM_SIZE / plate.texture.get_size()
	stage.add_child(plate)
	_load_layout()
	for id in prop_rects.keys():
		var prop := Sprite2D.new()
		prop.name = id.capitalize() + "Layer"
		prop.centered = false
		if ResourceLoader.exists("res://assets/bedroom/" + id + ".png"):
			prop.texture = load("res://assets/bedroom/" + id + ".png")
			# Full registered layer canvases share the room plate coordinate system.
			prop.scale = ROOM_SIZE / prop.texture.get_size()
		prop.z_index = int(prop_rects[id].end.y)
		stage.add_child(prop)
		prop_nodes[id] = prop
	for decoration in [{"id":"rug", "depth":1}, {"id":"pictures", "depth":2}]:
		var asset_path: String = "res://assets/bedroom/" + decoration.id + ".png"
		if ResourceLoader.exists(asset_path):
			var art := Sprite2D.new()
			art.name = decoration.id.capitalize() + "Layer"
			art.centered = false
			art.texture = load(asset_path)
			art.scale = ROOM_SIZE / art.texture.get_size()
			art.z_index = decoration.depth
			stage.add_child(art)
	actor = preload("res://src/layered_avatar.gd").new()
	actor.name = "Player"
	actor.scale = Vector2.ONE * 1.05
	stage.add_child(actor)
	var top := HBoxContainer.new()
	top.z_index = 2000
	top.position = Vector2(18, 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var back := button("Save & title", top)
	back.pressed.connect(_exit)
	var inventory_button := button("Bag", top)
	inventory_button.pressed.connect(func():
		if not sleeping and not state.character.is_empty() and not is_instance_valid(overlay):
			open_chest(false)
	)
	status = label("Local guest adventure • Bedroom", top)
	message = label("", self)
	message.z_index = 2000
	message.position = Vector2(24, 76)
	message.add_theme_color_override("font_color", Color("fff0c7"))
	var bottom := HBoxContainer.new()
	bottom.z_index = 2000
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.position = Vector2(-430, -78)
	bottom.size = Vector2(410, 60)
	add_child(bottom)
	interact_button = button("Interact [E]", bottom)
	interact_button.pressed.connect(interact)
	joystick = preload("res://src/touch_joystick.gd").new()
	joystick.name = "TouchJoystick"
	joystick.z_index = 2000
	add_child(joystick)
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 24
	joystick.offset_top = -184
	joystick.offset_right = 188
	joystick.offset_bottom = -20
	joystick.direction_changed.connect(func(value: Vector2): touch_direction = value)
	resized.connect(_layout)
	_layout()
	if state.character.is_empty():
		if state.load_saved():
			_start_character()
		elif not state.error.is_empty() or FileAccess.file_exists(state.path):
			message.text = "Your local save needs recovery. It has not been overwritten."
			joystick.hide()
		else:
			open_creator(false)
	else:
		_start_character()
func label(text: String, parent: Node) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override("font_color", Color("f4ead8"))
	result.add_theme_color_override("font_shadow_color", Color.BLACK)
	result.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(result)
	return result
func button(text: String, parent: Node) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(64, 54)
	# Godot's mouse emulation only supplies a primary pointer. Let additional
	# fingers operate room buttons while the primary finger owns the joystick.
	result.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.index > 0:
			if event.pressed and not event.canceled and not result.disabled:
				result.set_meta("touch_owner", event.index)
			elif result.get_meta("touch_owner", -1) == event.index:
				result.remove_meta("touch_owner")
				if not event.canceled and not result.disabled and Rect2(Vector2.ZERO, result.size).has_point(event.position):
					result.pressed.emit()
			result.accept_event()
	)
	parent.add_child(result)
	return result
func _layout() -> void:
	if not is_instance_valid(stage):
		return
	var factor := minf(size.x / ROOM_SIZE.x, size.y / ROOM_SIZE.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - ROOM_SIZE * factor) * 0.5
	if is_instance_valid(overlay):
		overlay.size = size
func _start_character() -> void:
	actor.configure(state.character.base, state.character["class"], state.character)
	movement_speed = actor.suggested_speed * PLAYER_SPEED_MULTIPLIER
	sleeping = false
	player = wake_spawn
	actor.visible = actor.artwork_ready
	message.text = "Move with the joystick or WASD / arrows. Your chest holds supplies."
	status.text = state.character.username + " • Local save • Appearance art in progress"
	_update_actor()
func can_stand(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, PackedVector2Array([Vector2(235, 385), Vector2(1305, 385), Vector2(1455, 925), Vector2(80, 925)])):
		return false
	for rect in prop_rects.values():
		if rect.grow(16).has_point(point):
			return false
	return true
func move_player(delta: Vector2) -> void:
	# Resolve axes independently to slide along furniture; small steps prevent tunnelling.
	var steps := maxi(1, int(ceil(delta.length() / 8)))
	var step := delta / steps
	for _i in range(steps):
		if can_stand(player + Vector2(step.x, 0)):
			player.x += step.x
		if can_stand(player + Vector2(0, step.y)):
			player.y += step.y
	_update_actor()
func _update_actor() -> void:
	actor.position = player
	actor.z_index = int(player.y)
func nearest_prop() -> String:
	var result := ""
	var distance := 135.0
	for id in anchors:
		var current: float = player.distance_to(anchors[id])
		if current < distance:
			distance = current
			result = id
	return result
func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	interact_button.disabled = sleeping or is_instance_valid(overlay) or nearest_prop().is_empty()
	if sleeping or is_instance_valid(overlay) or state.character.is_empty():
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))) + touch_direction
	if direction.length() > 0:
		moving_to_target = false
	elif moving_to_target:
		direction = target - player
		if direction.length() < 8:
			moving_to_target = false
			direction = Vector2.ZERO
	var previous_position := player
	if direction.length() > 0:
		facing = (2 if direction.x > 0 else 1) if absf(direction.x) > absf(direction.y) else (0 if direction.y > 0 else 3)
		move_player(direction.limit_length(1.0) * movement_speed * minf(delta, 0.05))
	# Keep the original stride distance at the faster speed, including analog
	# input, blocked movement and the frame-time cap used by movement above.
	var distance_moved := player.distance_to(previous_position)
	actor.advance(facing, distance_moved > 0, distance_moved / actor.suggested_speed)
	var id := nearest_prop()
	interact_button.text = (id.capitalize() + " [E]") if not id.is_empty() else "Walk closer"
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_instance_valid(overlay) and not sleeping:
		target = stage.to_local(event.position)
		moving_to_target = can_stand(target)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			interact()
		elif event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay):
				cancel_overlay()
			else:
				_exit()
func interact() -> void:
	if sleeping or is_instance_valid(overlay):
		return
	match nearest_prop():
		"mirror": open_creator(true)
		"chest": open_chest()
		"bed": message.text = "Your own bed. You are rested and ready for the day."
		"door": message.text = "The town beyond this door is a future chapter. Your bedroom is ready to explore."
func open_creator(mirror: bool) -> void:
	if is_instance_valid(overlay):
		return
	_reset_movement()
	var creator = Creator.new()
	creator.local_guest_mode = true
	creator.mirror_mode = mirror
	if mirror:
		creator.draft = state.draft_from(state.character)
	creator.dismissed.connect(func():
		_close_overlay()
		if state.character.is_empty(): exited.emit()
	)
	creator.character_submitted.connect(func(payload):
		var ok: bool = state.apply_appearance(payload) if mirror else state.create(payload)
		if not ok:
			creator.notice.text = state.error if not state.error.is_empty() else "Could not save that selection."
			return
		_close_overlay()
		if mirror:
			actor.configure(state.character.base, state.character["class"], state.character)
			message.text = "Appearance saved locally. Your base, class and username are unchanged."
		else:
			_start_character()
	)
	creator.z_index = 2100
	overlay = creator
	add_child(creator)
	creator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null
	_reset_movement()
func _reset_movement() -> void:
	touch_direction = Vector2.ZERO
	moving_to_target = false
	if is_instance_valid(joystick):
		joystick.reset()
func open_chest(show_storage: bool = true) -> void:
	_close_overlay()
	overlay = Control.new()
	overlay.z_index = 2100
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	label(("STORAGE CHEST" if show_storage else "BAG") + " • Saved on this device", box)
	label("Armor: " + state.character["class"] + " starting outfit", box)
	label("Equipped: " + (Save.ITEMS[state.equipped_weapon] if not state.equipped_weapon.is_empty() else "None"), box)
	if not state.equipped_weapon.is_empty():
		var unequip := button("Unequip weapon", box)
		unequip.pressed.connect(func():
			if not state.unequip(): message.text = state.error
			open_chest(show_storage)
		)
	if not show_storage and state.bag.values().all(func(count): return count == 0):
		label("Your bag is empty. Collect supplies from your storage chest.", box)
	for item in Save.ITEMS:
		if state.bag[item] == 0 and (not show_storage or state.chest[item] == 0):
			continue
		label(("%s    Bag: %d    Chest: %d" % [Save.ITEMS[item], state.bag[item], state.chest[item]]) if show_storage else ("%s    Bag: %d" % [Save.ITEMS[item], state.bag[item]]), box)
		var row := HBoxContainer.new()
		box.add_child(row)
		for deposit in ([true, false] if show_storage else []):
			var control := button("Store one" if deposit else "Take one", row)
			control.disabled = (state.bag[item] if deposit else state.chest[item]) <= 0
			control.pressed.connect(func():
				if not state.transfer(item, deposit):
					message.text = state.error
				open_chest(show_storage)
			)
		if Save.Inventory.can_equip(item, state.character["class"]):
			var equip_button := button("Equip", row)
			equip_button.disabled = state.bag[item] == 0 or not state.equipped_weapon.is_empty()
			equip_button.pressed.connect(func():
				if not state.equip(item): message.text = state.error
				open_chest(show_storage)
			)
	var close := button("Close", box)
	close.pressed.connect(_close_overlay)
	close.grab_focus()
func _exit() -> void:
	if not state.character.is_empty() and not state.save():
		message.text = state.error
		return
	exited.emit()
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_movement()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(overlay):
			cancel_overlay()
		else:
			_exit()

func cancel_overlay() -> void:
	_close_overlay()
	if state.character.is_empty():
		exited.emit()

func _load_layout() -> void:
	var path := "res://assets/bedroom/runtime-layout.json"
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	var spawn: Array = data.get("wake_spawn", [625, 700])
	if spawn.size() == 2:
		wake_spawn = Vector2(spawn[0], spawn[1])
	for id in data.get("collisions", {}):
		var rect: Array = data.collisions[id]
		if rect.size() == 4:
			prop_rects[id] = Rect2(rect[0], rect[1], rect[2], rect[3])
	for id in data.get("interactions", {}):
		var point: Array = data.interactions[id]
		if point.size() == 2:
			anchors[id] = Vector2(point[0], point[1])
