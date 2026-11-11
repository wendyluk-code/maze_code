extends RefCounted
## 坐标只来自当前餐厅的可编辑标记；旧场景保留调用方给出的回退位置。
static func world(tree: SceneTree, anchor_name: String, fallback: Vector2) -> Vector2:
	for marker in tree.get_nodes_in_group("restaurant_layout_anchors"):
		if marker.name == anchor_name:
			return marker.global_position
	return fallback

static func counter(tree: SceneTree) -> Vector2:
	return world(tree, "CustomerCounter", Vector2(910, 198))

static func seat(tree: SceneTree, index: int) -> Vector2:
	var fallback: Array[Vector2] = [Vector2(471, 251), Vector2(397, 264), Vector2(321, 278)]
	return world(tree, "Seat%d" % index, fallback[clampi(index, 0, 2)])

static func queue(tree: SceneTree, index: int) -> Vector2:
	var fallback: Array[Vector2] = [Vector2(795, 180), Vector2(680, 162)]
	return world(tree, "Queue%d" % index, fallback[clampi(index, 0, 1)])
