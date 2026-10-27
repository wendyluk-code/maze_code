extends RefCounted
## 已确认盐池原图坐标；可走地面减去水池、晶簇、植被与石块占地。
const SIZE := Vector2(1615,974)
const SPAWN := Vector2(670,840)
const ENTRANCE := Vector2(640,900)
const INTERACT_RADIUS := 85.0
const FOOT_RADIUS := 4.0
const FENSHUI_PORTAL := Vector2(830,80)
const FENSHUI_RETURN := Vector2(867,115)
static var OUTLINE := PackedVector2Array([
 Vector2(0,365),Vector2(80,360),Vector2(145,382),Vector2(235,413),Vector2(290,430),Vector2(335,418),Vector2(380,385),Vector2(390,365),Vector2(365,340),Vector2(345,307),Vector2(390,307),Vector2(440,286),Vector2(477,270),Vector2(475,250),Vector2(433,224),Vector2(404,191),Vector2(442,177),Vector2(450,187),Vector2(451,211),Vector2(501,228),Vector2(560,237),Vector2(609,225),Vector2(652,203),Vector2(695,195),Vector2(679,217),Vector2(669,242),Vector2(690,258),Vector2(735,262),Vector2(785,237),Vector2(794,252),Vector2(763,278),Vector2(756,299),Vector2(790,312),Vector2(790,332),Vector2(830,342),Vector2(850,359),Vector2(896,361),Vector2(914,393),Vector2(950,401),Vector2(977,386),Vector2(965,348),Vector2(976,330),Vector2(946,298),Vector2(935,277),Vector2(978,272),Vector2(997,249),Vector2(1009,227),Vector2(992,210),Vector2(959,185),Vector2(960,171),Vector2(1006,181),Vector2(1040,175),Vector2(1072,153),Vector2(1072,124),Vector2(1090,106),Vector2(1094,88),Vector2(1136,91),Vector2(1111,121),Vector2(1115,139),Vector2(1150,156),Vector2(1195,159),Vector2(1244,148),Vector2(1264,131),Vector2(1289,137),Vector2(1276,146),Vector2(1255,157),Vector2(1241,180),Vector2(1270,211),Vector2(1303,226),Vector2(1344,229),Vector2(1321,254),Vector2(1340,278),Vector2(1356,298),Vector2(1349,319),Vector2(1362,337),Vector2(1410,342),Vector2(1484,339),Vector2(1495,351),Vector2(1460,382),Vector2(1438,411),Vector2(1410,424),Vector2(1407,447),Vector2(1425,461),Vector2(1395,474),Vector2(1355,467),Vector2(1334,480),Vector2(1314,497),Vector2(1320,515),Vector2(1364,526),Vector2(1407,520),Vector2(1397,539),Vector2(1360,544),Vector2(1355,565),Vector2(1386,591),Vector2(1395,611),Vector2(1357,613),Vector2(1323,608),Vector2(1295,624),Vector2(1283,649),Vector2(1255,675),Vector2(1210,670),Vector2(1180,687),Vector2(1146,709),Vector2(1108,702),Vector2(1085,683),Vector2(1054,671),Vector2(1025,647),Vector2(984,631),Vector2(950,641),Vector2(924,666),Vector2(940,679),Vector2(909,699),Vector2(873,715),Vector2(831,723),Vector2(794,709),Vector2(772,722),Vector2(761,748),Vector2(736,762),Vector2(735,786),Vector2(714,812),Vector2(702,843),Vector2(709,877),Vector2(734,893),Vector2(715,918),Vector2(695,934),Vector2(690,974),Vector2(540,974),Vector2(561,945),Vector2(581,915),Vector2(606,905),Vector2(620,873),Vector2(612,834),Vector2(613,808),Vector2(587,783),Vector2(568,766),Vector2(592,759),Vector2(621,777),Vector2(655,790),Vector2(680,781),Vector2(696,753),Vector2(688,730),Vector2(655,711),Vector2(621,695),Vector2(589,670),Vector2(551,661),Vector2(536,647),Vector2(539,614),Vector2(522,583),Vector2(490,568),Vector2(443,554),Vector2(398,549),Vector2(365,552),Vector2(312,559),Vector2(297,540),Vector2(271,531),Vector2(239,512),Vector2(233,486),Vector2(201,467),Vector2(167,450),Vector2(113,429),Vector2(82,420),Vector2(48,424),Vector2(0,418)])
