extends RefCounted

const RecipeCatalog := preload("res://scripts/cooking/recipe_catalog.gd")
const KEY := "restaurant_day_v1"

## 仅记录已有事务真实销毁的成品，不改库存；由调用方和原事务一起保存/回滚。
static func record_dish_loss(state: Dictionary, items: Dictionary) -> void:
	if not items.keys().any(func(id): return RecipeCatalog.RECIPES.has(id) and int(items[id])>0): return
	var day: Dictionary = state.get(KEY, {}).duplicate(true)
	if day.get("status") == "closing": return
	var losses: Dictionary = day.get("dish_losses", {}).duplicate(true)
	for id in items:
		if RecipeCatalog.RECIPES.has(id) and int(items[id]) > 0:
			losses[id] = int(losses.get(id,0)) + int(items[id])
	day["dish_losses"] = losses
	state[KEY] = day

## 只合并已存在的凭证；不从日数或历史总金币反推虚构营业日。
static func settlement_history(sm: Node, current: Dictionary = {}) -> Array:
	var day := snapshot(sm)
	var by_day := {}
	var raw = day.get("history",[])
	var candidates: Array = raw.duplicate(true) if raw is Array else []
	candidates.append(day.get("last_settlement",{}))
	candidates.append(day.get("settlement",{}))
	candidates.append(current)
	for entry in candidates:
		if not entry is Dictionary or not entry.has("day") or not entry.has("income") or not entry.has("reputation"): continue
		var number := int(entry.day)
		if number < 1 or number > int(day.get("day",1)): continue
		by_day[number] = entry.duplicate(true)
	var numbers: Array = by_day.keys()
	numbers.sort()
	var history: Array = []
	for number in numbers:
		if number >= int(day.get("day",1))-5: history.append(by_day[number])
	return history

static func snapshot(sm: Node) -> Dictionary:
	var state: Dictionary = sm.get("_state")
	var raw = state.get(KEY, {})
	return raw.duplicate(true) if raw is Dictionary else {}

static func pending_loot(sm: Node) -> Array:
	var queue = snapshot(sm).get("loot_queue", [])
	return queue.duplicate(true) if queue is Array else []

static func loot_groups(sm: Node, items: Dictionary) -> Dictionary:
	var sources: Array = snapshot(sm).get("loot_sources", [])
	if not sources.is_empty(): return sources[0].duplicate(true)
	# 旧回执没有来源字段；现有任务专属原料不来自捕获。
	var groups := {"capture":{}, "task":{}}
	for id in items:
		var kind := "task" if id in ["moondew_honey","cooking_sake","sour_vine_juice","white_truffle","jade_lily","golden_bird_nest"] else "capture"
		groups[kind][id] = items[id]
	return groups

## 任务奖励已由领取事务入仓；这里只记本趟展示回执，绝不二次入库。
static func record_task_loot(state: Dictionary, items: Dictionary) -> void:
	var pending: Dictionary = state.get("exploration_task_loot", {}).duplicate(true)
	for id in items:
		preload("res://scripts/maze/backpack_contents.gd").record(state, id, "task")
		pending[id] = int(pending.get(id, 0)) + int(items[id])
	state["exploration_task_loot"] = pending

## 仅修复已完成首次探索、尚未开业且仍保留本趟记录的旧档；不据仓库总量补奖。
static func repair_first_return(sm: Node) -> bool:
	var state: Dictionary = sm.get("_state")
	if state.get("return_loot_version", 0) == 1: return true
	if state.get("first_exploration_gate_v1", "") != "done": return true
	var day := snapshot(sm)
	if int(day.get("day",1)) != 1 or day.get("status", "") in ["open","closing"]: return true
	var lesson: Dictionary = state.get("ch2_guide_01", {})
	var items: Dictionary = lesson.get("banked", {}).duplicate(true)
	if items.is_empty(): return true
	var before := state.duplicate(true)
	if sm.elder_backpack_unlocked():
		for item in preload("res://data/maze/elder_firewood.gd").REWARD_ITEMS:
			items[item.id] = int(items.get(item.id,0)) + int(item.quantity)
	var queue := pending_loot(sm)
	if queue.is_empty(): queue.append(items)
	else: queue[0] = items
	day["loot_queue"] = queue
	day.erase("loot_sources")
	state[KEY] = day
	state["return_loot_version"] = 1
	state["first_business_intro_pending"] = true
	lesson["step"] = "warehouse"
	state["ch2_guide_01"] = lesson
	if sm.save(): return true
	sm.set("_state", before)
	return false

