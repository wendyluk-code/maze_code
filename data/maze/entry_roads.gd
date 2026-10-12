extends RefCounted
## 原图像素坐标；不使用生成掩码，也不改变地图原图。
const SIZE := Vector2(1222, 1287)
const ENTRANCE := Vector2(1104, 153)
const SPAWN := Vector2(1088, 170)
const FOOT_RADIUS := 4.0
const GATE := Vector2(654, 1069)
const EXIT := Vector2(13, 699)
const MONSTER := Vector2(933, 269)
const TEAM := Vector2(497, 779)

static func roads() -> Array:
	return [
		# 石门、旧城长廊至环路北端。
		{"width": 24.0, "points": PackedVector2Array([Vector2(1117,126), Vector2(1104,153), Vector2(1061,188), Vector2(995,225), Vector2(933,269), Vector2(860,295), Vector2(790,326), Vector2(725,369), Vector2(688,396)])},
		# 枯水渠完整环路：首尾相接，栅栏不参与主路裁剪。
		{"width": 23.0, "points": PackedVector2Array([Vector2(688,396), Vector2(613,421), Vector2(552,455), Vector2(534,499), Vector2(527,544), Vector2(497,578), Vector2(448,603), Vector2(413,646), Vector2(392,694), Vector2(425,730), Vector2(477,766), Vector2(539,789), Vector2(602,807), Vector2(633,851), Vector2(636,909), Vector2(669,948), Vector2(707,991), Vector2(691,1037), Vector2(699,1073), Vector2(736,1119), Vector2(795,1170), Vector2(854,1204), Vector2(918,1208), Vector2(965,1181), Vector2(983,1132), Vector2(995,1072), Vector2(1029,1006), Vector2(1082,954), Vector2(1126,906), Vector2(1134,869), Vector2(1101,813), Vector2(1086,755), Vector2(1091,704), Vector2(1094,670), Vector2(1060,636), Vector2(1007,610), Vector2(956,582), Vector2(926,551), Vector2(898,521), Vector2(839,503), Vector2(786,481), Vector2(755,448), Vector2(741,414), Vector2(688,396)])},
		# 左中出口的整段道路，提示只在图像边缘。
		{"width": 22.0, "points": PackedVector2Array([Vector2(392,694), Vector2(330,691), Vector2(270,705), Vector2(191,720), Vector2(116,724), Vector2(57,711), Vector2(0,695)])},
		# 环内可见的相连岔路；末端在树丛前，不跨越沟壑。
		{"width": 19.0, "points": PackedVector2Array([Vector2(669,948), Vector2(734,922), Vector2(799,888), Vector2(852,858), Vector2(869,819), Vector2(862,771), Vector2(860,725), Vector2(849,695), Vector2(813,675), Vector2(773,658), Vector2(745,642)])},
		# 栅栏上侧的小段支路，止于栅栏前；可从主环靠近。
		{"width": 17.0, "points": PackedVector2Array([Vector2(699,1073), Vector2(676,1069), Vector2(653,1064)])}
	]

static func is_walkable(point: Vector2, radius: float = FOOT_RADIUS) -> bool:
	if not point.is_finite() or radius < 0.0:
		return false
	if point.x < radius or point.y < radius or point.x > SIZE.x - radius or point.y > SIZE.y - radius:
		return false
	# 栅栏实体及其下方不允许绕行；只覆盖支路，距离主环至少 30 像素。
	if point.y + radius > 1081.0 and point.x - radius < 684.0:
		return false
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
