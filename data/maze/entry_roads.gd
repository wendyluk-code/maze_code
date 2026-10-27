extends RefCounted
const SettlementExit = preload("res://data/maze/settlement_exit.gd")
## 原图像素坐标；不使用生成掩码，也不改变地图原图。
const SIZE := Vector2(1222, 1287)
const ENTRANCE := Vector2(1104, 153)
const SPAWN := Vector2(1073, 195)
const FOOT_RADIUS := 4.0
const GATE := Vector2(654, 1069)
const EXIT := Vector2(13, 699)
const MONSTER := Vector2(933, 269)
const TEAM := Vector2(497, 779)

static func roads() -> Array:
	return [
		# 石门、旧城长廊至环路北端。
		{"width": 24.0, "points": PackedVector2Array([Vector2(1117,126), Vector2(1104,153), Vector2(1061,188), Vector2(995,234), Vector2(933,278), Vector2(895,291), Vector2(860,295), Vector2(825,315), Vector2(790,337), Vector2(725,369), Vector2(688,396)])},
		# 枯水渠完整环路：首尾相接，栅栏不参与主路裁剪。
		{"width": 23.0, "points": PackedVector2Array([Vector2(688,396), Vector2(613,421), Vector2(571,441), Vector2(547,464), Vector2(534,499), Vector2(527,544), Vector2(497,578), Vector2(448,603), Vector2(413,646), Vector2(392,694), Vector2(425,730), Vector2(477,766), Vector2(539,789), Vector2(602,807), Vector2(633,851), Vector2(636,909), Vector2(669,948), Vector2(707,991), Vector2(721,1014), Vector2(724,1037), Vector2(728,1073), Vector2(741,1095), Vector2(762,1119), Vector2(795,1170), Vector2(854,1204), Vector2(918,1208), Vector2(965,1181), Vector2(983,1132), Vector2(995,1072), Vector2(1029,1006), Vector2(1082,954), Vector2(1126,906), Vector2(1134,869), Vector2(1101,813), Vector2(1086,755), Vector2(1081,704), Vector2(1081,678), Vector2(1060,651), Vector2(1037,634), Vector2(1007,610), Vector2(956,582), Vector2(926,551), Vector2(898,521), Vector2(839,503), Vector2(786,481), Vector2(755,448), Vector2(741,414), Vector2(688,396)])},
		# 左中出口的整段道路，提示只在图像边缘。
		{"width": 22.0, "points": PackedVector2Array([Vector2(392,694), Vector2(330,691), Vector2(270,705), Vector2(191,720), Vector2(116,724), Vector2(57,711), Vector2(0,695)])},
		# 环内可见的相连岔路；末端在树丛前，不跨越沟壑。
		{"width": 19.0, "points": PackedVector2Array([Vector2(669,948), Vector2(734,922), Vector2(799,888), Vector2(852,858), Vector2(869,819), Vector2(862,771), Vector2(853,732), Vector2(838,704), Vector2(813,686), Vector2(773,658), Vector2(745,642)])},
		# 栅栏上侧的小段支路，止于栅栏前；可从主环靠近。
		{"width": 17.0, "points": PackedVector2Array([Vector2(728,1073), Vector2(700,1072), Vector2(676,1069), Vector2(653,1064)])}
	]

