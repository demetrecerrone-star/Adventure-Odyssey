extends Node2D
# Adventure Odyssey cottage: an explorable hallway, sitting room and kitchen.
# Temporary code-rendered art keeps the new spaces functional until their
# illustrated background/sprite pass is approved. Coordinates: 2048 x 1280.

func _rect(x:float,y:float,w:float,h:float,color:String)->void:
	draw_rect(Rect2(x,y,w,h),Color(color))

func _framed(x:float,y:float,w:float,h:float,edge:String,fill:String,border:float=9.0)->void:
	_rect(x,y,w,h,edge)
	_rect(x+border,y+border,w-border*2.0,h-border*2.0,fill)

func _rug(x:float,y:float,w:float,h:float,base:String)->void:
	_framed(x,y,w,h,"#4b343a","#d7ac72",11)
	_framed(x+15,y+15,w-30,h-30,"#694752",base,11)
	for i in range(6):
		var rx=x+32+i*(w-64)/6.0
		_rect(rx,y+37,9,h-74,"#a47b69")

func _window(x:float,y:float)->void:
	_framed(x,y,190,94,"#4c3940","#a87856",12)
	_rect(x+22,y+19,146,54,"#547f98")
	_rect(x+92,y+19,12,54,"#dfc5a0")
	_rect(x+20,y+46,151,8,"#dfc5a0")
	_rect(x+36,y+24,30,17,"#92abc1")

func _draw()->void:
	# A continuous floor: the narrow hall leads to a shared living/kitchen area.
	_rect(0,0,2048,1280,"#142331")
	_rect(232,218,1596,952,"#302c36")
	_framed(250,238,1560,914,"#5b3d36","#825b43",23)
	# Wood-plank seams and alternating honey highlights.
	for row in range(25):
		var y=268+row*34
		_rect(278,y,1503,3,"#634633")
		for col in range(10):
			var x=291+col*149+(73 if row%2 else 0)
			if x<1770:
				_rect(x,y+6,3,18,"#73523e")
	for i in range(20):
		_rect(310+(i*139)%1390,304+(i*233)%760,68,3,"#947052")
	# Plaster upper walls, structural beams, and room-dividing floor trims.
	_rect(260,248,1540,85,"#b49878")
	_rect(260,248,1540,15,"#4b3941")
	_rect(260,320,1540,17,"#63443b")
	for x in [306,732,1285,1743]:
		_rect(x,250,26,104,"#624537")
	_rect(272,514,566,18,"#684a3c")
	_rect(1215,514,569,18,"#684a3c")
	_rect(836,514,379,9,"#c09b68")
	# Corridor runner: the bedroom is north; town entrance is south.
	_rug(881,339,288,347,"#785c71")
	_rug(941,818,185,271,"#637a71")
	# Living room: sunlit window, books, hearth, couch, cushions and table.
	_window(466,276)
	_framed(328,440,125,210,"#392f31","#87634e")
	_rect(347,500,87,115,"#3a3435")
	_rect(364,550,52,53,"#df7a42")
	_rect(376,525,22,76,"#f4b95f")
	_rect(340,637,101,15,"#b99569")
	_framed(512,665,322,146,"#463941","#8c5849",13)
	_framed(529,675,282,92,"#b88a67","#6d8a88",12)
	_rect(520,778,300,26,"#604439")
	_rect(551,700,77,49,"#c9a16e")
	_rect(700,700,78,49,"#c9a16e")
	_rug(500,818,465,248,"#735b70")
	_framed(680,871,253,122,"#4b3336","#ab805a",14)
	_rect(704,886,206,8,"#dfb27b")
	_framed(305,694,130,276,"#49383d","#a47b56")
	for shelf in range(4):
		var sy=720+shelf*56
		_rect(322,sy+44,93,9,"#513b35")
		for b in range(5):
			var h=19+(b*7+shelf*3)%20
			_rect(327+b*18,sy+42-h,12,h,["#648895","#b27c6b","#d3b073"][b%3])
	# Kitchen and breakfast nook: functional visual elements are separate
	# from collisions, so interactions can be attached later.
	_window(1360,278)
	_framed(1365,470,233,146,"#523d37","#b68a5a",12)
	_rect(1388,488,186,14,"#dfbd87")
	_rect(1388,524,186,14,"#dfbd87")
	_rect(1415,478,20,51,"#658678")
	_rect(1474,478,25,51,"#b07d62")
	_rect(1534,478,25,51,"#63879c")
	_framed(1281,736,320,179,"#4b3636","#9d754e",17)
	_rect(1303,758,274,12,"#dbb989")
	_rect(1336,912,18,36,"#563f37")
	_rect(1530,912,18,36,"#563f37")
	_framed(1630,517,150,450,"#573d36","#b68a62",12)
	for i in range(4):
		_rect(1645,599+i*78,118,12,"#70503c")
	for i in range(3):
		_framed(1650,552+i*83,35,34,"#78513c","#e1bf89",5)
		_framed(1701,552+i*83,50,34,"#6a5547","#77948e",5)
	# Pantry sacks and hanging herbs.
	_rect(1660,985,89,34,"#c4a070")
	_rect(1670,972,64,36,"#ab865f")
	for i in range(4):
		_rect(1635+i*30,425,11,55,"#66816b")
	# Small dining table with pottery, benches, and a vase.
	_framed(1230,585,204,126,"#4b3736","#9c724c",13)
	_rect(1255,600,154,10,"#d5ac75")
	draw_circle(Vector2(1353,647),21,Color("#d9bb92"))
	draw_circle(Vector2(1353,647),10,Color("#627e83"))
	_rect(1260,715,149,22,"#62443a")
	# Plants, coat hooks, wall portraits, and lanterns.
	_framed(587,405,147,100,"#604337","#e5c595",13)
	_rect(611,430,96,49,"#658b89")
	_rect(620,437,37,32,"#ad9271")
	_rect(350,1010,76,38,"#89614b")
	for off in [-19,0,20]:
		draw_circle(Vector2(388+off,987),25,Color("#577b60"))
	_rect(1581,1033,76,39,"#906549")
	for off in [-18,4,20]:
		draw_circle(Vector2(1618+off,1017),24,Color("#5e8364"))
	for x in [822,1190]:
		_rect(x,341,23,45,"#806144")
		draw_circle(Vector2(x+12,390),23,Color(0.96,0.72,0.42,0.46))
	# Bedroom entrance at top, outgoing front porch at bottom.
	_framed(943,251,170,82,"#3e3034","#644c41",10)
	_rect(958,273,143,49,"#cba16b")
	_rect(1006,279,14,35,"#ebd1a1")
	_framed(939,1057,182,89,"#342b30","#966b48",13)
	_rect(959,1070,145,62,"#694c3b")
	_rect(1090,1087,12,13,"#e7c483")
	# Route hint integrated into the floor, not an intrusive tutorial overlay.
	_rect(971,1024,126,6,"#c39e6c")
