extends RefCounted
## 守水人小屋室外：石桥、土路与门前院落；不开放房屋、菜畦、溪水和树根出口。
const SIZE := Vector2(1672,941)
const SPAWN := Vector2(1550,163)
const ENTRANCE := Vector2(1620,163)
const INTERACT_RADIUS := 80.0
const FOOT_RADIUS := 4.0
const MOSS_MARKER := Vector2(945,800)
const MOSS_RETURN := Vector2(974,824)
const LINK_ATLAS := Vector2(285,164)
const COURTYARD := [Vector2(590,326),Vector2(645,305),Vector2(720,302),Vector2(742,329),Vector2(820,347),Vector2(910,362),Vector2(980,360),Vector2(992,388),Vector2(865,413),Vector2(812,435),Vector2(765,443),Vector2(729,417),Vector2(650,397),Vector2(591,373),Vector2(560,350)]
## 菜园通路沿两畦之间的浅色土路；菜畦本身与柴堆不开放。
const GARDEN_OBSTACLES := [
	[Vector2(278,330),Vector2(407,283),Vector2(485,320),Vector2(491,342),Vector2(350,382),Vector2(300,365)],
	[Vector2(383,399),Vector2(518,351),Vector2(586,384),Vector2(589,420),Vector2(441,466),Vector2(382,438)],
	[Vector2(516,267),Vector2(558,269),Vector2(582,293),Vector2(552,313),Vector2(515,293)]
]

static func roads() -> Array:
	return [
		{"width":14.0,"points":PackedVector2Array([Vector2(620,344),Vector2(550,335),Vector2(500,350),Vector2(450,363),Vector2(400,380),Vector2(350,392)])},
		{"width":22.0,"points":PackedVector2Array([Vector2(1645,163),Vector2(1550,163),Vector2(1450,143),Vector2(1370,180),Vector2(1315,215),Vector2(1270,260),Vector2(1190,312),Vector2(1090,340),Vector2(990,370),Vector2(840,370),Vector2(700,350)])},
		{"width":24.0,"points":PackedVector2Array([Vector2(780,408),Vector2(780,450),Vector2(750,510),Vector2(670,580),Vector2(570,650),Vector2(450,710),Vector2(350,760),Vector2(300,795)])},
		{"width":19.0,"points":PackedVector2Array([Vector2(1370,180),Vector2(1430,149),Vector2(1395,105),Vector2(1320,60),Vector2(1295,30)])},
		{"width":13.0,"points":PackedVector2Array([Vector2(620,344),Vector2(540,322),Vector2(460,285),Vector2(405,265)])}
	]

static func _inside(point: Vector2) -> bool:
	for polygon in GARDEN_OBSTACLES:
		if Geometry2D.is_point_in_polygon(point,PackedVector2Array(polygon)): return false
	if Geometry2D.is_point_in_polygon(point,PackedVector2Array(COURTYARD)): return true
	for road in roads():
		for i in range(road.points.size()-1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[i],road.points[i+1])) <= road.width: return true
	return false

static func is_walkable(point: Vector2, radius: float = FOOT_RADIUS) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius<0.0: return false
	if not Rect2(Vector2.ONE*radius,SIZE-Vector2.ONE*radius*2).has_point(point) or not _inside(point): return false
	for i in 8:
		if not _inside(point+Vector2.from_angle(float(i)*TAU/8)*radius): return false
	return true

static func move_on_road(origin: Vector2, displacement: Vector2) -> Vector2:
	if not is_walkable(origin) or not displacement.is_finite(): return origin
	var count := maxi(1,ceili(displacement.length()/2.0))
	var step := displacement/float(count)
	var current := origin
	for i in count:
		if is_walkable(current+step): current+=step
		elif is_walkable(current+Vector2(step.x,0)): current.x+=step.x
		elif is_walkable(current+Vector2(0,step.y)): current.y+=step.y
	return current
