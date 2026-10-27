extends RefCounted
## 永久领取 ID 不随显示名称和站位调整而变；坐标是原图脚底锚点。
const REWARD := 100
const INTERACT_RADIUS := 52.0

static func all(region: String = "maze_entry") -> Array[Dictionary]:
	if region != "maze_entry":
		var result: Array[Dictionary]=[]
		for row in preload("res://data/maze/region_resources.gd").all(region):
			if row.item=="gold": result.append(row)
		return result
	return [
		{"id": "entry_corridor_north", "position": Vector2(724, 350)},
		{"id": "entry_west_fork", "position": Vector2(375, 646)},
		{"id": "entry_inner_end", "position": Vector2(733, 630)},
		{"id": "entry_east_rim", "position": Vector2(1075, 627)},
		{"id": "entry_south_rim", "position": Vector2(804, 1195)},
	]

static func find(id: String) -> Dictionary:
	var regional: Dictionary=preload("res://data/maze/region_resources.gd").find(id)
	if not regional.is_empty(): return regional if regional.item=="gold" else {}
	for chest in all():
		if chest.id == id:
			return chest
	return {}
