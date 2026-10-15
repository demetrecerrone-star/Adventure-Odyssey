extends Node2D
const ART = "res://assets/home/approved_cottage_foyer.jpg"
var background:Sprite2D
func _ready()->void:
    background=Sprite2D.new()
    background.name="ApprovedFoyerBackground"
    background.centered=false
    background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    background.texture=load(ART)
    if background.texture==null:
        push_error("Missing approved cottage artwork")
        return
    var factor:float=maxf(2048.0/float(background.texture.get_width()),1280.0/float(background.texture.get_height()))
    background.scale=Vector2(factor,factor)
    background.position=Vector2((2048.0-float(background.texture.get_width())*factor)*0.5,(1280.0-float(background.texture.get_height())*factor)*0.5)
    add_child(background)
