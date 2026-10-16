extends Node2D
# Presentation only: no damage, cooldown, movement or save-state mutations.
# Keep the original semantic families for existing callers and regression tests.
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
# Individual palettes are intentional: Firebolt must not inherit Mage ice blue.
const ABILITY_COLORS={
	"Power Slash":"#ffbd68","Shield Bash":"#f2d9a3","Battle Cry":"#ff9256",
	"Aimed Shot":"#d8f3af","Quick Volley":"#8de8c0","Snare Trap":"#69dca0",
	"Firebolt":"#ff863e","Frost Nova":"#85deff","Arcane Barrier":"#a898ff",
	"Raise Skeleton":"#a4ead4","Soul Bolt":"#c59dff","Life Drain":"#a9f58c",
	"Backstab":"#efbaff","Shadowstep":"#bca2ff","Poison Blade":"#abeb65",
	"Holy Strike":"#ffe79a","Divine Heal":"#b5ffd5","Sacred Shield":"#ffe2a0",
	"Earthshaker":"#e8ac73","Hunter's Mark":"#c4f498","Meteor Burst":"#ff9b52",
	"Death Echo":"#cd95ee","Smoke Veil":"#b4acd0","Consecration":"#fff0ae"
}
const TRAIL_LIMIT:float=52.0
const TRAVEL_END:float=0.64
var ability:String=""
var from_here:Vector2=Vector2.ZERO
var direction:Vector2=Vector2.RIGHT
var glow:Color=Color.WHITE
var age:float=0.0
var duration:float=0.72
var pattern:String="aura"
var target_offsets:Array[Vector2]=[]

func configure(skill_name:String,origin:Vector2,destination:Vector2,color:Color,kind:String="",facing_hint:Vector2=Vector2.RIGHT)->void:
	ability=skill_name
	position=origin
	from_here=origin
	direction=destination-origin
	glow=Color(str(ABILITY_COLORS[skill_name])) if ABILITY_COLORS.has(skill_name) else color
	pattern=str(ABILITY_PATTERNS.get(skill_name,KIND_PATTERNS.get(kind,"aura")))
	age=0.0
	duration=0.90 if pattern in ["ward","summon","trap","smoke","heal","nova"] else 0.72
	if pattern in ["projectile","volley"]:
		duration=clampf(direction.length()/620.0+0.26,0.60,0.94)
	var facing_axis:Vector2=facing_hint.normalized() if facing_hint.length_squared()>0.001 else Vector2.RIGHT
	if direction.length()<1.0 and pattern in ["projectile","volley","dash","slash"]:
		direction=facing_axis*145.0
	# Ground placement and single-target contact cues must not remain on caster.
	if pattern in ["trap","summon","mark"] or ability in ["Shield Bash","Holy Strike"]:
		position=destination
	target_offsets.clear()
	target_offsets.append(direction)
	# Above world scenery, still in the world canvas below the existing HUD.
	z_index=30
	queue_redraw()

func set_target_positions(destinations:Array)->void:
	# Capture real targets before gameplay damage can remove them. Three maximum.
	target_offsets.clear()
	for destination in destinations:
		if destination is Vector2:
			target_offsets.append(destination-from_here)
			if target_offsets.size()==3:break
	if target_offsets.is_empty():target_offsets.append(direction)
	queue_redraw()

func visual_alpha(progress:float)->float:
	# Hold the silhouette through the readable part, then ease it out.
	return 1.0-smoothstep(0.58,1.0,clampf(progress,0.0,1.0))

func projectile_point(progress:float,offset:Vector2)->Vector2:
	return offset*clampf(progress/TRAVEL_END,0.0,1.0)

func trail_length(offset:Vector2)->float:
	return minf(TRAIL_LIMIT,offset.length()*0.32)

func _process(delta:float)->void:
	age+=maxf(0.0,delta)
	if age>=duration:
		queue_free()
		return
	queue_redraw()

