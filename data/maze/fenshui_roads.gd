extends RefCounted
## 分水庭原图像素。浅水可走，岸壁与植被岛按脚底半径裁剪。
const SIZE := Vector2(1715,917)
const SPAWN := Vector2(1560,218)
const ENTRANCE := Vector2(1660,168)
const INTERACT_RADIUS := 65.0
const FOOT_RADIUS := 4.0
const Gates = preload("res://data/maze/fenshui_gates.gd")
const WATER_SPEED := 0.65
static var OUTLINE := PackedVector2Array([Vector2(8,14),Vector2(70,30),Vector2(113,83),Vector2(151,126),Vector2(263,142),Vector2(350,177),Vector2(471,187),Vector2(558,206),Vector2(650,175),Vector2(717,172),Vector2(812,173),Vector2(835,125),Vector2(798,79),Vector2(781,4),Vector2(846,4),Vector2(859,61),Vector2(912,104),Vector2(965,146),Vector2(1122,142),Vector2(1190,161),Vector2(1160,205),Vector2(1194,257),Vector2(1270,279),Vector2(1390,264),Vector2(1490,233),Vector2(1570,188),Vector2(1707,137),Vector2(1707,188),Vector2(1590,222),Vector2(1519,260),Vector2(1466,302),Vector2(1493,355),Vector2(1528,404),Vector2(1557,430),Vector2(1530,484),Vector2(1481,533),Vector2(1431,578),Vector2(1480,625),Vector2(1570,657),Vector2(1707,704),Vector2(1707,756),Vector2(1588,711),Vector2(1480,675),Vector2(1366,645),Vector2(1323,689),Vector2(1319,758),Vector2(1223,787),Vector2(1123,786),Vector2(1051,803),Vector2(1020,847),Vector2(1027,909),Vector2(955,909),Vector2(948,844),Vector2(905,806),Vector2(824,777),Vector2(715,814),Vector2(588,831),Vector2(463,862),Vector2(337,909),Vector2(282,909),Vector2(394,849),Vector2(529,800),Vector2(627,763),Vector2(669,711),Vector2(594,670),Vector2(504,642),Vector2(432,594),Vector2(341,582),Vector2(266,561),Vector2(201,535),Vector2(152,547),Vector2(91,520),Vector2(8,503),Vector2(8,465),Vector2(89,485),Vector2(152,506),Vector2(217,466),Vector2(259,429),Vector2(286,373),Vector2(309,330),Vector2(294,277),Vector2(245,236),Vector2(201,198),Vector2(108,163),Vector2(77,123),Vector2(58,72),Vector2(8,47)])
const ISLANDS := [Vector4(650,245,96,42),Vector4(1184,248,112,56),Vector4(1000,337,53,29),Vector4(379,329,53,25),Vector4(544,381,36,37),Vector4(560,481,110,48),Vector4(1138,528,86,37),Vector4(1355,484,111,52),Vector4(1373,326,46,29),Vector4(1443,378,38,24),Vector4(948,670,80,35),Vector4(1132,717,65,30)]

## 用户绿圈指定的浅水缺口。优先于粗略岛体椭圆，但仍受栅栏阻挡。
static var ROAD_EDGE := PackedVector2Array([Vector2(1275,406),Vector2(1359,410),Vector2(1438,429),Vector2(1480,457),Vector2(1490,503),Vector2(1470,515),Vector2(1456,500),Vector2(1419,475),Vector2(1358,451),Vector2(1285,437)])

