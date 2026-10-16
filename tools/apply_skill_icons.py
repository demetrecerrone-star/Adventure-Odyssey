#!/usr/bin/env python3
"""Install game-ready skill icons, compact mobile labels and cooldown overlays.

Run after apply_class_skills.py. Does not change the eighteen original
starter skill mechanics, AO app icon, or future mentor progression.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(before,after):
    global s
    hits=s.count(before)
    if hits!=1:
        raise SystemExit(f"SKILL ICON PATCH ERROR ({hits}): {before[:96]!r}")
    s=s.replace(before,after,1)

rep('''		_button(hud,name,510+slot*169,579,165,60,_use_starting_skill.bind(slot))
		# Long names must remain fully visible on a phone landscape screen.
		for child in hud.get_children():
			if child is Button and child.text==name:
				child.add_theme_font_size_override("font_size",18)''',
'''		_button(hud,name,510+slot*169,579,165,60,_use_starting_skill.bind(slot))
		# Retain Button.text for accessibility and earlier gameplay tests.
		# Render a separate SVG icon and fitted two-line caption.
		for child in hud.get_children():
			if child is Button and child.text==name:
				_configure_skill_icon_button(child,slot,str(skills[slot]["name"]))''')
rep('''	_tick_starting_skill_effects(delta)
	var axis=movement+_key_axis()''',
'''	_tick_starting_skill_effects(delta)
	_refresh_skill_icon_cooldowns()
	var axis=movement+_key_axis()''')
s+=r'''
# -- Class skill icons and per-slot cooldown readability -----------------------
func _configure_skill_icon_button(button:Button,slot:int,full_name:String)->void:
	button.name="SkillSlot%d" % slot
	var icon_path:String="res://assets/skills/%s_%s.svg" % [str(data.get("class","Warrior")).to_lower(),full_name.to_lower().replace(" ","_")]
	var icon_texture:Texture2D=load(icon_path) as Texture2D
	if icon_texture==null:
		push_error("Class skill icon missing or not imported: "+icon_path)
		return
	var artwork=TextureRect.new()
	artwork.name="SkillIcon"
	artwork.texture=icon_texture
	artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.position=Vector2(5,5)
	artwork.size=Vector2(50,50)
	artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(artwork)
	var caption=Label.new()
	caption.name="SkillName"
	caption.text=full_name.to_upper().replace(" ","\n")
	caption.position=Vector2(57,3)
	caption.size=Vector2(104,54)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",15)
	caption.add_theme_color_override("font_color",Color("#fff0ca"))
	caption.add_theme_color_override("font_outline_color",Color("#101c2d"))
	caption.add_theme_constant_override("outline_size",3)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	var cooldown=Label.new()
	cooldown.name="Cooldown"
	cooldown.position=Vector2(5,5)
	cooldown.size=Vector2(50,50)
	cooldown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cooldown.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	cooldown.add_theme_font_size_override("font_size",23)
	cooldown.add_theme_color_override("font_color",Color.WHITE)
	cooldown.add_theme_color_override("font_outline_color",Color("#080e19"))
	cooldown.add_theme_constant_override("outline_size",5)
	cooldown.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(cooldown)
	button.tooltip_text="%s | %.1fs cooldown | unlocked at level 1" % [full_name,float(_starter_skills()[slot]["cd"])]
	# Preserve button text for prior regression tests and input accessibility.
	# Draw only the overlay label to prevent clipping on mobile.
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		button.add_theme_color_override(key,Color.TRANSPARENT)
	_refresh_skill_icon_cooldowns()

func _refresh_skill_icon_cooldowns()->void:
	if hud==null or not is_instance_valid(hud):return
	for slot in range(3):
		var button:Button=hud.get_node_or_null("SkillSlot%d" % slot) as Button
		if button==null:continue
		var artwork:TextureRect=button.get_node_or_null("SkillIcon") as TextureRect
		var counter:Label=button.get_node_or_null("Cooldown") as Label
		if artwork==null or counter==null:continue
		var remaining:float=skill_cooldowns[slot]
		artwork.modulate=Color(0.47,0.50,0.56,0.80) if remaining>0.0 else Color.WHITE
		counter.text=str(int(ceil(remaining))) if remaining>0.0 else ""
'''
p.write_text(s,encoding="utf-8")
print("AO SKILL ICONS PATCH OK: 18 icons, phone labels and live cooldowns.")