# 多边形按真实岸线描绘，避免旧椭圆阻挡把岸边误作水面或漏掉水湾。
static var BLOCKERS: Array[PackedVector2Array] = [
 PackedVector2Array([Vector2(650,448),Vector2(679,430),Vector2(725,418),Vector2(771,412),Vector2(801,417),Vector2(820,437),Vector2(819,459),Vector2(836,473),Vector2(877,478),Vector2(916,489),Vector2(952,508),Vector2(980,530),Vector2(988,548),Vector2(977,570),Vector2(949,588),Vector2(908,594),Vector2(881,611),Vector2(840,626),Vector2(800,627),Vector2(773,613),Vector2(750,593),Vector2(730,570),Vector2(735,552),Vector2(727,536),Vector2(702,527),Vector2(678,513),Vector2(667,488),Vector2(650,476)]),
 PackedVector2Array([Vector2(1023,375),Vector2(1047,360),Vector2(1076,359),Vector2(1101,373),Vector2(1111,388),Vector2(1145,393),Vector2(1174,390),Vector2(1204,410),Vector2(1225,428),Vector2(1235,455),Vector2(1223,480),Vector2(1202,500),Vector2(1178,510),Vector2(1149,510),Vector2(1127,490),Vector2(1102,477),Vector2(1088,458),Vector2(1059,457),Vector2(1024,448),Vector2(1015,429),Vector2(1023,411)]),
 PackedVector2Array([Vector2(1090,185),Vector2(1118,175),Vector2(1147,185),Vector2(1166,207),Vector2(1194,222),Vector2(1227,245),Vector2(1234,264),Vector2(1220,284),Vector2(1227,302),Vector2(1239,319),Vector2(1223,337),Vector2(1194,342),Vector2(1174,332),Vector2(1166,303),Vector2(1148,276),Vector2(1150,252),Vector2(1129,238),Vector2(1104,228),Vector2(1086,211),Vector2(1080,198)]),
 PackedVector2Array([Vector2(575,291),Vector2(598,281),Vector2(620,288),Vector2(639,300),Vector2(664,308),Vector2(675,327),Vector2(664,344),Vector2(665,364),Vector2(646,378),Vector2(624,376),Vector2(604,364),Vector2(599,343),Vector2(579,332),Vector2(568,315)]),
 PackedVector2Array([Vector2(444,341),Vector2(467,330),Vector2(493,333),Vector2(516,327),Vector2(536,342),Vector2(553,369),Vector2(560,397),Vector2(536,405),Vector2(506,407),Vector2(478,400),Vector2(456,391),Vector2(443,370),Vector2(433,359)]),
 PackedVector2Array([Vector2(1115,324),Vector2(1133,307),Vector2(1146,279),Vector2(1163,278),Vector2(1182,309),Vector2(1195,332),Vector2(1192,352),Vector2(1168,362),Vector2(1133,354),Vector2(1111,343)]),
 PackedVector2Array([Vector2(1263,375),Vector2(1290,368),Vector2(1318,382),Vector2(1337,400),Vector2(1340,414),Vector2(1320,430),Vector2(1295,434),Vector2(1272,424),Vector2(1263,406),Vector2(1255,391)]),
 PackedVector2Array([Vector2(1214,516),Vector2(1243,516),Vector2(1267,530),Vector2(1282,547),Vector2(1275,561),Vector2(1255,572),Vector2(1228,571),Vector2(1214,586),Vector2(1195,581),Vector2(1184,571),Vector2(1193,552),Vector2(1204,541)]),
 PackedVector2Array([Vector2(562,429),Vector2(583,419),Vector2(603,425),Vector2(612,442),Vector2(599,453),Vector2(578,456),Vector2(562,447)]),
 PackedVector2Array([Vector2(309,455),Vector2(342,437),Vector2(374,425),Vector2(400,421),Vector2(423,432),Vector2(431,449),Vector2(405,467),Vector2(366,483),Vector2(340,494),Vector2(318,490),Vector2(302,474)]),
 PackedVector2Array([Vector2(488,496),Vector2(513,479),Vector2(536,478),Vector2(548,490),Vector2(552,509),Vector2(581,521),Vector2(610,525),Vector2(642,532),Vector2(673,543),Vector2(680,561),Vector2(658,581),Vector2(665,608),Vector2(686,621),Vector2(709,634),Vector2(721,650),Vector2(711,667),Vector2(686,672),Vector2(667,659),Vector2(662,645),Vector2(624,637),Vector2(598,619),Vector2(586,597),Vector2(579,568),Vector2(558,552),Vector2(536,549),Vector2(514,527),Vector2(497,521)]),
 PackedVector2Array([Vector2(1004,569),Vector2(1022,550),Vector2(1044,545),Vector2(1064,555),Vector2(1081,577),Vector2(1101,590),Vector2(1109,606),Vector2(1091,618),Vector2(1064,620),Vector2(1043,609),Vector2(1021,608),Vector2(1004,592)]),
 PackedVector2Array([Vector2(815,676),Vector2(839,659),Vector2(857,660),Vector2(880,678),Vector2(885,693),Vector2(863,708),Vector2(840,705),Vector2(818,694)]),
 PackedVector2Array([Vector2(691,370),Vector2(713,355),Vector2(735,362),Vector2(754,382),Vector2(741,396),Vector2(715,400),Vector2(689,389)]),
 PackedVector2Array([Vector2(1020,273),Vector2(1035,255),Vector2(1056,254),Vector2(1081,271),Vector2(1079,292),Vector2(1067,313),Vector2(1043,314),Vector2(1030,299)]),
 PackedVector2Array([Vector2(1266,318),Vector2(1282,310),Vector2(1301,318),Vector2(1323,330),Vector2(1338,342),Vector2(1315,353),Vector2(1288,350),Vector2(1266,340)])
]
const OBSTACLES := [Vector4(1233,367,16,10),Vector4(1251,404,13,10),Vector4(1086,479,17,12)]
static var ROAD := PackedVector2Array([Vector2(0,390),Vector2(75,390),Vector2(155,421),Vector2(242,460),Vector2(289,509),Vector2(365,522),Vector2(424,516),Vector2(486,550),Vector2(530,585),Vector2(566,638),Vector2(606,662),Vector2(658,689),Vector2(712,716),Vector2(724,751),Vector2(692,798),Vector2(664,835),Vector2(656,879),Vector2(625,923),Vector2(615,974)])
static func terrain_multiplier(point: Vector2) -> float:
 for i in range(ROAD.size()-1):
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point,ROAD[i],ROAD[i+1]))<25.0: return 1.0
 return 0.5
static func _near_edge(point: Vector2, polygon: PackedVector2Array, radius: float) -> bool:
 for i in polygon.size():
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) < radius: return true
 return false
static func is_walkable(point: Vector2, radius: float = FOOT_RADIUS) -> bool:
 if not point.is_finite() or not is_finite(radius) or radius<0 or not Geometry2D.is_point_in_polygon(point,OUTLINE): return false
 if _near_edge(point,OUTLINE,radius): return false
 for polygon in BLOCKERS:
  if Geometry2D.is_point_in_polygon(point,polygon) or _near_edge(point,polygon,radius): return false
 for o in OBSTACLES:
  if ((point-Vector2(o.x,o.y))/(Vector2(o.z,o.w)+Vector2.ONE*radius)).length()<=1.0: return false
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

