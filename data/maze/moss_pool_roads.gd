extends RefCounted
## 飞书原图1408×1117；按可见土路标定，水池、瀑布、树林及崖壁不开放。
const SIZE := Vector2(1408,1117)
const SPAWN := Vector2(1100,1030)
const ENTRANCE := Vector2(1140,1080)
const INTERACT_RADIUS := 80.0
const FOOT_RADIUS := 4.0
const FENSHUI_PORTAL := Vector2(189.5,170.5)
const FENSHUI_RETURN := Vector2(239,194)
## 盐池左侧道路连接青苔池右侧道路；落点在路标内侧，避开路标阻挡。
const SALT_MARKER := Vector2(1370,730)
const SALT_ARRIVAL := Vector2(1315,710)
const SALT_SIDE_MARKER := Vector2(35,390)
const SALT_SIDE_ARRIVAL := Vector2(105,402)
const SALT_LINK_ATLAS := Vector2(662,263)

static func roads() -> Array:
	return [
		{"width":14.0,"points":PackedVector2Array([Vector2(0,430),Vector2(70,458),Vector2(140,474),Vector2(188,469),Vector2(240,438),Vector2(300,402),Vector2(350,382),Vector2(390,354),Vector2(424,324),Vector2(434,299),Vector2(423,270)])},
		{"width":12.0,"points":PackedVector2Array([Vector2(580,505),Vector2(620,512),Vector2(650,531),Vector2(669,550),Vector2(667,575),Vector2(652,596),Vector2(620,616),Vector2(585,637),Vector2(560,646)])},
		{"width":12.0,"points":PackedVector2Array([Vector2(920,498),Vector2(940,477),Vector2(955,460),Vector2(970,435),Vector2(990,408),Vector2(1000,390),Vector2(1010,370),Vector2(1000,345)])},
		{"width":16.0,"points":PackedVector2Array([Vector2(1150,1117),Vector2(1150,1100),Vector2(1120,1070),Vector2(1100,1030),Vector2(1075,1000),Vector2(1060,970),Vector2(1050,950),Vector2(1030,910),Vector2(1005,870),Vector2(985,840),Vector2(974,824),Vector2(990,780),Vector2(1014,738),Vector2(1060,702),Vector2(1120,669),Vector2(1170,665),Vector2(1230,689),Vector2(1315,710),Vector2(1408,742)])},
		{"width":14.0,"points":PackedVector2Array([Vector2(490,860),Vector2(520,890),Vector2(548,917),Vector2(570,941),Vector2(570,969),Vector2(545,990),Vector2(500,1008),Vector2(460,1016),Vector2(400,1025),Vector2(350,1035)])}
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
