@tool
extends Node2D
## 原始整图显示；保留布局节点作为碰撞、交互与顾客定位数据。
var _surfaces: Array[Dictionary] = []

func _ready() -> void:
	for prop in get_tree().get_nodes_in_group("restaurant_layout_props"):
		if not $InteractPoints.is_ancestor_of(prop):
			continue
		var art := prop.get_node_or_null("Art") as CanvasItem
		if art != null:
			art.hide()
	if Engine.is_editor_hint():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/restaurant_layout/original_occlusion.json"))
	for entry in data:
		var origin := Vector2(entry.position[0], entry.position[1])
		var polygon := Polygon2D.new()
		polygon.name = entry.name + "MapOcclusion"
		polygon.polygon = _points(entry.foreground, origin)
		polygon.uv = polygon.polygon
		polygon.texture = $BG.texture
		polygon.z_as_relative = false
		var counter: bool = entry.name in ["BarCounter", "Register"]
		polygon.z_index = -1 if counter else 1
		add_child(polygon)
		_surfaces.append({"node": polygon, "counter": counter, "name": entry.name, "area": _points(entry.occlusion, origin)})

func _points(values: Array, origin: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0, values.size(), 2):
		result.append(origin + Vector2(values[i], values[i + 1]))
	return result

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for surface in _surfaces:
		var prop := get_node_or_null("InteractPoints/" + str(surface.name)) as Node2D
		var left: bool = prop != null and surface.name in ["Fridge", "FoodCart", "Cauldron"] and player.global_position.x < prop.global_position.x
		surface.node.visible = surface.counter or (not left and Geometry2D.is_point_in_polygon(player.global_position, surface.area))
