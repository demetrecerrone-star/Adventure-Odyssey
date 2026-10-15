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
    # Fit the ENTIRE approved painting. Cover-scaling clipped the outer beams
    # and front threshold on screens with a wider-than-art aspect ratio.
    var painted_size:Vector2=background.texture.get_size()
    var factor:float=minf(2048.0/painted_size.x,1280.0/painted_size.y)
    background.scale=Vector2.ONE*factor
    background.position=(Vector2(2048,1280)-painted_size*factor)*0.5
    background.z_index=-10
    add_child(background)
