extends "res://data/maze/entry_map_projection.gd"
## 五段土路按源图地标映射到浅层总图；入口与分水庭共用同一锚点。
func _init() -> void:
	WORLD = PackedVector2Array([Vector2(0,0),Vector2(1484,0),Vector2(1484,1060),Vector2(0,1060),Vector2(0,359),Vector2(240,447),Vector2(384,422),Vector2(502,359),Vector2(551,289),Vector2(650,575),Vector2(727,534),Vector2(778,490),Vector2(1265,622),Vector2(1371,628),Vector2(1484,676),Vector2(1100,738),Vector2(1080,781),Vector2(1147,870),Vector2(1208,1015),Vector2(1208,1060),Vector2(728,885),Vector2(680,960),Vector2(664,1060)])
	ATLAS = PackedVector2Array([Vector2(224,0),Vector2(693,0),Vector2(693,350),Vector2(224,350),Vector2(234,161),Vector2(290,168),Vector2(330,160),Vector2(348,128),Vector2(367,107),Vector2(363,237),Vector2(411,222),Vector2(443,202),Vector2(574,227),Vector2(624,234),Vector2(662,263),Vector2(553,264),Vector2(550,283),Vector2(577,319),Vector2.ZERO,Vector2(611,380),Vector2(427,312),Vector2(413,338),Vector2(398,366)])
	ATLAS[18] = preload("res://data/maze/fenshui_projection.gd").new().project(preload("res://data/maze/moss_pool_roads.gd").FENSHUI_PORTAL)
	_triangles = Geometry2D.triangulate_delaunay(WORLD)
	# 路标两端同一总图锚点，邻近道路保持连续插值。
	WORLD.append(preload("res://data/maze/moss_pool_roads.gd").SALT_MARKER)
	ATLAS.append(preload("res://data/maze/moss_pool_roads.gd").SALT_LINK_ATLAS)
	_triangles = Geometry2D.triangulate_delaunay(WORLD)

func project_direction(point: Vector2, direction: Vector2) -> Vector2:
	return (project(point+direction*2.0)-project(point)).normalized()
