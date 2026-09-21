extends Node2D
## 从扁平餐厅底图采样道具前景。
## 交互轮廓、视觉前景和脚底深度区域彼此独立：只有脚底落在道具
## 自己校准的 occlusion_polygon 内时，才重绘 foreground_polygon。
## 对带有 `occlusion_body_visible_height` 元数据的道具，前景还会在角色
## 肩部上方裁剪，避免脚底刚跨过前缘时整张角色贴图被前景吞掉。

@export var foreground_z_index := 50
## 边界带视为前方，避免脚底落在手绘前缘上时整块前景误盖角色。
@export var front_epsilon := 0.25

var _player: Node2D = null
var _layers: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_build_layers")

func _build_layers() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	var bg := get_parent().get_node_or_null("BG") as Sprite2D
	if bg == null or bg.texture == null:
		return
	for node in get_tree().get_nodes_in_group("interactable"):
		var target := node as Node2D
		if target == null or not target.has_method("world_foreground_polygon") \
			or not target.has_method("world_occlusion_polygon"):
			continue
		var foreground: PackedVector2Array = target.world_foreground_polygon()
		var occlusion: PackedVector2Array = target.world_occlusion_polygon()
		if foreground.size() < 3 or occlusion.size() < 3:
			push_warning("PropForeground: missing authored depth data for %s" % target.name)
			continue
		var layer := Polygon2D.new()
		layer.name = target.name + "Foreground"
		layer.polygon = foreground
		layer.uv = foreground
		layer.texture = bg.texture
		layer.z_index = foreground_z_index
		layer.visible = false
		add_child(layer)
		_layers.append({
			"target": target,
			"layer": layer,
			"occlusion": occlusion,
			"foreground": foreground,
			"clipped_for": INF,
		})

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_player):
		return
	for entry in _layers:
		var target: Node2D = entry["target"]
		var layer: Polygon2D = entry["layer"]
		if not is_instance_valid(target) or not is_instance_valid(layer):
			continue
		var behind := _point_is_behind(_player.global_position, entry["occlusion"])
		layer.visible = behind
		if behind:
			_update_body_clip(entry)

func _point_is_behind(point: Vector2, occlusion: PackedVector2Array) -> bool:
	if not Geometry2D.is_point_in_polygon(point, occlusion):
		return false
	# 交界线采用前方容差：边界附近宁可不盖住角色，避免连续移动时
	# 在前缘线上出现“后一帧又盖回去”的闪烁。
	for i in occlusion.size():
		var closest := Geometry2D.get_closest_point_to_segment(
			point, occlusion[i], occlusion[(i + 1) % occlusion.size()])
		if point.distance_to(closest) <= front_epsilon:
			return false
	return true

func _update_body_clip(entry: Dictionary) -> void:
	var target: Node2D = entry["target"]
	var layer: Polygon2D = entry["layer"]
	var keep_height := float(target.get_meta("occlusion_body_visible_height", 0.0))
	var source: PackedVector2Array = entry["foreground"]
	if keep_height <= 0.0 or source.size() < 3:
		return
	var clip_top := _player.global_position.y - keep_height
	if is_equal_approx(float(entry["clipped_for"]), clip_top):
		return
	var bounds := Rect2(source[0], Vector2.ZERO)
	for point in source:
		bounds = bounds.expand(point)
	var clip := PackedVector2Array([
		Vector2(bounds.position.x - 1.0, clip_top),
		Vector2(bounds.end.x + 1.0, clip_top),
		Vector2(bounds.end.x + 1.0, bounds.end.y + 1.0),
		Vector2(bounds.position.x - 1.0, bounds.end.y + 1.0),
	])
	# The clip rectangle is the lower body band. Use intersection so this band
	# remains in front of the character; clip_polygons would keep the difference
	# (the upper half) and invert the intended depth ordering.
	var clipped := Geometry2D.intersect_polygons(source, clip)
	if clipped.is_empty():
		layer.polygon = PackedVector2Array()
		layer.uv = PackedVector2Array()
	else:
		# Authored foregrounds are single connected regions; retain the largest
		# clipped piece if a concave edge produces more than one result.
		var best := clipped[0]
		var best_area := absf(_polygon_area(best))
		for candidate in clipped:
			var candidate_area := absf(_polygon_area(candidate))
			if candidate_area > best_area:
				best = candidate
				best_area = candidate_area
		layer.polygon = best
		layer.uv = best
	entry["clipped_for"] = clip_top

func _polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	return area * 0.5

func is_target_occluding(target: Node2D) -> bool:
	for entry in _layers:
		if entry["target"] == target:
			return bool(entry["layer"].visible)
	return false

func set_target_visible(target: Node2D, value: bool) -> void:
	for entry in _layers:
		if entry["target"] == target:
			(entry["layer"] as Polygon2D).visible = value
			return