static func enqueue_loot(state: Dictionary, items: Dictionary, captured: Dictionary = {}, tasks: Dictionary = {}) -> void:
	var day = state.get(KEY, {})
	if not day is Dictionary: day = {}
	var queue = day.get("loot_queue", [])
	if not queue is Array: queue = []
	queue.append(items.duplicate(true))
	var sources: Array = day.get("loot_sources", [])
	# 老队列用原料来源兼容；新回执逐次保留真实来源。
	while sources.size() < queue.size() - 1:
		var old: Dictionary = queue[sources.size()]
		var groups := {"capture":{}, "task":{}}
		for id in old:
			var kind := "task" if id in ["moondew_honey","cooking_sake","sour_vine_juice","white_truffle","jade_lily","golden_bird_nest"] else "capture"
			groups[kind][id] = old[id]
		sources.append(groups)
	sources.append({"capture":captured.duplicate(true), "task":tasks.duplicate(true)} if not captured.is_empty() or not tasks.is_empty() else {"capture":items.duplicate(true),"task":{}})
	day["loot_sources"] = sources
	day["loot_queue"] = queue
	state[KEY] = day

static func acknowledge_loot(sm: Node) -> bool:
	var state: Dictionary = sm.get("_state")
	var previous := state.duplicate(true)
	var day := snapshot(sm)
	var queue := pending_loot(sm)
	if queue.is_empty(): return false
	queue.pop_front()
	var sources: Array = day.get("loot_sources", [])
	if not sources.is_empty(): sources.pop_front()
	day["loot_sources"] = sources
	day["loot_queue"] = queue
	state[KEY] = day
	if sm.save(): return true
	sm.set("_state", previous)
	return false

static func validate_menu(sm: Node, menu: Dictionary) -> Dictionary:
	if menu.is_empty() or menu.size() > 5: return {"success": false, "reason": "menu_size"}
	var recipes := {}
	var unlocked: Array = sm.unlocked_recipe_ids()
	for recipe_id in menu:
		var quantity = menu[recipe_id]
		if recipe_id not in unlocked or RecipeCatalog.order_gold(str(recipe_id)) <= 0 or typeof(quantity) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(quantity)) or float(quantity) != floor(float(quantity)) or quantity < 1 or quantity > 10:
			return {"success": false, "reason": "invalid_recipe"}
		var ingredients: Dictionary = RecipeCatalog.get_recipe(recipe_id).get("ingredients", {})
		if ingredients.is_empty(): return {"success": false, "reason": "invalid_recipe"}
		recipes[recipe_id] = ingredients
	return preload("res://scripts/restaurant/menu_portions.gd").build(sm,menu)

static func validate_requirements(stock: Dictionary, recipes: Dictionary, menu: Dictionary) -> Dictionary:
	var required := {}
	for recipe_id in menu:
		var ingredients: Dictionary = recipes[recipe_id]
		for item_id in ingredients:
			required[item_id] = int(required.get(item_id, 0)) + int(ingredients[item_id]) * int(menu[recipe_id])
	for item_id in required:
		if int(required[item_id]) > maxi(0, int(stock.get(item_id, 0))):
			return {"success": false, "reason": "insufficient_material", "item_id": item_id}
	return {"success": true, "required": required}

static func save_menu(sm: Node, menu: Dictionary) -> Dictionary:
	if snapshot(sm).get("status", "") in ["prepared", "open", "closing"]: return {"success": false, "reason": "already_prepared"}
	var result := validate_menu(sm, menu)
	if not result.success: return result
	var state: Dictionary = sm.get("_state")
	var previous := state.duplicate(true)
	var day := snapshot(sm)
	day["menu"] = menu.duplicate(true)
	day["status"] = "prepared"
	state[KEY] = day
	if not sm.save():
		sm.set("_state", previous)
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "menu": menu.duplicate(true), "required": result.required}
