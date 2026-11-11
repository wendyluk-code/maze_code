extends RefCounted
## 优化前的零半径水域与范围采样，用独立旧路径核对几何结果。
const Water = preload("res://data/maze/fenshui_encounters.gd")
const Roads = preload("res://data/maze/fenshui_roads.gd")

static func water_edge(point: Vector2) -> bool:
	for polygon in Roads.WATER_EDGES:
		if not Geometry2D.is_point_in_polygon(point,polygon): continue
		var fits := true
		for i in polygon.size():
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]))<0.0:
				fits = false
				break
		if fits: return true
	return false

static func walkable(point: Vector2) -> bool:
	if not point.is_finite() or Roads.Gates.blocks(point,0.0): return false
	if Geometry2D.is_point_in_polygon(point,Roads.ROAD_EDGE) or water_edge(point): return true
	if not Geometry2D.is_point_in_polygon(point,Roads.OUTLINE): return false
	return not Roads.island_blocks(point,0.0,false)

static func terrain(point: Vector2) -> float:
	if Roads.on_low_island(point): return 1.0
	if Geometry2D.is_point_in_polygon(point,Roads.ROAD_EDGE): return 1.0
	if water_edge(point): return Roads.WATER_SPEED
	for road in Roads.dry_paths():
		for i in range(road.points.size()-1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[i],road.points[i+1]))<=road.width: return 1.0
	return Roads.WATER_SPEED

static func water(point: Vector2) -> bool:
	return not Water.protected(point,0.0) and walkable(point) and terrain(point)==Roads.WATER_SPEED

static func polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var shape := PackedVector2Array()
	if not water(center): return shape
	var reach: Array[float] = []
	for i in 128:
		var direction := Vector2.RIGHT.rotated(TAU*i/128.0)
		var length := 0.0
		for step in range(1,ceili(radius/2.0)+1):
			var distance := minf(step*2.0,radius)
			if not water(center+direction*distance): break
			length = distance
		reach.append(length)
	for i in 128:
		var length := minf(reach[i],minf(reach[(i+1)%128],reach[(i+127)%128]))
		shape.append(center+Vector2.RIGHT.rotated(TAU*i/128.0)*length)
	return shape
