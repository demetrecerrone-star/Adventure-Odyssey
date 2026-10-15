extends Node2D
# Adventure Odyssey starter bedroom. All geometry is deliberately pixel-aligned,
# drawn at native world resolution so it inherits the game's nearest-neighbor look.
var chest_open := false

func _tile(x:float,y:float,w:float,h:float,col:Color)->void:
	draw_rect(Rect2(x,y,w,h),col)

func _framed(x:float,y:float,w:float,h:float,edge:Color,fill:Color)->void:
	_tile(x,y,w,h,edge)
	_tile(x+8,y+8,w-16,h-16,fill)

func set_chest_open(value:bool)->void:
	chest_open=value
	queue_redraw()

func _draw()->void:
	# Dark outside border, warm wood floor, and thick plaster-and-timber walls.
	_tile(0,0,2048,1280,Color("#121d2a"))
	_tile(462,203,1124,894,Color("#2a2b35"))
	_tile(485,228,1078,847,Color("#645142"))
	_tile(516,321,1016,718,Color("#805b42"))
	for row in range(23):
		var y=323+row*31
		_tile(520,y,1008,3,Color("#5a3f32"))
		for col in range(7):
			var x=533+col*146+(73 if row%2==1 else 0)
			if x<1520:
				_tile(x,y+6,3,19,Color("#6b4834"))
	for k in range(32):
		var xx=528+(k*101)%968
		var yy=346+(k*71)%665
		_tile(xx,yy,36,3,Color(0.98,0.72,0.48,0.12))
	# Upper wall with oak beams and an arched inset window.
	_tile(485,228,1078,94,Color("#555263"))
	_tile(485,230,1078,15,Color("#342b34"))
	_tile(485,309,1078,20,Color("#322b31"))
	_tile(542,236,24,90,Color("#392f34"))
	_tile(1494,236,24,90,Color("#392f34"))
	_framed(936,242,171,95,Color("#393443"),Color("#b69b79"))
	_tile(950,254,143,69,Color("#344f6f"))
	_tile(1006,255,8,68,Color("#a5a0a4"))
	_tile(951,292,141,8,Color("#a5a0a4"))
	_tile(957,261,44,26,Color("#6e84a1"))
	_tile(1021,265,58,21,Color("#7f91a7"))
	# Side walls and trim.
	_tile(485,320,32,733,Color("#423743"))
	_tile(1531,320,32,733,Color("#423743"))
	_tile(485,1039,1078,36,Color("#46333b"))
	_tile(514,1028,1045,12,Color("#b28757"))
	# Woven carpet with a golden stitched border.
	_framed(890,622,315,297,Color("#554044"),Color("#ad6661"))
	_framed(915,645,265,247,Color("#cfaa6b"),Color("#744c58"))
	for k in range(6):
		_tile(931+k*42,673,14,194,Color("#996f6c"))
	# Tall four-post bed on the left.
	_tile(615,383,292,316,Color("#422f32"))
	_tile(624,390,272,295,Color("#6a493a"))
	_tile(642,415,238,242,Color("#c2a679"))
	_tile(647,423,226,217,Color("#d3c4a2"))
	_tile(653,424,214,66,Color("#f0e7d0"))
	_tile(647,503,226,137,Color("#4e8190"))
	for k in range(4):
		_tile(657+k*52,512,31,116,Color("#6496a2"))
	_tile(618,378,30,311,Color("#3b272b"))
	_tile(875,378,30,311,Color("#3b272b"))
	_tile(608,363,51,26,Color("#b58a52"))
	_tile(864,363,51,26,Color("#b58a52"))
	_tile(614,680,293,22,Color("#3a292d"))
	# Bedside shelf, candle, and tiny book.
	_framed(526,465,76,117,Color("#382a2c"),Color("#9c6b48"))
	_tile(545,481,21,45,Color("#e7cc94"))
	_tile(548,465,15,20,Color("#ffd887"))
	_tile(572,498,17,63,Color("#416b78"))
	# Wall bookshelf with little uneven book spines.
	_framed(1157,342,274,179,Color("#3e2e31"),Color("#865b40"))
	for shelf in range(3):
		var yy=358+shelf*51
		_tile(1171,yy+36,244,9,Color("#4a3034"))
		for book in range(10):
			var bx=1180+book*22
			var bh=20+(book*7+shelf*5)%18
			var col=Color("#5d7688") if book%3==0 else (Color("#a85e53") if book%3==1 else Color("#c7a06e"))
			_tile(bx,yy+36-bh,15,bh,col)
	# Brass mirror with a visible glass surface and shaded reflection.
	_tile(1441,471,91,220,Color("#362b32"))
	_framed(1449,482,75,190,Color("#cca66c"),Color("#385970"))
	_tile(1465,500,24,130,Color("#668496"))
	_tile(1474,514,8,99,Color("#b3c6c1"))
	_tile(1463,650,48,8,Color("#c7a26b"))
	# Storage chest, reinforced leather and brass latch.
	_tile(1250,734,210,113,Color("#35272c"))
	_tile(1258,748,194,91,Color("#7d513b"))
	_tile(1268,756,174,72,Color("#a7724c"))
	for band in [1282,1408]:
		_tile(band,749,18,91,Color("#ca9d58"))
	_tile(1345,785,24,29,Color("#e4c179"))
	_tile(1352,793,10,15,Color("#4e3d3a"))
	if chest_open:
		_tile(1255,714,200,38,Color("#2c2530"))
		_tile(1265,719,180,25,Color("#b9905b"))
	else:
		_tile(1254,728,202,27,Color("#563834"))
		_tile(1267,731,180,14,Color("#c69b61"))
	# Plant, hanging banner, and a soft candle glow.
	_tile(556,798,79,64,Color("#795444"))
	_tile(568,788,55,35,Color("#b38b61"))
	for off in [-28,-4,18,34]:
		draw_circle(Vector2(598+off,754+abs(off)%23),28,Color("#446c58"))
	_tile(586,737,14,67,Color("#38533e"))
	_tile(742,242,92,142,Color("#5e3d50"))
	_tile(751,248,74,112,Color("#8f5a5d"))
	_tile(776,270,23,60,Color("#d7b67e"))
	draw_circle(Vector2(565,470),66,Color(1.0,0.69,0.30,0.08))
	# Bedroom doorway. The rest of the cottage will connect here later.
	_tile(966,1013,150,62,Color("#251f28"))
	_tile(978,1016,126,58,Color("#9d744f"))
	_tile(991,1023,101,51,Color("#3e3339"))
	_tile(1078,1043,10,10,Color("#dfbf7f"))
	_tile(953,1007,15,71,Color("#d1a269"))
	_tile(1112,1007,15,71,Color("#d1a269"))
