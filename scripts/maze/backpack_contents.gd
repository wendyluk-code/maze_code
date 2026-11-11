extends RefCounted
## 数量沿用现有库存；仅记录来源和首次获得顺序。
const KEY := "exploration_bag_order"

static func _append(order: Array, id: String, source: String) -> void:
	for entry in order:
		if str(entry.id) == id and str(entry.source) == source: return
	order.append({"id":id,"source":source})

static func rows(state: Dictionary) -> Array:
	var groups := {"capture":state.get("capture_run_v1",{}).get("bag",{}), "task":state.get("exploration_task_loot",{})}
	var order: Array = []
	for entry in state.get(KEY,[]): _append(order,str(entry.id),str(entry.source))
	for source in groups:
		for id in groups[source]: _append(order,str(id),str(source))
	var result: Array = []
	for entry in order:
		var quantity := int(groups.get(entry.source,{}).get(entry.id,0))
		if quantity > 0: result.append({"id":entry.id,"source":entry.source,"quantity":quantity})
	return result

static func record(state: Dictionary, id: String, source: String) -> void:
	var order: Array = []
	for entry in state.get(KEY,[]): _append(order,str(entry.id),str(entry.source))
	for row in rows(state): _append(order,str(row.id),str(row.source))
	_append(order,id,source)
	state[KEY] = order
