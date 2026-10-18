extends "res://src/tutorial_dialogue.gd"
# Read-only upgrade selection. Only the owning scene may request Save's transaction.
signal confirm_requested
var save_state
var selected := false
var eligible := false
var select_button: Button
var confirm_button: Button
func _render() -> void:
 title_label.text = "Blacksmith upgrade"
 close_button.text = "Back"
 body_label.text = "Select your carried starter weapon, then confirm its free +1 lesson upgrade. The blacksmith supplies the materials."
 objective_label.text = "No gold is charged. The +1 upgrade adds 1 damage to your basic strike."
 notice_label.text = ""
 for child in choices.get_children():
  choices.remove_child(child); child.queue_free()
 var weapon_id:String = save_state.Inventory.starter_weapon(save_state.character["class"])
 var carried := false
 var level := 0
 for item in save_state.get_item_instances(weapon_id):
  if item.source == "starter":
   carried = item.container in ["bag","equipped_weapon"]
   level = int(item.upgrade_level)
 eligible = carried and level == 0 and save_state.tutorial.stage == "upgrade_blacksmith"
 select_button = _button("Select: %s  +%d → +1" % [save_state.ITEMS[weapon_id],level],choices)
 select_button.name = "SelectTutorialWeapon"
 select_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 select_button.disabled = not eligible
 select_button.pressed.connect(select_weapon)
 confirm_button = _button("Confirm free +1 upgrade",choices)
 confirm_button.name = "ConfirmTutorialUpgrade"
 confirm_button.disabled = true
 confirm_button.pressed.connect(confirm_upgrade)
 if not carried: notice_label.text = "Collect your starter weapon from your home chest first."
 elif level > 0: notice_label.text = "Your starter weapon already has its +1 lesson upgrade."
 elif not eligible: notice_label.text = "Speak to the blacksmith during the guild's upgrade lesson first."
 scroll.scroll_vertical = 0
func select_weapon() -> void:
 if not eligible or pending: return
 selected = true
 select_button.text = select_button.text.replace("Select:","Selected:")
 confirm_button.disabled = false
func confirm_upgrade() -> void:
 if not eligible or not selected or pending: return
 set_pending(true)
 confirm_requested.emit()
func show_error(message: String) -> void:
 super.show_error(message)
 select_button.disabled = not eligible
 confirm_button.disabled = not eligible or not selected
