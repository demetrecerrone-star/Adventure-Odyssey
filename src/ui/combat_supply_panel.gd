extends "res://src/tutorial_dialogue.gd"
var supply_state
var fight
func configure_supplies(saved, model) -> void:
	supply_state = saved
	fight = model
	pending = false
	if is_node_ready(): _render()
func _render() -> void:
	if supply_state == null or fight == null: return
	title_label.text = "Field supplies"
	body_label.text = "HP %d / %d     MP %d / %d\nHealing: +40 HP. Mana: +25 MP. Shared cooldown: 3s.\nUsed potions stay consumed after retry or reload." % [fight.hp,fight.max_hp,int(fight.mana),int(fight.max_mana)]
	objective_label.text = "Full resource? No potion used. Mana recovers outside menus."
	_view = {"choices":[]}
	for child in choices.get_children():
		choices.remove_child(child); child.queue_free()
	for item in ["healing_potion","mana_potion"]:
		var count: int = supply_state.bag[item]
		var label_text := "Healing potion • %d in bag" % count if item == "healing_potion" else "Mana potion • %d in bag" % count
		var choice := _choice(item,label_text)
		_view.choices.append(choice)
		var button := _button(label_text,choices)
		button.name = "Use_" + item
		button.pressed.connect(_choose.bind(choice))
		button.disabled = pending or count <= 0 or fight.defeated or fight.potion_cooldown > 0 or (fight.hp >= fight.max_hp if item == "healing_potion" else fight.mana >= fight.max_mana)
	notice_label.text = "Potions ready in %.1f seconds. Close this panel to continue." % fight.potion_cooldown if fight.potion_cooldown > 0 else ""
