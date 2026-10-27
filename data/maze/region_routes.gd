extends RefCounted
## 后续区域在此登记来源、绿色出生标记与返回落点，复用相同交互格式。
const ROUTES = {
	"moss_pool": {"name":"青苔池","previous_id":"fenshui","previous_name":"分水庭","spawn":preload("res://data/maze/moss_pool_roads.gd").SPAWN,"marker":preload("res://data/maze/moss_pool_roads.gd").ENTRANCE,"return_point":preload("res://data/maze/moss_pool_roads.gd").FENSHUI_RETURN},
	"salt_pool": {"name":"盐池","previous_id":"fenshui","previous_name":"分水庭","spawn":preload("res://data/maze/salt_pool_roads.gd").SPAWN,"marker":preload("res://data/maze/salt_pool_roads.gd").ENTRANCE,"return_point":preload("res://data/maze/salt_pool_roads.gd").FENSHUI_RETURN},
	"fenshui": {"name":"分水庭", "previous_id":"maze_entry", "previous_name":"枯水渠", "spawn":preload("res://data/maze/fenshui_roads.gd").SPAWN, "marker":preload("res://data/maze/fenshui_roads.gd").ENTRANCE, "return_point":preload("res://data/maze/settlement_exit.gd").ARRIVAL}
}
static func route(region: String) -> Dictionary:
	return ROUTES.get(region,{})
