extends Node2D
## 从扁平餐厅底图采样道具前景。
## 交互轮廓、视觉前景和脚底深度区域彼此独立：只有脚底落在道具
## 自己校准的 occlusion_polygon 内时，才重绘 foreground_polygon。

@export var foreground_z_index := 50
@export var front_epsilon := 0.1

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
		_layers.append({"target": target, "layer": layer, "occlusion": occlusion})

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
		layer.visible = _point_is_behind(_player.global_position, entry["occlusion"])

func _point_is_behind(point: Vector2, occlusion: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point, occlusion):
		return true
	# 交界线采用小容差，避免脚底在手绘前缘上闪烁。
	for i in occlusion.size():
		var closest := Geometry2D.get_closest_point_to_segment(
			point, occlusion[i], occlusion[(i + 1) % occlusion.size()])
		if point.distance_to(closest) <= front_epsilon:
			return true
	return false

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
