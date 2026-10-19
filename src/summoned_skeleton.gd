extends Node2D
# Title-screen skeleton identity adapted into directional poses; rendering never applies damage.
const SHEET=preload("res://assets/monsters/summoned_skeleton/skeleton.png")
var sprite: Sprite2D
var poses: Array[AtlasTexture] = []
var moving:=false
var phase:=0.0
var direction:=0
var attack_flash:=0.0
func _ready() -> void:
 sprite=Sprite2D.new()
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 sprite.centered=false;sprite.scale=Vector2.ONE*0.52
 for bounds in RECTS:
  var atlas:=AtlasTexture.new();atlas.atlas=SHEET;atlas.region=Rect2(bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]);poses.append(atlas)
 add_child(sprite);hide()
func sync(encounter, active: bool) -> void:
 visible=active and encounter.summon_timer>0 and not encounter.defeated
 position=encounter.summon_position;z_index=int(position.y*0.4)
 moving=encounter.summon_moving;attack_flash=encounter.summon_attack_flash
 var face:Vector2=encounter.summon_facing
 if face.length_squared()>0.01:direction=(1 if face.x<0 else 2) if absf(face.x)>absf(face.y) else (3 if face.y<0 else 0)
 _pose();queue_redraw()
func _process(delta: float) -> void:
 if visible and moving:phase+=delta*8
 elif not moving:phase=0
 _pose()
func _pose() -> void:
 if not is_instance_valid(sprite):return
 var row:=0 if direction==0 else (2 if direction==3 else 1)
 var frame:=int(phase)%4 if moving else 0
 if attack_flash>0:
  row+=3;frame=2 if attack_flash>0.12 else 3
 sprite.flip_h=false
 # Each source pose has its own uncropped region. Anchor registration absorbs
 # atlas gutters so raised swords and feet never clip or jump between cells.
 var index:=row*4+frame
 sprite.texture=poses[index]
 var anchor:Vector2=ANCHORS[index]
 var region:Rect2=poses[index].region
 sprite.position=(region.position-anchor)*0.52
 sprite.scale=Vector2.ONE*0.52
 if direction==1:
  sprite.scale.x=-0.52
  sprite.position.x=-(region.position.x-anchor.x)*0.52
 sprite.set_meta("pose",Vector2i(frame,row))
func _draw() -> void:
 draw_set_transform(Vector2(0,-2),0,Vector2(1,0.35))
 draw_circle(Vector2.ZERO,24,Color(0.04,0.09,0.07,0.3))
 draw_arc(Vector2.ZERO,27,0,TAU,40,Color(0.56,0.85,0.72,0.65),2,true)

const RECTS := [[76, 63, 220, 245], [338, 63, 480, 246], [580, 67, 729, 246], [843, 65, 981, 246], [60, 310, 231, 503], [334, 310, 492, 505], [559, 310, 746, 503], [842, 310, 996, 505], [64, 567, 200, 760], [324, 566, 457, 759], [568, 567, 725, 760], [830, 567, 967, 760], [72, 831, 232, 1005], [325, 788, 464, 1004], [543, 828, 765, 1005], [811, 827, 992, 1004], [52, 1057, 234, 1238], [319, 1013, 468, 1243], [547, 1056, 816, 1243], [817, 1055, 995, 1238], [67, 1305, 228, 1491], [318, 1268, 483, 1492], [561, 1294, 742, 1490], [814, 1305, 994, 1486]]
const ANCHORS := [Vector2(151,245),Vector2(406,245),Vector2(657,245),Vector2(909,245),Vector2(145,504),Vector2(401,504),Vector2(657,504),Vector2(913,504),Vector2(132,760),Vector2(391,760),Vector2(644,760),Vector2(900,760),Vector2(140,1005),Vector2(396,1005),Vector2(652,1005),Vector2(908,1005),Vector2(140,1243),Vector2(396,1243),Vector2(652,1243),Vector2(908,1243),Vector2(140,1492),Vector2(396,1492),Vector2(652,1492),Vector2(908,1492)]
