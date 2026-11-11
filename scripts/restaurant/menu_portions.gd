extends RefCounted
## 当日逐份归属。仓库预留不扣实物；所有变更由调用方同一事务保存。
const DAY := "restaurant_day_v1"
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Freezer := preload("res://scripts/restaurant/freezer_store.gd")

static func valid(day: Dictionary) -> bool:
	if not day.has("portions_revision"): return not day.has("portions")
	if day.portions_revision!=1 or not day.get("portions") is Array or not day.get("menu") is Dictionary: return false
	if day.portions.is_empty() or day.portions.size()>50: return false
	var counts := {}
	var ids := {}
	var physical_ids := {}
	var pots := 0
	for unit in day.portions:
		if not unit is Dictionary or not Freezer.integer(unit.get("id"),1) or ids.has(int(unit.id)): return false
		ids[int(unit.id)] = true
		if not unit.get("recipe") is String or not Recipes.RECIPES.has(unit.recipe) or not day.menu.has(unit.recipe): return false
		if unit.get("phase") not in ["warehouse","carried","cooking","dish","stored","sold","lost"]: return false
		if not Freezer.integer(unit.get("quality")) or unit.quality>3 or not Freezer.integer(unit.get("freezer_id")): return false
		if unit.phase in ["warehouse","carried","cooking"] and (unit.quality!=0 or unit.freezer_id!=0): return false
		if unit.phase in ["dish","stored"] and unit.quality<1: return false
		if unit.phase=="stored" and unit.freezer_id<1: return false
		if unit.phase=="cooking": pots += 1
		if live(unit) and unit.freezer_id>0:
			if physical_ids.has(int(unit.freezer_id)): return false
			physical_ids[int(unit.freezer_id)] = true
		counts[unit.recipe] = int(counts.get(unit.recipe,0))+1
	if pots>1 or counts.size()!=day.menu.size(): return false
	for recipe in day.menu:
		if not Freezer.integer(day.menu[recipe],1) or day.menu[recipe]>10 or int(counts.get(recipe,0))!=int(day.menu[recipe]): return false
	return true

static func managed(state: Dictionary) -> bool:
	return state.get(DAY,{}).get("portions_revision",0)==1

static func units(state: Dictionary) -> Array:
	return state.get(DAY,{}).get("portions",[])

static func live(unit: Dictionary) -> bool:
	return unit.phase not in ["sold","lost"]

static func build(sm: Node, menu: Dictionary) -> Dictionary:
	if not sm.freezer_valid(): return {"success":false,"reason":"invalid_state"}
	var stock: Dictionary = sm.warehouse_snapshot()
	var raw: Dictionary = sm.carried_ingredients()
	var prepared: Dictionary = sm.prepared_dishes_snapshot()
	var freezer: Dictionary = sm.freezer_snapshot()
	var cooking: Dictionary = sm.cooking_state()
	var dishes: Array = []
	var now := int(Time.get_unix_time_from_system())
	for location in ["carried","stored"]:
		for dish in freezer[location]:
			if location=="carried": prepared[dish.recipe_id][str(int(dish.quality))] -= 1
			if int(dish.expires_at)>now:
				dishes.append({"recipe":dish.recipe_id,"phase":"dish" if location=="carried" else "stored","quality":int(dish.quality),"freezer_id":int(dish.id)})
	for recipe in prepared:
		for quality in [3,2,1]:
			for count in int(prepared[recipe].get(str(quality),0)):
				dishes.append({"recipe":recipe,"phase":"dish","quality":quality,"freezer_id":0})
	var result: Array = []
	var required := {}
	for recipe in menu:
		var ingredients: Dictionary = Recipes.get_recipe(recipe).ingredients
		for count in int(menu[recipe]):
			var unit := {"id":result.size()+1,"recipe":recipe,"phase":"warehouse","quality":0,"freezer_id":0}
			var found := -1
			for i in dishes.size():
				if dishes[i].recipe==recipe:
					found = i
					break
			if found>=0:
				unit.merge(dishes[found],true)
				dishes.remove_at(found)
			elif cooking.get("status")=="active" and cooking.get("recipe_id")==recipe:
				unit.phase = "cooking"
				cooking = {}
			elif _contains(raw,ingredients):
				unit.phase = "carried"
				_subtract(raw,ingredients)
			else:
				for item in ingredients: required[item] = int(required.get(item,0))+int(ingredients[item])
			result.append(unit)
	if not _contains(stock,required): return {"success":false,"reason":"insufficient_material"}
	return {"success":true,"units":result,"required":required}

