extends RefCounted
## 行走地图到浅层总图的地标网格。坐标均为各自原图像素，北朝上。
const SIZE := Vector2(1672, 941)
const Roads := preload("res://data/maze/entry_roads.gd")
static var _road_mask: Image
static var _road_texture: ImageTexture
var WORLD := PackedVector2Array([
	Vector2(0,0), Vector2(1222,0), Vector2(1222,1287), Vector2(0,1287),
	Vector2(1104,153), Vector2(933,269), Vector2(688,396),
	Vector2(534,499), Vector2(392,694), Vector2(270,705), Vector2(116,724), Vector2(13,699),
	Vector2(477,766), Vector2(636,909), Vector2(699,1073), Vector2(654,1069),
	Vector2(854,1204), Vector2(983,1132), Vector2(1134,869), Vector2(1060,636),
	Vector2(898,521), Vector2(755,448), Vector2(799,888), Vector2(860,725), Vector2(745,642),
	# 左出口延伸到原图边界，避免近边地标与两个远端角点形成未覆盖的细长三角形。
	Vector2(0,695)
])
var ATLAS := PackedVector2Array([
	Vector2(1080,70), Vector2(1630,60), Vector2(1620,615), Vector2(1100,615),
	Vector2(1554,139), Vector2(1450,200), Vector2(1350,243),
	Vector2(1283,286), Vector2(1270,337), Vector2(1234,373), Vector2(1200,398), Vector2(1160,412),
	Vector2(1270,397), Vector2(1325,383), Vector2(1348,478), Vector2(1340,497),
	Vector2(1430,579), Vector2(1491,550), Vector2(1545,421), Vector2(1486,363),
	Vector2(1420,338), Vector2(1400,273), Vector2(1390,440), Vector2(1380,375), Vector2(1359,334),
	Vector2(1155,414)
])
var _triangles: PackedInt32Array

func _init() -> void:
	_triangles = Geometry2D.triangulate_delaunay(WORLD)

func project(point: Vector2) -> Vector2:
	# 外框覆盖整个正式地图，分片仿射使跨地标移动连续，资源沿用同一变换。
	for i in range(0, _triangles.size(), 3):
		var ia := _triangles[i]
		var ib := _triangles[i + 1]
		var ic := _triangles[i + 2]
		var a := WORLD[ia]
		var ab := WORLD[ib] - a
		var ac := WORLD[ic] - a
		var offset := point - a
		var denominator := ab.cross(ac)
		var b := offset.cross(ac) / denominator
		var c := ab.cross(offset) / denominator
		if b >= -0.0001 and c >= -0.0001 and b + c <= 1.0001:
			return ATLAS[ia] * (1.0 - b - c) + ATLAS[ib] * b + ATLAS[ic] * c
	return ATLAS[4]

static func _ellipse(point: Vector2, center: Vector2, radius: Vector2) -> float:
	return ((point - center) / radius).length() - 1.0

static func is_revealed(point: Vector2, unlocked: bool) -> bool:
	if not unlocked:
		return false
	road_texture()
	var pixel := Vector2i(point.floor())
	if Rect2i(Vector2i.ZERO, Vector2i(SIZE)).has_point(pixel) and _road_mask.get_pixelv(pixel).r >= 0.99:
		return true
	# 与 shallow_map_fog.gdshader 的揭示区域一致，标记保守留在清晰区域内。
	for ellipse in [Vector4(1560,125,92,88), Vector4(1434,203,112,66), Vector4(822,487,147,110), Vector4(898,211,182,110)]:
		var radius := Vector2(ellipse.z, ellipse.w)
		if _ellipse(point, Vector2(ellipse.x, ellipse.y), radius) * minf(radius.x, radius.y) <= -12.0:
			return true
	var route := PackedVector2Array([Vector2(1390,220),Vector2(1320,250),Vector2(1283,286),Vector2(1270,337),Vector2(1210,388),Vector2(1160,412),Vector2(1093,403),Vector2(1040,437),Vector2(1005,478),Vector2(918,501)])
	for i in range(route.size() - 1):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, route[i], route[i+1])) <= 20.0:
			return true
	if point.distance_to(Geometry2D.get_closest_point_to_segment(point, Vector2(1554,139), Vector2(1450,200))) <= 24.0:
		return true
	var salt := PackedVector2Array([Vector2(828,417),Vector2(850,365),Vector2(818,315),Vector2(785,288),Vector2(801,252)])
	for i in range(salt.size() - 1):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, salt[i], salt[i+1])) <= 26.0:
			return true
	return false