func _tint(color:Color,alpha:float)->Color:
	return Color(color.r,color.g,color.b,clampf(alpha,0.0,1.0))

func _stroke(a:Vector2,b:Vector2,color:Color,width:float)->void:
	draw_line(a,b,Color(0.04,0.06,0.10,color.a*0.75),width+3.0,true)
	draw_line(a,b,color,width,true)

func _ring(center:Vector2,radius:float,color:Color,width:float=3.0)->void:
	draw_arc(center,radius,0.0,TAU,40,Color(0.04,0.06,0.10,color.a*0.65),width+3.0,true)
	draw_arc(center,radius,0.0,TAU,40,color,width,true)

func _burst(center:Vector2,progress:float,alpha:float)->void:
	var radius:float=8.0+30.0*progress
	_ring(center,radius,_tint(glow,alpha),3.0)
	for i in range(6):
		var axis:Vector2=Vector2.from_angle(TAU*float(i)/6.0)
		_stroke(center+axis*radius*0.65,center+axis*(radius+8.0),_tint(glow,alpha),3.0)

func _arrow(point:Vector2,axis:Vector2,alpha:float)->void:
	var normal:Vector2=axis.orthogonal()
	_stroke(point-axis*28.0,point,_tint(glow,alpha),4.0)
	draw_colored_polygon(PackedVector2Array([point+axis*13.0,point-axis*3.0+normal*7.0,point-axis*3.0-normal*7.0]),_tint(Color.WHITE,alpha))
	_stroke(point-axis*21.0,point-axis*29.0+normal*7.0,_tint(glow,alpha),2.0)
	_stroke(point-axis*21.0,point-axis*29.0-normal*7.0,_tint(glow,alpha),2.0)

func _projectile(offset:Vector2,t:float,alpha:float)->void:
	if t>=TRAVEL_END:
		_burst(offset,(t-TRAVEL_END)/(1.0-TRAVEL_END),alpha)
		return
	var point:Vector2=projectile_point(t,offset)
	var axis:Vector2=offset.normalized() if offset.length_squared()>0.001 else Vector2.RIGHT
	var tail:float=minf(trail_length(offset),point.length())
	_stroke(point-axis*tail,point,_tint(glow,alpha*0.62),6.0)
	if ability in ["Aimed Shot","Quick Volley"]:
		_arrow(point,axis,alpha)
	elif ability=="Firebolt":
		var normal:Vector2=axis.orthogonal()
		draw_circle(point,19.0,_tint(glow,alpha*0.20))
		draw_colored_polygon(PackedVector2Array([point+axis*14.0,point+normal*10.0,point-axis*23.0,point-normal*10.0]),_tint(glow,alpha))
		draw_circle(point,6.0,_tint(Color("#fff5ba"),alpha))
		for i in range(3):
			var ember:Vector2=point-axis*(18.0+float(i)*11.0)+normal*sin(t*30.0+float(i))*6.0
			draw_circle(ember,3.0,_tint(glow,alpha*(0.7-float(i)*0.15)))
	else:
		draw_circle(point,18.0,_tint(glow,alpha*0.18))
		_ring(point,11.0,_tint(glow,alpha),4.0)
		draw_circle(point,4.5,_tint(Color.WHITE,alpha))
		for i in range(2):
			var orbit:Vector2=Vector2.from_angle(t*11.0+float(i)*PI)*16.0
			draw_circle(point+orbit,3.0,_tint(glow,alpha))