static func _contains(stock: Dictionary, items: Dictionary) -> bool:
	for item in items:
		if int(stock.get(item,0))<int(items[item]): return false
	return true

static func _subtract(stock: Dictionary, items: Dictionary) -> void:
	for item in items: stock[item] = int(stock.get(item,0))-int(items[item])

static func reserved(state: Dictionary) -> Dictionary:
	var amounts := {}
	for unit in units(state):
		if unit.phase!="warehouse": continue
		for item in Recipes.get_recipe(unit.recipe).ingredients:
			amounts[item] = int(amounts.get(item,0))+int(Recipes.get_recipe(unit.recipe).ingredients[item])
	return amounts

static func take(state: Dictionary, selection: Dictionary) -> bool:
	if not managed(state) or state[DAY].status!="open": return true
	for unit in units(state):
		if unit.phase=="warehouse" and Recipes.get_recipe(unit.recipe).ingredients==selection:
			unit.phase = "carried"
			return true
	var free: Dictionary = state.get("warehouse_stock",{}).duplicate(true)
	_subtract(free,reserved(state))
	return _contains(free,selection)

static func start(state: Dictionary, recipe: String) -> bool:
	if not managed(state) or state[DAY].status!="open": return true
	for unit in units(state):
		if unit.phase=="carried":
			if unit.recipe!=recipe: return false
			unit.phase = "cooking"
			return true
	# 自带未归属原料制作菜单菜时释放对应仓库预留，不重复占用两份来源。
	for unit in units(state):
		if unit.recipe==recipe and unit.phase=="warehouse":
			unit.phase = "cooking"
			break
	return true

static func finish(state: Dictionary, recipe: String, quality: int) -> void:
	if not managed(state) or not valid(state.get(DAY,{})): return
	for unit in units(state):
		if unit.recipe==recipe and unit.phase=="cooking":
			unit.phase = "dish"
			unit.quality = quality
			unit.freezer_id = 0
			return

static func consume(state: Dictionary, recipe: String, quality: int, freezer_id: int, outcome: String, preferred_id := 0) -> void:
	if not managed(state) or state[DAY].status!="open": return
	var actual: Dictionary = {}
	for unit in units(state):
		if unit.recipe==recipe and unit.phase in ["dish","stored"] and int(unit.quality)==quality and int(unit.freezer_id)==freezer_id:
			actual = unit
			break
	var chosen: Dictionary = {}
	var assigned := _assigned(state.get("restaurant_customers",{}))
	for unit in units(state):
		if unit.recipe==recipe and live(unit) and int(unit.id)==preferred_id: chosen = unit
	if chosen.is_empty():
		for unit in units(state):
			if unit.recipe==recipe and live(unit) and int(unit.id) not in assigned:
				chosen = unit
				break
	if chosen.is_empty() and not actual.is_empty(): chosen = actual
	if chosen.is_empty():
		# 真实额外成品也可填菜单额度；释放原来源归属，不额外销毁它。
		for unit in units(state):
			if unit.recipe==recipe and live(unit):
				chosen = unit
				break
	if not chosen.is_empty():
		# 订单配额与实物来源分离：乱序交同菜时交换来源，另一顾客保留其份额。
		if not actual.is_empty() and actual.id!=chosen.id:
			for field in ["phase","quality","freezer_id"]:
				var previous: Variant = chosen[field]
				chosen[field] = actual[field]
				actual[field] = previous
		chosen.phase = outcome

static func discarded_carried(state: Dictionary, items: Dictionary) -> Dictionary:
	var raw_losses := {}
	if not managed(state) or state[DAY].status!="open": return raw_losses
	var remaining := items.duplicate(true)
	for unit in units(state):
		if unit.phase=="carried" and _contains(remaining,Recipes.get_recipe(unit.recipe).ingredients):
			_subtract(remaining,Recipes.get_recipe(unit.recipe).ingredients)
			unit.phase = "lost"
			raw_losses[unit.recipe] = int(raw_losses.get(unit.recipe,0))+1
		elif unit.phase=="dish" and int(remaining.get(unit.recipe,0))>0:
			remaining[unit.recipe] -= 1
			unit.phase = "lost"
	for recipe in remaining:
		if Recipes.RECIPES.has(recipe):
			for n in int(remaining[recipe]): consume(state,recipe,0,-1,"lost")
	return raw_losses

