extends Node2D
## interactive point: registers to interactable group and shows a display name
@export var display_name := "interaction"
## 按钮显示位置相对交互点的偏移（世界坐标，像素），不影响交互触发点
@export var ui_offset := Vector2.ZERO
## 道具贴近地图外缘时使用手工边界；封闭道具从 WalkZone 提取掩码岛。
@export var interaction_polygon: PackedVector2Array = PackedVector2Array()
## 视觉前景区域，与交互/碰撞轮廓分离。仅包含需要在角色身前重绘的表面。
@export var foreground_polygon: PackedVector2Array = PackedVector2Array()
## 脚底深度区域：脚底落在其中时，显示 foreground_polygon。
## 这是每个道具独立校准的局部区域，而不是交互轮廓的水平线。
@export var occlusion_polygon: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	add_to_group("interactable")

func interaction_distance_from(world_point: Vector2) -> float:
	var region := world_interaction_polygon()
	if region.size() < 3:
		return world_point.distance_to(global_position)
	if Geometry2D.is_point_in_polygon(world_point, region):
		return 0.0
	var best := INF
	for i in region.size():
		var closest := Geometry2D.get_closest_point_to_segment(
			world_point, region[i], region[(i + 1) % region.size()]
		)
		best = minf(best, world_point.distance_to(closest))
	return best

func world_interaction_polygon() -> PackedVector2Array:
	var local_polygon := interaction_polygon
	if local_polygon.size() < 3:
		var zone := get_tree().get_first_node_in_group("walk_zone") as Node2D
		if zone != null and zone.has_method("nearest_obstacle"):
			local_polygon = zone.nearest_obstacle(zone.to_local(global_position))
			var world_polygon := PackedVector2Array()
			for point in local_polygon:
				world_polygon.append(zone.to_global(point))
			return world_polygon
	var world_polygon := PackedVector2Array()
	for point in local_polygon:
		world_polygon.append(to_global(point))
	return world_polygon

func world_foreground_polygon() -> PackedVector2Array:
	return _world_polygon_from_local(foreground_polygon)

func world_occlusion_polygon() -> PackedVector2Array:
	return _world_polygon_from_local(occlusion_polygon)

func _world_polygon_from_local(local_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon := PackedVector2Array()
	for point in local_polygon:
		world_polygon.append(to_global(point))
	return world_polygon
