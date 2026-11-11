extends "res://data/maze/entry_map_projection.gd"
## 飞书原图土路映射到浅层总图；各跨区路标保留原共用锚点。
var _main_world := PackedVector2Array([Vector2(1140,1080),Vector2(1120,1070),Vector2(1100,1030),Vector2(1075,1000),Vector2(1050,950),Vector2(1030,910),Vector2(1005,870),Vector2(974,824),Vector2(945,800)])
var _main_atlas := PackedVector2Array()
func _init() -> void:
	WORLD = PackedVector2Array([Vector2(0,0),Vector2(1408,0),Vector2(1408,1117),Vector2(0,1117),Vector2(0,430),Vector2(188,469),Vector2(350,382),Vector2(434,299),Vector2(423,270),Vector2(580,505),Vector2(667,575),Vector2(560,646),Vector2(920,498),Vector2(970,435),Vector2(1000,345),Vector2(1060,702),Vector2(1315,710),Vector2(1408,742),Vector2(1140,1080),Vector2(490,860),Vector2(570,941),Vector2(350,1035)])
	ATLAS = PackedVector2Array([Vector2(224,0),Vector2(693,0),Vector2(693,350),Vector2(224,350),Vector2(234,161),Vector2(290,168),Vector2(330,160),Vector2(348,128),Vector2(367,107),Vector2(363,237),Vector2(411,222),Vector2(443,202),Vector2(574,227),Vector2(624,234),Vector2(662,263),Vector2(574,227),Vector2(624,234),Vector2(677,270),Vector2.ZERO,Vector2(427,312),Vector2(413,338),Vector2(398,366)])
	ATLAS[18] = preload("res://data/maze/fenshui_projection.gd").new().project(preload("res://data/maze/moss_pool_roads.gd").FENSHUI_PORTAL)
	# 同一条可达土路贯穿青苔池，沿总图道路向西接小屋，不把可站立入口留在东南角。
	_main_atlas = PackedVector2Array([ATLAS[18],Vector2(574,227),Vector2(530,227),Vector2(498,223),Vector2(450,227),Vector2(418,239),Vector2(335,193),Vector2(313,164),preload("res://data/maze/waterkeeper_cottage_roads.gd").LINK_ATLAS])
	# 路边也使用相同地标，离开主路窄带时不跳回旧底图的插值。
	for i in _main_world.size():
		if WORLD.find(_main_world[i])<0:
			WORLD.append(_main_world[i])
			ATLAS.append(_main_atlas[i])
	_triangles = Geometry2D.triangulate_delaunay(WORLD)
	# 路标两端同一总图锚点，邻近道路保持连续插值。
	WORLD.append(preload("res://data/maze/waterkeeper_cottage_roads.gd").MOSS_MARKER)
	ATLAS.append(preload("res://data/maze/waterkeeper_cottage_roads.gd").LINK_ATLAS)
	WORLD.append(preload("res://data/maze/moss_pool_roads.gd").SALT_MARKER)
	ATLAS.append(preload("res://data/maze/moss_pool_roads.gd").SALT_LINK_ATLAS)
	_triangles = Geometry2D.triangulate_delaunay(WORLD)

func project(point: Vector2) -> Vector2:
	var nearest := 22.0
	var segment := -1
	var closest := Vector2.ZERO
	for i in range(_main_world.size()-1):
		var candidate := Geometry2D.get_closest_point_to_segment(point,_main_world[i],_main_world[i+1])
		var distance := point.distance_to(candidate)
		if distance<nearest:
			nearest=distance
			segment=i
			closest=candidate
	if segment>=0:
		var source := _main_world[segment+1]-_main_world[segment]
		var mapped := _main_atlas[segment+1]-_main_atlas[segment]
		var fraction := clampf((closest-_main_world[segment]).dot(source)/source.length_squared(),0,1)
		var lateral := (point-closest).dot(Vector2(-source.y,source.x).normalized())
		return _main_atlas[segment].lerp(_main_atlas[segment+1],fraction)+Vector2(-mapped.y,mapped.x).normalized()*lateral*0.15
	return super.project(point)

func project_direction(point: Vector2, direction: Vector2) -> Vector2:
	return (project(point+direction*2.0)-project(point)).normalized()
