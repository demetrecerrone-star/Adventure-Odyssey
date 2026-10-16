#!/usr/bin/env python3
"""Add non-disruptive, game-rendered enemy health/target/hit feedback.

Applied after the Thornbrook background patch. Four existing slime actors,
quest balance, saved stat points, house layout and Guild routines are unchanged.
"""
from pathlib import Path
game = Path("scripts/game.gd")
src = game.read_text(encoding="utf-8")
def rep(before: str, after: str) -> None:
    global src
    count = src.count(before)
    if count != 1:
        raise SystemExit(f"COMBAT FEEDBACK PATCH ANCHOR FAILED ({count}): {before[:125]!r}")
    src = src.replace(before, after, 1)

rep('''		mob["alive"]=true
		mobs.append(mob)''',
'''		mob["alive"]=true
		var indicator=Node2D.new()
		indicator.name="SlimeHealthIndicator"
		indicator.set_script(load("res://scripts/slime_combat_indicator.gd"))
		mob["node"].add_child(indicator)
		indicator.call("update_health",35,35)
		mob["indicator"]=indicator
		mobs.append(mob)''')

rep('''	var nearby = _nearest_npc()
	if current_map=="bedroom":''',
'''	if current_map=="forest":
		_update_slime_targeting()
	var nearby = _nearest_npc()
	if current_map=="bedroom":''')

rep('''	elif current_map=="forest":prompt.text="Attack nearby slimes!  |  Walk west to return"''',
'''	elif current_map=="forest":
		var target=_nearest_attackable_slime()
		prompt.text="ATTACK: Green Slime %d/%d HP" % [maxi(0,int(target["hp"])),int(target["max_hp"])] if not target.is_empty() else "Approach a slime to attack  |  West: Elmwatch"''')

rep('''	var best:Dictionary={}
	var dist=170.0
	for mob in mobs:
		if not mob["alive"]:continue
		var length=player.position.distance_to(mob["node"].position)
		if length<dist:
			best=mob
			dist=length
	if best.size()==0:
		hint_label.text="Move closer to a monster to attack."''',
'''	var best:Dictionary=_nearest_attackable_slime()
	if best.size()==0:
		hint_label.text="Move within attack range of a slime; follow its health bar."''')

rep('''	best["hp"]=int(best["hp"])-dmg
	hint_label.text="%d damage! Press ATTACK again after its short cooldown." % dmg''',
'''	best["hp"]=int(best["hp"])-dmg
	best["indicator"].call("update_health",int(best["hp"]),int(best["max_hp"]))
	_combat_popup(best["node"].position,"-%d" % dmg,Color("#ffe7a0"))
	hint_label.text="%d damage! Press ATTACK again after its short cooldown." % dmg''')

rep('''			if randf()<evade:
				hint_label.text="DODGE! Your Agility avoided the attack."
			else:
				data["hp"]=maxi(0,int(data["hp"])-5)''',
'''			if randf()<evade:
				_combat_popup(player.position,"DODGE",Color("#8ce7ee"))
				hint_label.text="DODGE! Your Agility avoided the attack."
			else:
				_combat_popup(player.position,"-5 HP",Color("#ff9a98"))
				data["hp"]=maxi(0,int(data["hp"])-5)''')

src += '''
# -- First forest combat feedback (visual-only), retained across screen transitions. --
func _nearest_attackable_slime()->Dictionary:
	if current_map!="forest" or player==null:return {}
	var best:Dictionary={}
	var dist:=170.0
	for mob in mobs:
		if not bool(mob.get("alive",false)):continue
		var delta:float=player.position.distance_to(mob["node"].position)
		if delta<dist:
			dist=delta
			best=mob
	return best

func _update_slime_targeting()->void:
	var target:Dictionary=_nearest_attackable_slime()
	for mob in mobs:
		if not mob["alive"]:continue
		var selected:bool=not target.is_empty() and target["node"]==mob["node"]
		var warning:bool=monster_timer>1.55 and player.position.distance_to(mob["node"].position)<105.0
		mob["indicator"].call("update_indicator",selected,warning)

func _combat_popup(at:Vector2,words:String,tint:Color)->void:
	if world==null or not is_instance_valid(world):return
	var label=Label.new()
	label.name="CombatFloat"
	label.text=words
	label.position=at+Vector2(-50,-130)
	label.size=Vector2(140,52)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",33)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_color_override("font_shadow_color",Color("#1b2630"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	world.add_child(label)
	var motion=create_tween()
	motion.tween_property(label,"position",label.position+Vector2(0,-75),0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(label,"modulate:a",0.0,0.7)
	motion.tween_callback(label.queue_free)
'''
game.write_text(src,encoding="utf-8")
print("COMBAT FEEDBACK PATCH OK: slime HP bars, nearest target, warning ring and floating hit numbers.")
