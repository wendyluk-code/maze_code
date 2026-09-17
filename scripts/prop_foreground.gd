extends Node2D
## 从扁平餐厅底图采样道具前景；只覆盖玩家脚底位于道具前缘后侧的帧。

@export var foreground_z_index := 50
@export var front_epsilon := 0.5

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
		if target == null or not target.has_method("world_interaction_polygon"):
			continue
		var polygon: PackedVector2Array = target.world_interaction_polygon()
		if polygon.size() < 3:
			continue
		var layer := Polygon2D.new()
		layer.name = target.name + "Foreground"
		layer.polygon = polygon
		layer.uv = polygon
		layer.texture = bg.texture
		layer.z_index = foreground_z_index
		layer.visible = false
		add_child(layer)
		var front_y := -INF
		for point in polygon:
			front_y = maxf(front_y, point.y)
		_layers.append({"target": target, "layer": layer, "front_y": front_y})

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
		# Y is the authored isometric depth axis: above the prop's bottom/front
		# edge means behind it, while crossing that edge puts the player in front.
		layer.visible = _player.global_position.y <= float(entry["front_y"]) + front_epsilon

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
