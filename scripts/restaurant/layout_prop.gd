@tool
extends Node2D
## 编辑器道具：根节点是落地排序点，子节点保存图片、交互轮廓和碰撞。
@export var display_name := "装饰"
@export var interactive := false
@export var ui_offset := Vector2(0, -100)
## 主角脚底在根节点左侧时，图片退到主角后方；其他方向沿用落地点排序。
@export var player_in_front_on_left := false
var _art_base_z := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if interactive:
		add_to_group("interactable")
	set_meta("foreground_disabled", true)
	set_meta("use_own_ui_anchor", true)
	var art := get_node_or_null("Art") as Sprite2D
	if art != null:
		_art_base_z = art.z_index
	set_process(player_in_front_on_left)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var art := get_node_or_null("Art") as Sprite2D
	if art == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var foot := player.get_node_or_null("Collision") as Node2D if is_instance_valid(player) else null
	var point := foot.global_position if foot != null else (player.global_position if is_instance_valid(player) else global_position)
	art.z_index = _art_base_z - 1 if is_instance_valid(player) and point.x < global_position.x else _art_base_z

func world_interaction_polygon() -> PackedVector2Array:
	var outline := get_node_or_null("InteractionArea") as Polygon2D
	if outline != null and outline.polygon.size() >= 3:
		return _world_polygon(outline, outline.polygon)
	return world_collision_polygon()

func world_collision_polygon() -> PackedVector2Array:
	var shape := get_node_or_null("Body/Collision") as CollisionPolygon2D
	if shape == null or shape.disabled:
		return PackedVector2Array()
	return _world_polygon(shape, shape.polygon)

func interaction_distance_from(point: Vector2) -> float:
	var polygon := world_interaction_polygon()
	if polygon.size() < 3:
		return point.distance_to(global_position)
	if Geometry2D.is_point_in_polygon(point, polygon):
		return 0.0
	var distance := INF
	for i in polygon.size():
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])))
	return distance

func _world_polygon(node: Node2D, points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(node.to_global(point))
	return result