## 用户红圈补充的脚底中心可走区，与原道路取并集，不扩大整张地图。
static func extra_walkable_areas() -> Array:
	return [
		PackedVector2Array([Vector2(1056,168),Vector2(1057,148),Vector2(1068,127),Vector2(1101,125),Vector2(1088,148),Vector2(1075,168)]),
		PackedVector2Array([Vector2(519,488),Vector2(519,461),Vector2(534,434),Vector2(576,407),Vector2(621,386),Vector2(663,379),Vector2(692,373),Vector2(722,350),Vector2(755,332),Vector2(727,362),Vector2(696,385),Vector2(659,397),Vector2(618,407),Vector2(576,422),Vector2(542,441),Vector2(532,464)]),
		PackedVector2Array([Vector2(389,677),Vector2(379,649),Vector2(380,617),Vector2(408,595),Vector2(454,568),Vector2(506,543),Vector2(475,572),Vector2(450,598),Vector2(427,631),Vector2(409,661)]),
		PackedVector2Array([Vector2(180,731),Vector2(210,718),Vector2(262,707),Vector2(313,703),Vector2(368,703),Vector2(368,714),Vector2(316,723),Vector2(261,736),Vector2(210,736)]),
		PackedVector2Array([Vector2(538,773),Vector2(572,772),Vector2(609,785),Vector2(632,808),Vector2(651,856),Vector2(670,910),Vector2(669,924),Vector2(653,925),Vector2(638,897),Vector2(622,856),Vector2(610,818),Vector2(588,804),Vector2(560,797)]),
		PackedVector2Array([Vector2(716,596),Vector2(727,615),Vector2(751,635),Vector2(794,652),Vector2(832,669),Vector2(863,689),Vector2(879,717),Vector2(884,758),Vector2(884,825),Vector2(863,861),Vector2(832,882),Vector2(835,841),Vector2(839,793),Vector2(836,746),Vector2(818,708),Vector2(798,685),Vector2(767,665),Vector2(741,642),Vector2(724,620)]),
		PackedVector2Array([Vector2(690,947),Vector2(733,924),Vector2(778,908),Vector2(814,900),Vector2(796,918),Vector2(758,937),Vector2(730,955),Vector2(731,985),Vector2(744,1021),Vector2(744,1055),Vector2(727,1032),Vector2(717,1001),Vector2(704,975)]),
		PackedVector2Array([Vector2(661,1049),Vector2(680,1028),Vector2(702,1009),Vector2(711,1015),Vector2(711,1057),Vector2(702,1063),Vector2(674,1059)]),
		PackedVector2Array([Vector2(763,1089),Vector2(785,1099),Vector2(812,1124),Vector2(838,1155),Vector2(880,1185),Vector2(879,1195),Vector2(855,1193),Vector2(819,1177),Vector2(795,1153),Vector2(776,1118)]),
		PackedVector2Array([Vector2(1080,644),Vector2(1102,662),Vector2(1118,686),Vector2(1119,717),Vector2(1101,736),Vector2(1101,758),Vector2(1112,785),Vector2(1144,821),Vector2(1163,852),Vector2(1170,876),Vector2(1155,907),Vector2(1127,946),Vector2(1096,976),Vector2(1077,991),Vector2(1052,1028),Vector2(1026,1079),Vector2(1010,1122),Vector2(1010,1158),Vector2(991,1192),Vector2(969,1202),Vector2(965,1176),Vector2(975,1124),Vector2(988,1073),Vector2(1009,1028),Vector2(1031,994),Vector2(1060,979),Vector2(1090,944),Vector2(1116,910),Vector2(1132,877),Vector2(1127,851),Vector2(1109,823),Vector2(1086,792),Vector2(1078,756),Vector2(1080,716)])
	]

static func is_walkable(point: Vector2, radius: float = FOOT_RADIUS) -> bool:
	if not point.is_finite() or radius < 0.0:
		return false
	if point.x - radius < SettlementExit.BLOCK_X:
		return false
	if point.x < radius or point.y < radius or point.x > SIZE.x - radius or point.y > SIZE.y - radius:
		return false
	# 栅栏实体及其下方不允许绕行；只覆盖支路，距离主环至少 30 像素。
	if point.y + radius > 1081.0 and point.x - radius < 684.0:
		return false
	for polygon in extra_walkable_areas():
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	for road in roads():
		var points: PackedVector2Array = road.points
		var clearance: float = road.width - radius
		if clearance < 0.0:
			continue
		for i in range(points.size() - 1):
			if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])) <= clearance * clearance:
				return true
	return false

static func move_on_road(origin: Vector2, displacement: Vector2) -> Vector2:
	if not is_walkable(origin) or not displacement.is_finite():
		return origin
	var count := maxi(1, ceili(displacement.length() / 2.0))
	var step := displacement / float(count)
	var current := origin
	for _i in count:
		var next := current + step
		if is_walkable(next):
			current = next
		elif is_walkable(current + Vector2(step.x, 0)):
			current.x += step.x
		elif is_walkable(current + Vector2(0, step.y)):
			current.y += step.y
	return current

