extends Node2D
# Named, lightweight effects for the original eighteen starters + six mentors.
# Drawn entirely in Godot; no incompatible sprite-sheet substitutions.
const ABILITY_PATTERNS={
	"Power Slash":"slash","Shield Bash":"impact","Battle Cry":"aura",
	"Aimed Shot":"projectile","Quick Volley":"volley","Snare Trap":"trap",
	"Firebolt":"projectile","Frost Nova":"nova","Arcane Barrier":"ward",
	"Raise Skeleton":"summon","Soul Bolt":"projectile","Life Drain":"drain",
	"Backstab":"slash","Shadowstep":"dash","Poison Blade":"slash",
	"Holy Strike":"impact","Divine Heal":"heal","Sacred Shield":"ward",
	"Earthshaker":"impact","Hunter's Mark":"mark","Meteor Burst":"nova",
	"Death Echo":"drain","Smoke Veil":"smoke","Consecration":"heal"
}
const KIND_PATTERNS={
	"cleave":"slash","stun":"impact","buff":"aura","ranged":"projectile",
	"volley":"volley","trap":"trap","burn":"projectile","nova":"nova",
	"barrier":"ward","summon":"summon","drain":"drain","backstab":"slash",
	"step":"dash","poison":"slash","holy":"impact","heal":"heal",
	"shield":"ward","advanced":"aura"
}
var ability:String=""
var from_here:Vector2=Vector2.ZERO
var direction:Vector2=Vector2.ZERO
var glow:Color=Color.WHITE
var age:float=0.0
var duration:float=0.58
var pattern:String="aura"

func configure(skill_name:String,origin:Vector2,destination:Vector2,color:Color,kind:String="")->void:
	ability=skill_name
	position=origin
	from_here=origin
	direction=destination-origin
	glow=color
	pattern=str(ABILITY_PATTERNS.get(skill_name,KIND_PATTERNS.get(kind,"aura")))
	age=0.0
	duration=0.75 if pattern in ["nova","ward","summon","trap","smoke"] else 0.52
	# No target yet: fire in front of the player instead of an invisible bolt.
	if direction.length()<10.0 and pattern in ["projectile","volley","dash"]:
		direction=Vector2.RIGHT*145.0
	queue_redraw()

func _process(delta:float)->void:
	age+=maxf(0.0,delta)
	if age>=duration:
		queue_free()
		return
	queue_redraw()

func _draw()->void:
	if duration<=0.0:return
	var t:float=clampf(age/duration,0.0,1.0)
	var fade:Color=glow
	fade.a=1.0-t
	var pale:Color=Color(1.0,1.0,1.0,(1.0-t)*0.75)
	var radius:float=16.0+82.0*t
	var point:Vector2=direction*minf(1.0,t*1.7)
	match pattern:
		"slash":
			draw_arc(Vector2.ZERO,radius,-1.15,1.25,28,fade,8.0,true)
			draw_line(Vector2(-radius*0.62,radius*0.50),Vector2(radius*0.7,-radius*0.36),pale,4.0,true)
		"impact":
			draw_circle(Vector2.ZERO,18.0+radius*0.32,Color(glow.r,glow.g,glow.b,(1.0-t)*0.25))
			draw_arc(Vector2.ZERO,radius,0,TAU,32,fade,6.0,true)
			for i in range(8):
				var a:float=TAU*float(i)/8.0
				draw_line(Vector2.from_angle(a)*radius*0.62,Vector2.from_angle(a)*radius,fade,5.0,true)
		"aura":
			for i in range(6):
				var a:float=TAU*float(i)/6.0
				draw_circle(Vector2.from_angle(a)*radius*0.66,8.0,fade)
			draw_arc(Vector2.ZERO,radius*0.75,0,TAU,32,fade,4.0,true)
		"projectile":
			draw_line(Vector2.ZERO,point,Color(glow.r,glow.g,glow.b,(1.0-t)*0.50),7.0,true)
			draw_circle(point,11.0+3.0*t,fade)
			draw_circle(point,4.0,pale)
		"volley":
			var tangent:Vector2=direction.normalized().orthogonal()*24.0
			for j in range(-1,2):
				draw_line(tangent*float(j),point+tangent*float(j),fade,4.0,true)
				draw_circle(point+tangent*float(j),6.0,pale)
		"trap":
			for i in range(4):
				var a:float=TAU*float(i)/4.0
				var b:float=TAU*float(i+1)/4.0
				draw_line(Vector2.from_angle(a)*radius,Vector2.from_angle(b)*radius,fade,5.0,true)
			draw_arc(Vector2.ZERO,radius*0.55,0,TAU,28,pale,3.0,true)
		"nova":
			draw_circle(Vector2.ZERO,radius*0.85,Color(glow.r,glow.g,glow.b,(1.0-t)*0.16))
			draw_arc(Vector2.ZERO,radius,0,TAU,50,fade,8.0,true)
			draw_arc(Vector2.ZERO,radius*0.55,0,TAU,40,pale,3.0,true)
		"ward":
			for i in range(6):
				var a:float=TAU*float(i)/6.0
				var b:float=TAU*float(i+1)/6.0
				draw_line(Vector2.from_angle(a)*radius,Vector2.from_angle(b)*radius,fade,6.0,true)
			draw_arc(Vector2.ZERO,radius*0.65,0,TAU,40,pale,3.0,true)
		"summon":
			for j in range(-2,3):
				var x:float=float(j)*15.0
				draw_line(Vector2(x,-radius),Vector2(x*0.6,radius*0.2),fade,5.0,true)
			draw_arc(Vector2.ZERO,radius*0.7,PI,TAU,30,pale,4.0,true)
		"drain":
			draw_line(Vector2.ZERO,point,fade,9.0,true)
			for i in range(3):
				var a:float=TAU*float(i)/3.0+t*3.0
				draw_circle(point+Vector2.from_angle(a)*(10.0+radius*0.2),5.0,pale)
		"dash":
			for i in range(4):
				var at:Vector2=direction*clampf(t*1.8-float(i)*0.18,0.0,1.0)
				draw_arc(at,14.0,-PI*0.4,PI*0.6,20,fade,5.0,true)
		"heal":
			draw_arc(Vector2.ZERO,radius*0.8,0,TAU,40,fade,4.0,true)
			draw_line(Vector2(0,-radius*0.6),Vector2(0,radius*0.6),pale,8.0,true)
			draw_line(Vector2(-radius*0.6,0),Vector2(radius*0.6,0),pale,8.0,true)
		"mark":
			draw_arc(point,25.0+radius*0.12,0,TAU,40,fade,5.0,true)
			draw_line(point+Vector2(-radius*0.6,0),point+Vector2(radius*0.6,0),pale,3.0,true)
			draw_line(point+Vector2(0,-radius*0.6),point+Vector2(0,radius*0.6),pale,3.0,true)
		"smoke":
			for i in range(3):
				var a:float=TAU*float(i)/3.0+t*4.0
				draw_arc(Vector2.from_angle(a)*radius*0.26,radius*0.55,a,a+2.7,20,fade,6.0,true)
		_:
			draw_arc(Vector2.ZERO,radius,0,TAU,40,fade,6.0,true)
