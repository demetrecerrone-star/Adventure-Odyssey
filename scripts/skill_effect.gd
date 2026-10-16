extends Node2D
# Lightweight animated vector combat effects, one pattern per named ability.
# Generated geometry, no external sprite sheets, no performance-heavy particles.
var ability:String=""
var from_here:Vector2=Vector2.ZERO
var direction:Vector2=Vector2.ZERO
var glow:Color=Color.WHITE
var age:float=0.0
var duration:float=0.48
var pattern:int=0

func configure(skill_name:String,origin:Vector2,destination:Vector2,color:Color)->void:
	ability=skill_name
	position=origin
	from_here=origin
	direction=destination-origin
	glow=color
	pattern=abs(int(skill_name.hash()))%6
	duration=0.62 if direction.length()<25.0 else 0.44
	queue_redraw()

func _process(delta:float)->void:
	age+=maxf(0.0,delta)
	if age>=duration:
		queue_free()
		return
	queue_redraw()

func _draw()->void:
	if duration<=0.0:return
	var phase:float=clampf(age/duration,0.0,1.0)
	var fade:Color=glow
	fade.a=1.0-phase
	var opacity:Color=Color(1.0,1.0,1.0,(1.0-phase)*0.26)
	var point:Vector2=direction*minf(1.0,phase*2.0)
	if direction.length()>25.0:
		draw_line(Vector2.ZERO,point,glow.darkened(0.20)*Color(1,1,1,1.0-phase),9.0,true)
		draw_circle(point,10.0+phase*7.0,fade)
		draw_circle(point,5.0+phase*3.0,Color(1,1,1,1.0-phase))
	var radius:float=22.0+phase*88.0
	if pattern==0: # slash: crossing sharp crescents
		draw_arc(Vector2.ZERO,radius,-1.15,1.2,36,fade,9.0,true)
		draw_line(Vector2(-radius*0.72,radius*0.44),Vector2(radius*0.74,-radius*0.42),fade,7.0,true)
	elif pattern==1: # defensive rings and eight sparks
		draw_circle(Vector2.ZERO,radius*0.8,opacity)
		draw_arc(Vector2.ZERO,radius,0.0,TAU,40,fade,5.0,true)
		for i in range(8):
			var theta:float=float(i)*TAU/8.0
			draw_line(Vector2.from_angle(theta)*radius*0.66,Vector2.from_angle(theta)*radius,fade,4.0,true)
	elif pattern==2: # clustered magic bolts
		draw_arc(Vector2.ZERO,radius*0.9,phase*4.0,phase*4.0+5.1,40,fade,4.0,true)
		for i in range(5):
			var theta:float=float(i)*TAU/5.0+phase*2.0
			draw_circle(Vector2.from_angle(theta)*radius*0.76,7.0,fade)
	elif pattern==3: # trap or leaf sigil
		for i in range(6):
			var angle:float=float(i)*TAU/6.0
			var start:Vector2=Vector2.from_angle(angle)*radius*0.2
			draw_line(start,Vector2.from_angle(angle)*radius,fade,5.0,true)
		draw_arc(Vector2.ZERO,radius*0.65,0,TAU,32,fade,3.0,true)
	elif pattern==4: # star-like pulse, suitable for holy and healing
		for i in range(4):
			var theta:float=float(i)*TAU/4.0
			draw_line(Vector2.from_angle(theta)*radius*0.1,Vector2.from_angle(theta)*radius,fade,7.0,true)
		draw_circle(Vector2.ZERO,13.0+phase*8.0,fade)
	else: # smoky curved vortex
		for i in range(3):
			var theta:float=float(i)*TAU/3.0+phase*2.0
			draw_arc(Vector2.from_angle(theta)*radius*0.25,radius*0.55,theta,theta+2.9,22,fade,5.0,true)