static var WATER_EDGES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(863,673),Vector2(870,652),Vector2(891,631),Vector2(911,622),Vector2(939,619),Vector2(948,616),Vector2(944,630),Vector2(920,643),Vector2(895,661),Vector2(876,675)]),
	PackedVector2Array([Vector2(467,206),Vector2(586,211),Vector2(599,248),Vector2(617,264),Vector2(686,275),Vector2(720,292),Vector2(713,303),Vector2(579,313),Vector2(537,297),Vector2(507,262)]),
	PackedVector2Array([Vector2(625,194),Vector2(677,198),Vector2(731,214),Vector2(745,235),Vector2(695,222)]),
	PackedVector2Array([Vector2(1056,266),Vector2(1094,279),Vector2(1178,298),Vector2(1253,287),Vector2(1257,310),Vector2(1178,325),Vector2(1113,326),Vector2(1069,298)]),
	PackedVector2Array([Vector2(326,312),Vector2(362,301),Vector2(390,303),Vector2(365,317),Vector2(360,337),Vector2(389,357),Vector2(389,368),Vector2(355,370),Vector2(331,352),Vector2(318,329)]),
	PackedVector2Array([Vector2(438,442),Vector2(489,430),Vector2(557,418),Vector2(606,417),Vector2(623,428),Vector2(602,439),Vector2(542,453),Vector2(495,476),Vector2(461,493),Vector2(446,473)]),
	PackedVector2Array([Vector2(514,527),Vector2(555,519),Vector2(632,517),Vector2(687,516),Vector2(677,539),Vector2(641,555),Vector2(514,556)]),
	PackedVector2Array([Vector2(1384,345),Vector2(1471,343),Vector2(1477,359),Vector2(1440,357),Vector2(1401,376),Vector2(1387,366)]),
	PackedVector2Array([Vector2(1130,475),Vector2(1181,484),Vector2(1238,499),Vector2(1248,515),Vector2(1246,548),Vector2(1213,533),Vector2(1168,514),Vector2(1139,497)]),
	PackedVector2Array([Vector2(1250,499),Vector2(1304,509),Vector2(1358,529),Vector2(1376,544),Vector2(1355,548),Vector2(1291,534),Vector2(1252,518)]),
	PackedVector2Array([Vector2(873,656),Vector2(912,641),Vector2(928,639),Vector2(907,664),Vector2(902,679),Vector2(919,694),Vector2(956,693),Vector2(982,710),Vector2(985,724),Vector2(939,731),Vector2(893,722),Vector2(864,697),Vector2(861,676)]),
	PackedVector2Array([Vector2(1068,704),Vector2(1092,679),Vector2(1110,678),Vector2(1091,693),Vector2(1091,718),Vector2(1109,730),Vector2(1206,737),Vector2(1191,751),Vector2(1129,757),Vector2(1082,749),Vector2(1064,733)]),
	PackedVector2Array([Vector2(1154,779),Vector2(1233,780),Vector2(1232,808),Vector2(1219,814),Vector2(1183,807),Vector2(1167,795)]),
]

static func is_water_edge(point: Vector2, radius: float = 0.0) -> bool:
	for polygon in WATER_EDGES:
		if not Geometry2D.is_point_in_polygon(point,polygon): continue
		var fits := true
		for i in polygon.size():
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) < radius:
				fits = false
				break
		if fits: return true
	return false

static func dry_paths() -> Array:
	return [
		{"width":22.0,"points":PackedVector2Array([Vector2(15,26),Vector2(88,73),Vector2(125,141),Vector2(264,188),Vector2(354,262),Vector2(425,325),Vector2(462,376),Vector2(413,433),Vector2(275,463),Vector2(161,526),Vector2(24,483)])},
		{"width":22.0,"points":PackedVector2Array([Vector2(811,12),Vector2(830,80),Vector2(887,118),Vector2(911,160),Vector2(877,230),Vector2(850,296),Vector2(779,340),Vector2(755,404),Vector2(781,475),Vector2(842,533),Vector2(881,594),Vector2(857,659),Vector2(836,739),Vector2(725,784),Vector2(595,807),Vector2(459,841),Vector2(315,910)])},
		{"width":23.0,"points":PackedVector2Array([Vector2(1700,161),Vector2(1590,203),Vector2(1495,250),Vector2(1399,283),Vector2(1295,317),Vector2(1214,352),Vector2(1298,390),Vector2(1396,427),Vector2(1445,455),Vector2(1476,509),Vector2(1410,563),Vector2(1391,609),Vector2(1511,654),Vector2(1697,726)])},
		{"width":22.0,"points":PackedVector2Array([Vector2(840,746),Vector2(920,782),Vector2(975,827),Vector2(988,908)])}
	]

static func is_walkable(point: Vector2, radius: float = FOOT_RADIUS) -> bool:
	if not point.is_finite() or radius < 0: return false
	if Gates.blocks(point,radius): return false
	if Geometry2D.is_point_in_polygon(point,ROAD_EDGE) or is_water_edge(point): return true
	if not Geometry2D.is_point_in_polygon(point,OUTLINE): return false
	for i in OUTLINE.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,OUTLINE[i],OUTLINE[(i+1)%OUTLINE.size()])) < radius: return false
	for island in ISLANDS:
		if ((point-Vector2(island.x,island.y))/(Vector2(island.z,island.w)+Vector2.ONE*radius)).length() <= 1.0: return false
	return true

static func terrain_multiplier(point: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(point,ROAD_EDGE): return 1.0
	if is_water_edge(point): return WATER_SPEED
	for road in dry_paths():
		for i in range(road.points.size()-1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[i],road.points[i+1])) <= road.width: return 1.0
	return WATER_SPEED

static func move_on_road(origin: Vector2, displacement: Vector2) -> Vector2:
	if not is_walkable(origin) or not displacement.is_finite(): return origin
	var count := maxi(1,ceili(displacement.length()/2.0))
	var step := displacement/float(count)
	var current := origin
	for i in count:
		if is_walkable(current+step): current += step
		elif is_walkable(current+Vector2(step.x,0)): current.x += step.x
		elif is_walkable(current+Vector2(0,step.y)): current.y += step.y
	return current
