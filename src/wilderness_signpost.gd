extends Node2D
# Readable road-side wayfinding, not a collider or an interaction gate.
var text := ""
var hero := Vector2.ZERO
const FONT = preload("res://assets/fonts/body.ttf")
func _draw() -> void:
 if position.distance_to(hero)>650: return
 var width := maxf(180,FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x+30)
 draw_line(Vector2(0,8),Vector2(0,48),Color("61492f"),9,true)
 var board := Rect2(-width*0.5,-24,width,40)
 draw_style_box(preload("res://src/ui/ornate_panel.gd").make_button_style(),board)
 draw_string(FONT,Vector2(-width*0.5+15,4),text,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("35291d"))
