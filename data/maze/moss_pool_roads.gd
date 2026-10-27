extends RefCounted
## 青苔池仅五段土路可行走；水池、瀑布、作物及崖壁均不开放。
const SIZE := Vector2(1484,1060)
const SPAWN := Vector2(1201,956)
const ENTRANCE := Vector2(1208,1015)
const INTERACT_RADIUS := 80.0
const FOOT_RADIUS := 4.0
const FENSHUI_PORTAL := Vector2(189.5,170.5)
const FENSHUI_RETURN := Vector2(239,194)
## 盐池左侧道路连接青苔池右侧道路；落点在路标内侧，避开路标阻挡。
const SALT_MARKER := Vector2(1445,662)
const SALT_ARRIVAL := Vector2(1380,633)
const SALT_SIDE_MARKER := Vector2(35,390)
const SALT_SIDE_ARRIVAL := Vector2(105,402)
const SALT_LINK_ATLAS := Vector2(662,263)

static func roads() -> Array:
	return [
		{"width":16.0,"points":PackedVector2Array([Vector2(0,359),Vector2(70,385),Vector2(156,424),Vector2(240,447),Vector2(313,446),Vector2(384,422),Vector2(446,394),Vector2(502,359),Vector2(539,322),Vector2(551,289)])},
		{"width":13.0,"points":PackedVector2Array([Vector2(650,575),Vector2(687,558),Vector2(727,534),Vector2(755,506),Vector2(778,490)])},
		{"width":15.0,"points":PackedVector2Array([Vector2(1265,622),Vector2(1313,619),Vector2(1371,628),Vector2(1433,658),Vector2(1484,676)])},
		{"width":14.0,"points":PackedVector2Array([Vector2(1100,738),Vector2(1080,781),Vector2(1101,827),Vector2(1147,870),Vector2(1194,915),Vector2(1201,956),Vector2(1208,1015),Vector2(1208,1060)])},
		{"width":14.0,"points":PackedVector2Array([Vector2(728,885),Vector2(707,923),Vector2(680,960),Vector2(666,1004),Vector2(664,1060)])}
	]

static func is_walkable(point: Vector2, radius: float = FOOT_RADIUS) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius < 0.0: return false
	if not Rect2(Vector2.ONE * radius, SIZE - Vector2.ONE * radius * 2.0).has_point(point): return false
	for road in roads():
		if radius > road.width: continue
		for i in range(road.points.size()-1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[i],road.points[i+1])) <= road.width-radius: return true
	return false

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
