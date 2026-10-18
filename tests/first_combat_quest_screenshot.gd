extends SceneTree
const Progress = preload("res://src/tutorial_progress.gd")
const Dialogue = preload("res://src/tutorial_dialogue.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var view := Dialogue.new()
	root.add_child(view)
	var state := Progress.initial_state()
	var context := {"character_class":"Warrior", "item_id":"warrior_01_weapon", "from_level":0, "to_level":1, "supplies_consumed":true, "encounter_id":"south_meadow_slimes"}
	for index in range(Progress.STEPS.size() + 1):
		if index >= 9:
			for resolution in [Vector2i(1280,720), Vector2i(844,390)]:
				root.size = resolution
				view.configure("guild_receptionist", state, "Warrior")
				for tick in 4: await process_frame
				assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(view.close_button.get_global_rect()))
				for button in view.choices.get_children(): assert(button.size.y >= 48)
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png("res://screenshots/quest_%s_%d.png" % [state.stage, resolution.x]) == OK)
		if index == Progress.STEPS.size(): break
		var step: Dictionary = Progress.STEPS[index]
		context.encounter_id = "west_forest_patrol" if step.id == "forest_patrol_completed" else "south_meadow_slimes"
		var result := Progress.plan_event(state, step.id, "capture_%d" % index, context) if step.kind == "event" else Progress.plan_action(state, step.id, "capture_%d" % index, context)
		assert(result.ok)
		state = result.next_state
	print("GUILD QUEST SCREENSHOTS: %d native dialogue views saved" % ((Progress.STEPS.size()-8)*2))
	quit()