static func road_texture() -> ImageTexture:
	if _road_texture != null:
		return _road_texture
	# 合并真实道路与已确认的完整区域；两种地图和资源可见性共用这份缓存。
	_road_mask = Image.create(int(SIZE.x), int(SIZE.y), false, Image.FORMAT_R8)
	_road_mask.fill(Color.BLACK)
	var projection := new()
	for road in Roads.roads():
		var points: PackedVector2Array = road.points
		for i in range(points.size() - 1):
			var low := (points[i].min(points[i+1]) - Vector2.ONE * float(road.width)).max(Vector2.ZERO)
			var high := (points[i].max(points[i+1]) + Vector2.ONE * float(road.width)).min(Roads.SIZE)
			# 在世界坐标采样道路面，避免畸变地标三角形被误扩成巨大圆。
			for y in range(floori(low.y),ceili(high.y)+1,4):
				for x in range(floori(low.x),ceili(high.x)+1,4):
					var world := Vector2(x,y)
					if world.distance_to(Geometry2D.get_closest_point_to_segment(world,points[i],points[i+1])) <= float(road.width):
						_stamp_road(projection.project(world),7.0)
	_reveal_entry_region()
	_road_mask.generate_mipmaps()
	_road_texture = ImageTexture.create_from_image(_road_mask)
	return _road_texture

static func _reveal_entry_region() -> void:
	# 用户红线换算到 1672×941 总图像素：盐池北侧、入口、旧城长廊及枯水渠全域。
	# 保留凹边，不能用包围矩形揭开圈外的水轮工坊等区域。
	var boundary := PackedVector2Array([
		Vector2(852,99), Vector2(895,33), Vector2(977,31), Vector2(1049,51),
		Vector2(1146,66), Vector2(1209,91), Vector2(1263,134), Vector2(1305,132),
		Vector2(1317,96), Vector2(1359,54), Vector2(1423,23), Vector2(1486,-2),
		Vector2(1585,-2), Vector2(1632,19), Vector2(1674,61), Vector2(1679,125),
		Vector2(1657,195), Vector2(1641,267), Vector2(1639,322), Vector2(1665,371),
		Vector2(1676,434), Vector2(1671,504), Vector2(1665,549), Vector2(1611,577),
		Vector2(1535,612), Vector2(1481,629), Vector2(1428,620), Vector2(1383,582),
		Vector2(1334,521), Vector2(1280,470), Vector2(1226,425), Vector2(1183,422),
		Vector2(1132,439), Vector2(1066,450), Vector2(974,443), Vector2(918,439),
		Vector2(883,416), Vector2(864,383), Vector2(871,352), Vector2(899,324),
		Vector2(953,303), Vector2(1009,289), Vector2(1056,267), Vector2(1061,246),
		Vector2(1019,230), Vector2(965,209), Vector2(916,185), Vector2(876,159),
		Vector2(853,131)
	])
	var bounds := Rect2(boundary[0], Vector2.ZERO)
	for point in boundary:
		bounds = bounds.expand(point)
	for y in range(maxi(0,floori(bounds.position.y)), mini(int(SIZE.y),ceili(bounds.end.y)+1)):
		for x in range(maxi(0,floori(bounds.position.x)), mini(int(SIZE.x),ceili(bounds.end.x)+1)):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5), boundary):
				_road_mask.set_pixel(x,y,Color.WHITE)
	# 圈内保持全亮，只在轮廓外延续已有遮罩的柔边。
	for i in boundary.size():
		var start := boundary[i]
		var end := boundary[(i+1)%boundary.size()]
		var steps := maxi(1,ceili(start.distance_to(end)/4.0))
		for step in range(steps+1):
			_stamp_road(start.lerp(end,float(step)/steps),0.0,32.0)

static func _stamp_road(center: Vector2, radius: float, feather: float = 2.0) -> void:
	var outer := radius + feather
	for y in range(maxi(0,floori(center.y-outer)), mini(int(SIZE.y),ceili(center.y+outer)+1)):
		for x in range(maxi(0,floori(center.x-outer)), mini(int(SIZE.x),ceili(center.x+outer)+1)):
			var distance := Vector2(x,y).distance_to(center)
			var value := 1.0 - smoothstep(radius, outer, distance)
			if value > _road_mask.get_pixel(x,y).r:
				_road_mask.set_pixel(x,y,Color(value,value,value))