static func freezer_move(state: Dictionary, action: String, recipe: String, quality: int, old_id: int, new_id: int) -> void:
	if not managed(state) or state[DAY].status!="open": return
	if action in ["discard","discard_carried"]:
		consume(state,recipe,quality,old_id,"lost")
		return
	for unit in units(state):
		if unit.recipe==recipe and int(unit.quality)==quality and int(unit.freezer_id)==old_id and unit.phase==("dish" if action=="store" else "stored"):
			unit.phase = "stored" if action=="store" else "dish"
			unit.freezer_id = new_id
			return

static func _assigned(customers: Dictionary) -> Array:
	var assigned: Array = []
	var orders: Array = customers.get("seated",[]).duplicate()
	if not customers.get("front",{}).is_empty(): orders.append(customers.front)
	orders.append_array(customers.get("legacy_waiting",[]))
	for order in orders:
		if order.get("stage")!="done": assigned.append(int(order.get("portion_id",0)))
	return assigned

static func available(state: Dictionary, customers: Dictionary) -> Dictionary:
	var assigned := _assigned(customers)
	for unit in units(state):
		if live(unit) and int(unit.id) not in assigned: return unit
	return {}

static func complete(state: Dictionary) -> bool:
	return managed(state) and not units(state).any(func(unit): return live(unit))

static func cancel_exhausted(state: Dictionary) -> void:
	if not managed(state): return
	var terminal: Array = []
	for unit in units(state):
		if not live(unit): terminal.append(int(unit.id))
	var customers: Dictionary = state.get("restaurant_customers",{})
	var orders: Array = customers.get("seated",[]).duplicate()
	if not customers.get("front",{}).is_empty(): orders.append(customers.front)
	for order in orders:
		if order.get("stage")!="done" and int(order.get("portion_id",0)) in terminal:
			var rebound := false
			var assigned := _assigned(customers)
			for unit in units(state):
				if unit.recipe==order.item_id and live(unit) and int(unit.id) not in assigned:
					order.portion_id = int(unit.id)
					rebound = true
					break
			# 确实再无该菜可用额度时无罚撤单；不将已损耗份数重新出售。
			if not rebound: order.merge({"stage":"done","phase":"leaving","outcome":"closed"},true)

static func close(state: Dictionary, inventory_key: String, prepared_key: String, cooking_key: String) -> bool:
	# 调用方已持有整份回滚快照；任一物理来源不符就拒绝整次结算。
	for key in [inventory_key,prepared_key,"warehouse_stock"]:
		if not state.get(key) is Dictionary: return false
	if not valid(state.get(DAY,{})): return false
	var inventory: Dictionary = state[inventory_key]
	var prepared: Dictionary = state[prepared_key]
	var freezer: Dictionary = state.get(Freezer.KEY,Freezer.empty()).duplicate(true)
	var day: Dictionary = state[DAY]
	for unit in units(state):
		if not live(unit): continue
		var ingredients: Dictionary = Recipes.get_recipe(unit.recipe).ingredients
		if unit.phase=="warehouse":
			if not _contains(state.warehouse_stock,ingredients): return false
			_subtract(state.warehouse_stock,ingredients)
		elif unit.phase=="carried":
			if not _contains(inventory,ingredients): return false
			_subtract(inventory,ingredients)
		elif unit.phase=="cooking":
			if state.get(cooking_key,{}).get("status")!="active" or state[cooking_key].recipe_id!=unit.recipe: return false
			state[cooking_key] = {"status":"idle","recipe_id":"","quality":0,"pointer":0.0}
		elif unit.phase in ["dish","stored"]:
			var location := "carried" if unit.phase=="dish" else "stored"
			if int(unit.freezer_id)>0:
				var index := -1
				for i in freezer[location].size():
					var actual: Dictionary = freezer[location][i]
					if int(actual.id)==int(unit.freezer_id) and actual.recipe_id==unit.recipe and int(actual.quality)==int(unit.quality): index = i
				if index<0: return false
				freezer[location].remove_at(index)
			if unit.phase=="dish":
				if int(inventory.get(unit.recipe,0))<1 or int(prepared.get(unit.recipe,{}).get(str(int(unit.quality)),0))<1: return false
				inventory[unit.recipe] -= 1
				prepared[unit.recipe][str(int(unit.quality))] -= 1
		else: return false
		unit.phase = "lost"
		day.dish_losses[unit.recipe] = int(day.dish_losses.get(unit.recipe,0))+1
	state[Freezer.KEY] = freezer
	return true