func _draw()->void:
	if duration<=0.0:return
	var t:float=clampf(age/duration,0.0,1.0)
	var alpha:float=visual_alpha(t)
	var ink:Color=_tint(glow,alpha)
	var white:Color=_tint(Color.WHITE,alpha*0.90)
	var radius:float=25.0+68.0*(1.0-pow(1.0-t,2.0))
	var angle:float=direction.angle()
	match pattern:
		"projectile":
			_projectile(direction,t,alpha)
		"volley":
			for offset in target_offsets:_projectile(offset,t,alpha)
		"slash":
			var sweep:float=angle-1.0+t*0.6
			draw_arc(Vector2.ZERO,radius,sweep,sweep+1.9,32,_tint(Color("#111923"),alpha*0.8),15.0,true)
			draw_arc(Vector2.ZERO,radius,sweep,sweep+1.9,32,ink,10.0,true)
			draw_arc(Vector2.ZERO,radius+3.0,sweep+0.2,sweep+1.8,28,white,3.0,true)
			if ability=="Backstab":
				_stroke(Vector2(18,-32).rotated(angle),Vector2(72,32).rotated(angle),white,5.0)
			elif ability=="Poison Blade":
				for i in range(4):
					draw_circle(Vector2.from_angle(sweep+float(i)*0.45)*(radius-12.0),4.0,ink)
		"impact":
			if ability=="Earthshaker":
				for i in range(8):
					var a:float=TAU*float(i)/8.0
					var start:Vector2=Vector2.from_angle(a)*18.0
					var bend:Vector2=Vector2.from_angle(a+0.12)*radius*0.62
					_stroke(start,bend,ink,5.0)
					_stroke(bend,Vector2.from_angle(a)*radius,ink,3.0)
				_ring(Vector2.ZERO,radius*0.70,_tint(glow,alpha*0.6),3.0)
			else:
				_burst(Vector2.ZERO,t,alpha)
				if ability=="Holy Strike":
					_stroke(Vector2(0,-44),Vector2(0,23),white,7.0)
					_stroke(Vector2(-22,-14),Vector2(22,-14),white,6.0)
				else:
					draw_colored_polygon(PackedVector2Array([Vector2(-17,-24),Vector2(17,-24),Vector2(15,10),Vector2(0,24),Vector2(-15,10)]),_tint(glow,alpha*0.45))
					_stroke(Vector2(0,-18),Vector2(0,15),white,4.0)
		"aura":
			_ring(Vector2.ZERO,radius*0.68,ink,4.0)
			for i in range(6):
				var at:Vector2=Vector2.from_angle(TAU*float(i)/6.0)*42.0
				_stroke(at+Vector2(0,12.0-t*20.0),at+Vector2(0,-12.0-t*20.0),ink,4.0)
		"trap":
			# Stable deployment footprint; this is not the 12-second gameplay timer.
			_ring(Vector2.ZERO,44.0,ink,3.0)
			_ring(Vector2.ZERO,32.0,_tint(glow,alpha*0.65),2.0)
			for i in range(8):
				var axis:Vector2=Vector2.from_angle(TAU*float(i)/8.0)
				_stroke(axis*35.0,axis*52.0,ink,4.0)
				_stroke(axis*31.0,axis.rotated(PI/2.0)*31.0,_tint(glow,alpha*0.35),1.5)
		"nova":
			if ability=="Meteor Burst":
				var fall:float=clampf(t/0.46,0.0,1.0)
				var at:Vector2=Vector2(48,-88)*(1.0-fall)
				if t<0.46:
					_stroke(at+Vector2(22,-40),at,_tint(glow,alpha*0.65),14.0)
					draw_circle(at,15.0,ink)
					draw_circle(at,7.0,white)
				else:
					_burst(Vector2.ZERO,(t-0.46)/0.54,alpha)
					_ring(Vector2.ZERO,radius,ink,6.0)
			else:
				_ring(Vector2.ZERO,radius,ink,4.0)
				for i in range(8):
					var axis:Vector2=Vector2.from_angle(TAU*float(i)/8.0)
					var side:Vector2=axis.orthogonal()
					_stroke(axis*20.0,axis*radius,ink,3.0)
					_stroke(axis*radius,axis*(radius-15.0)+side*9.0,white,2.0)
					_stroke(axis*radius,axis*(radius-15.0)-side*9.0,white,2.0)
		"ward":
			var r:float=42.0+sin(t*PI)*4.0
			if ability=="Sacred Shield":
				var points:PackedVector2Array=PackedVector2Array([Vector2(-32,-38),Vector2(32,-38),Vector2(29,14),Vector2(0,43),Vector2(-29,14),Vector2(-32,-38)])
				draw_colored_polygon(points,_tint(glow,alpha*0.12))
				draw_polyline(points,ink,5.0,true)
				_stroke(Vector2(0,-23),Vector2(0,23),white,4.0)
				_stroke(Vector2(-16,-6),Vector2(16,-6),white,4.0)
			else:
				for i in range(6):
					var a:float=TAU*float(i)/6.0
					_stroke(Vector2.from_angle(a)*r,Vector2.from_angle(a+TAU/6.0)*r,ink,4.0)
				_ring(Vector2.ZERO,32.0,_tint(glow,alpha*0.5),2.0)
		"summon":
			_ring(Vector2.ZERO,42.0,ink,3.0)
			for i in range(5):
				var at:Vector2=Vector2.from_angle(TAU*float(i)/5.0)*32.0
				_stroke(at,at+Vector2(0,-24.0-16.0*t),_tint(glow,alpha*0.6),3.0)
			var skull:Vector2=Vector2(0,-12.0-20.0*t)
			draw_circle(skull,13.0,white)
			draw_circle(skull+Vector2(-5,-2),3.5,_tint(Color("#223b3b"),alpha))
			draw_circle(skull+Vector2(5,-2),3.5,_tint(Color("#223b3b"),alpha))
			_stroke(skull+Vector2(-7,13),skull+Vector2(7,13),ink,4.0)
		"drain":
			_stroke(Vector2.ZERO,direction,_tint(glow,alpha*0.25),2.0)
			for i in range(4):
				var u:float=fposmod(t*1.5+float(i)*0.22,1.0)
				var at:Vector2=direction*(1.0-u)+direction.normalized().orthogonal()*sin(u*TAU)*9.0
				draw_circle(at,5.0,ink)
				draw_circle(at,2.0,white)
			if ability=="Death Echo":
				_ring(direction,20.0+18.0*t,ink,3.0)
				_ring(direction,12.0+12.0*t,_tint(glow,alpha*0.5),2.0)
			else:_ring(Vector2.ZERO,17.0+9.0*t,ink,3.0)
		"dash":
			for i in range(4):
				var at:Vector2=direction*clampf(t*1.8-float(i)*0.18,0.0,1.0)
				var tint:Color=_tint(glow,alpha*(0.8-float(i)*0.15))
				_ring(at,12.0,tint,3.0)
				_stroke(at+Vector2(0,12),at+Vector2(0,28),tint,5.0)
		"heal":
			var r:float=46.0 if ability=="Consecration" else 30.0
			_ring(Vector2.ZERO,r,ink,3.0)
			if ability=="Consecration":
				_ring(Vector2.ZERO,r+13.0,_tint(glow,alpha*0.55),2.0)
				for i in range(8):
					var at:Vector2=Vector2.from_angle(TAU*float(i)/8.0)*r
					draw_circle(at,4.0,white)
			var rise:Vector2=Vector2(0,-12.0-t*25.0)
			_stroke(rise+Vector2(0,-17),rise+Vector2(0,17),white,6.0)
			_stroke(rise+Vector2(-17,0),rise+Vector2(17,0),white,6.0)
		"mark":
			_ring(Vector2.ZERO,27.0,ink,3.0)
			for i in range(4):
				var axis:Vector2=Vector2.from_angle(TAU*float(i)/4.0)
				_stroke(axis*19.0,axis*39.0,ink,4.0)
		"smoke":
			for i in range(5):
				var at:Vector2=Vector2.from_angle(TAU*float(i)/5.0+t)*28.0
				draw_circle(at,21.0+7.0*t,_tint(glow,alpha*0.22))
				draw_arc(at,21.0+7.0*t,float(i),float(i)+3.4,20,ink,3.0,true)
		_:
			_ring(Vector2.ZERO,radius,ink,3.0)
