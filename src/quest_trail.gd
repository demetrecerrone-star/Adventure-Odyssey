extends Node2D
# Ground-level wayfinding follows the existing protected roads, never a straight
# arrow through buildings, walls or river banks. It never changes quest state.
const GOLD := Color(1.0,0.80,0.35,0.72)
var route := PackedVector2Array()
var branches: Array[PackedVector2Array] = []
var hero := Vector2.ZERO
var label := ""
static func road(stage:String) -> PackedVector2Array:
 var points := PackedVector2Array()
 if stage not in ["first_combat_active","forest_patrol_active"]: return points
 var values := [[2433.3,1002.45],[2424,1128],[2329,1213],[2344,1318],[2184,1283],[1944,1368],[1684,1393]]
 if stage == "first_combat_active": values.append_array([[1680,1540],[1620,1680],[1410,1780],[1110,1870],[880,1990],[1000,2020]])
 else: values.append_array([[1344,1340],[1100,1300],[850,1230],[750,1190],[700,1110],[660,1030],[660,950]])
 for value in values: points.append(Vector2(value[0],value[1]))
 return points
func update_quest(stage:String,position:Vector2,enemies:Array) -> void:
 route = road(stage); hero=position; branches.clear()
 visible = not route.is_empty()
 label = "South Meadow" if stage == "first_combat_active" else "Western Forest"
 if stage == "first_combat_active":
  for enemy in enemies:
   if enemy.hp <= 0: continue
   var branch:=PackedVector2Array([Vector2(1000,2020)])
   # Southern slime is beyond a flowering shrub: mark the clear east side.
   if enemy.home.y>2350: branch.append_array(PackedVector2Array([Vector2(1140,2200),Vector2(1140,2360)]))
   branch.append(enemy.home); branches.append(branch)
 queue_redraw()
func _draw() -> void:
 if route.size()<2: return
 # Draw only nearby road marks, keeping remote chunks free of visual clutter.
 _draw_path(route)
 for branch in branches: _draw_path(branch)
 var end := route[route.size()-1]
 if hero.distance_to(end)<600:
  draw_arc(end,22,0,TAU,32,GOLD,2,true)
  draw_string_outline(ThemeDB.fallback_font,end+Vector2(28,-5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,Color("302b20"))
  draw_string(ThemeDB.fallback_font,end+Vector2(28,-5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,GOLD)
func _draw_path(points:PackedVector2Array) -> void:
 for i in range(points.size()-1):
  var start := points[i]; var end := points[i+1]
  var direction := (end-start).normalized(); var side := direction.orthogonal()
  var count := maxi(1,int(start.distance_to(end)/68))
  for mark in range(count):
   var at := start.lerp(end,(float(mark)+0.5)/count)
   if hero.distance_to(at)>650: continue
   var chevron:=PackedVector2Array([at-direction*6+side*5,at+direction*3,at-direction*6-side*5])
   draw_polyline(chevron,Color("302b20"),5.5,true)
   draw_polyline(chevron,GOLD,2.5,true)
