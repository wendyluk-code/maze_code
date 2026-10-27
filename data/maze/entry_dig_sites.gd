extends RefCounted
## 用户红圈对应原地图像素坐标；ID 是跨版本存档契约，不随坐标调整改变。
const REWARD := 3
const ITEM_ID := "wood"
const INTERACT_RADIUS := 52.0

static func all(region: String = "maze_entry") -> Array[Dictionary]:
	if region != "maze_entry":
		var result: Array[Dictionary]=[]
		for row in preload("res://data/maze/region_resources.gd").all(region):
			if row.item!="gold": result.append(row)
		return result
	return [
		{"id": "entry_dig_west_fork", "position": Vector2(953, 310)},
		{"id": "entry_dig_northeast", "position": Vector2(988, 565)},
		{"id": "entry_dig_inner_path", "position": Vector2(782, 891)},
		{"id": "entry_dig_south_bend", "position": Vector2(923, 1211)},
	]

static func find(id: String) -> Dictionary:
	var regional: Dictionary=preload("res://data/maze/region_resources.gd").find(id)
	if not regional.is_empty(): return regional if regional.item!="gold" else {}
	for config in all():
		if config.id == id:
			return config
	return {}
