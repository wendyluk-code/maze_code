extends "res://scripts/walk_zone.gd"
## 餐厅专用：外边界与道具碰撞来自场景，不再读取旧图上的家具洞。
func _build_polygons() -> void:
	img_w = 1448
	img_h = 1086
	polygons.clear()
	var boundary := get_node("Boundary") as Polygon2D
	var outline := PackedVector2Array()
	for point in boundary.polygon:
		outline.append(to_local(boundary.to_global(point)))
	polygons.append(outline)
	_refresh_obstacles()

func _refresh_obstacles() -> void:
	obstacle_polys.clear()
	for prop in get_tree().get_nodes_in_group("restaurant_layout_props"):
		if not prop.has_method("world_collision_polygon"):
			continue
		var polygon: PackedVector2Array = prop.world_collision_polygon()
		var local := PackedVector2Array()
		for point in polygon:
			local.append(to_local(point))
		if local.size() >= 3:
			obstacle_polys.append(local)

func is_point_inside(point: Vector2) -> bool:
	_refresh_obstacles()
	return super.is_point_inside(point)

func is_circle_inside(point: Vector2, radius: float, epsilon: float = FOOTPRINT_EPSILON) -> bool:
	_refresh_obstacles()
	return super.is_circle_inside(point, radius, epsilon)

func nearest_obstacle(point: Vector2) -> PackedVector2Array:
	_refresh_obstacles()
	return super.nearest_obstacle(point)
