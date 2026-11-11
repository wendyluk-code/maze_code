extends "res://data/maze/entry_map_projection.gd"
## 小屋、石桥和南侧止步道路对齐总图地标；连接与青苔池共用一个标记。
func _init() -> void:
	WORLD = PackedVector2Array([Vector2(0,0),Vector2(1672,0),Vector2(1672,941),Vector2(0,941),Vector2(1620,163),Vector2(1090,340),Vector2(700,350),Vector2(300,795)])
	ATLAS = PackedVector2Array([Vector2(65,65),Vector2(300,65),Vector2(300,280),Vector2(65,280),preload("res://data/maze/waterkeeper_cottage_roads.gd").LINK_ATLAS,Vector2(273,163),Vector2(149,183),Vector2(187,250)])
	_triangles = Geometry2D.triangulate_delaunay(WORLD)

func project_direction(point: Vector2, direction: Vector2) -> Vector2:
	return (project(point+direction*2.0)-project(point)).normalized()
