extends RefCounted
## 普通营业订单独立状态；铁山首单不进入此服务。
const FRONT_SECONDS := 40.0
const DRINK_SECONDS := 40.0
const FOOD_SECONDS := 100.0
const ARRIVAL_SECONDS := 12.0
const BUSINESS_SECONDS := 300.0
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Catalog := preload("res://scripts/restaurant/customer_catalog.gd")
const Portions := preload("res://scripts/restaurant/menu_portions.gd")

static func managed(order: Dictionary) -> bool:
	return order.get("cycle", false)

## 只读旧档映射；实际写盘由 migrate_customers 原子提交，失败不改原始档。
static func three_seat_snapshot(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	if int(result.get("layout_revision",0)) == 3: return result
	result.layout_revision = 3
	result.legacy_waiting = []
	var seated: Array = []
	for order in result.seated:
		if seated.size() < 3:
			order.seat = seated.size()
			seated.append(order)
		else:
			order.seat = -1
			result.legacy_waiting.append(order)
	result.seated = seated
	return result

static func wait_for_food(order: Dictionary) -> void:
	order.stage = "food"
	order.remaining = FOOD_SECONDS
	order.drink_done = true

static func validate_order(order: Dictionary) -> bool:
	if not managed(order): return true
	var remaining = order.get("remaining")
	return order.get("stage") in ["front", "drink", "food", "done"] and (order.stage != "drink" or order.has("drink_ice")) and typeof(remaining) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(remaining)) and float(remaining) >= 0 and float(remaining) <= FOOD_SECONDS

static func valid_day(day: Dictionary) -> bool:
	if not Portions.valid(day): return false
	if day.get("status") not in ["open","closing"]: return true
	if not day.get("plan") is Array or day.plan.is_empty() or day.plan.size() > 50: return false
	var arrived = day.get("arrived")
	var remaining = day.get("arrival_left")
	var business_left = day.get("remaining")
	if typeof(business_left) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(business_left)) or business_left < 0 or business_left > BUSINESS_SECONDS: return false
	if typeof(arrived) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(arrived)) or float(arrived) != floor(float(arrived)) or arrived < 0 or (day.get("portions_revision",0)!=1 and arrived > day.plan.size()): return false
	if typeof(remaining) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(remaining)) or remaining < 0 or remaining > ARRIVAL_SECONDS: return false
	for planned in day.plan:
		if not planned is Dictionary or not planned.get("drink") is bool or Recipes.order_gold(str(planned.get("recipe",""))) <= 0: return false
	return true

static func commit(sm: Node, before: Dictionary, result: Dictionary = {}) -> Dictionary:
	if sm.save():
		result["success"] = true
		return result
	sm.set("_state", before)
	return {"success":false, "reason":"save_failed"}

static func timeout(sm: Node, order: Dictionary) -> void:
	var outcome := "front_timeout" if order.stage == "front" else ("drink_timeout" if order.stage == "drink" else "timeout")
	var penalty := 1 if order.stage == "front" else 2
	order.stage = "done"
	order.phase = "leaving"
	order.outcome = outcome
	var actual_gold := -mini(sm.gold_balance(),penalty)
	var actual_reputation := -mini(sm.reputation(),1)
	sm.get("_state")[sm.GOLD_KEY] = maxi(0, sm.gold_balance() - penalty)
	sm.get("_state")[sm.REPUTATION_KEY] = maxi(0, sm.reputation() - 1)
	var receipts: Dictionary = sm.get("_state").get("restaurant_order_receipts", {}).duplicate(true)
	receipts[order.id] = {"quality":0, "gold_awarded":-penalty, "reputation_awarded":-1, "gold_delta":actual_gold, "reputation_delta":actual_reputation, "item_id":order.item_id, "outcome":outcome}
	sm.get("_state")["restaurant_order_receipts"] = receipts

static func tick(sm: Node, delta: float) -> Dictionary:
	if not sm.is_chapter_1_done() or sm.chapter_1_outro_state() != "done": return {"success":true}
	if delta <= 0 or not is_finite(delta): return {"success":true}
	var customers: Dictionary = sm.restaurant_customers()
	if not sm._customers_valid(customers): return {"success":false, "reason":"invalid_state"}
	if not sm.chest_reward_state_valid(): return {"success":false,"reason":"invalid_reward_state"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	var changed := false
	var events: Array = []
	var day := Day.snapshot(sm)
	if not valid_day(day): return {"success":false,"reason":"invalid_state"}
	if day.get("status") == "closing":
		return settle(sm, "time") if not day.has("settlement") else {"success":true}
	if day.get("status") == "open":
		day.arrival_left = maxf(0, float(day.get("arrival_left", 0)) - delta)
		day.remaining = maxf(0, float(day.remaining) - delta)
		if day.remaining <= 0:
			# 同帧到时优先，整批订单不得再扣耐心。
			return settle(sm, "time")
		sm.get("_state")[Day.KEY] = day
		changed = true
	# 营业到时尚未接单的客人无罚离开；不能被同一帧候客超时扣款。
	if not customers.front.is_empty() and managed(customers.front):
		var front: Dictionary = customers.front
		if day.get("status") == "closing" and front.phase != "leaving":
			front.phase = "leaving"
			front.stage = "done"
			front.outcome = "closed"
			changed = true
		elif front.phase == "front":
			front.remaining = maxf(0, float(front.remaining) - delta)
			changed = true
			if front.remaining <= 0:
				events.append("front")
				timeout(sm, front)
	for order in customers.seated:
		if not managed(order) or order.phase != "waiting": continue
		changed = true
		order.remaining = maxf(0, float(order.remaining) - delta)
		if order.remaining <= 0:
			events.append(str(order.stage))
			timeout(sm, order)
	if not changed: return {"success":true}
	sm.get("_state")["restaurant_customers"] = customers
	return commit(sm, before, {"events":events})

static func begin_day(sm: Node) -> Dictionary:
	if not sm.is_chapter_1_done() or sm.chapter_1_outro_state() != "done": return {"success":false, "reason":"chapter_locked"}
	var day := Day.snapshot(sm)
	if day.get("status") in ["open","closing"]: return {"success":false, "reason":"already_open"}
	if day.get("status") != "prepared": return {"success":false, "reason":"not_prepared"}
	var checked := Day.validate_menu(sm, day.get("menu", {}))
	if not checked.success: return checked
	var customers: Dictionary = sm.restaurant_customers()
	if not sm._customers_valid(customers): return {"success":false, "reason":"invalid_state"}
	if not customers.seated.is_empty() or not customers.front.is_empty() or not customers.queue.is_empty() or not customers.get("legacy_waiting",[]).is_empty(): return {"success":false, "reason":"customers_pending"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	var plan: Array = []
	for recipe in day.menu:
		for i in int(day.menu[recipe]): plan.append({"recipe":recipe, "drink":false})
	plan.shuffle()
	# 入座人数的累计配额；五分钟提前截断计划也保持最接近30%的整数人数。
	for i in plan.size(): plan[i].drink = int(round((i+1)*0.3)) > int(round(i*0.3))
	day.merge({"status":"open", "plan":plan, "arrived":0, "arrival_left":0.0, "remaining":BUSINESS_SECONDS, "day":int(day.get("day",1))}, true)
	day["start_serial"] = int(customers.serial)
	day["start_gold"] = sm.gold_balance()
	day["start_reputation"] = sm.reputation()
	day["loss_tracking"] = true
	day["portions_revision"] = 1
	day["portions"] = checked.units.duplicate(true)
	if not day.has("dish_losses"): day["dish_losses"] = {}
	day.erase("settlement")
	sm.get("_state")[Day.KEY] = day
	return commit(sm, before)

static func open_with_menu(sm: Node, menu: Dictionary) -> Dictionary:
	if Day.snapshot(sm).get("status") in ["open","closing"]: return {"success":false,"reason":"already_open"}
	var checked := Day.validate_menu(sm,menu)
	if not checked.success: return checked
	var before: Dictionary = sm.get("_state").duplicate(true)
	var day := Day.snapshot(sm)
	day.menu = menu.duplicate(true)
	day.status = "prepared"
	sm.get("_state")[Day.KEY] = day
	var result := begin_day(sm)
	if not result.success: sm.set("_state",before)
	else: result.merge({"menu":menu.duplicate(true),"required":checked.required,"opened":true})
	return result

static func arrive(sm: Node) -> Dictionary:
	if not sm.is_chapter_1_done() or sm.chapter_1_outro_state() != "done" or sm.maze_exploration_state().region != "restaurant": return {"success":false, "reason":"arrival_locked"}
	var day := Day.snapshot(sm)
	if not valid_day(day): return {"success":false,"reason":"invalid_state"}
	if day.get("status") not in ["open","closing"]: return {"success":true, "created":false}
	var customers: Dictionary = sm.restaurant_customers()
	if not sm._customers_valid(customers): return {"success":false, "reason":"invalid_state"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	# 菜单份数全部分配后不再来客；在座顾客收尾完成即可提前结束。
	if day.status == "closing": return {"success":true, "created":false}
	# 仅旧六座档存在：已接单客保持原阶段和剩余时间，腾座后继续。
	var pending: Array = customers.get("legacy_waiting", [])
	if not pending.is_empty() and customers.seated.size() < Catalog.SEATS.size():
		var order: Dictionary = pending.pop_front()
		var occupied: Array = []
		for seated in customers.seated: occupied.append(int(seated.seat))
		var free := 0
		while free in occupied: free += 1
		order.seat = free
		order.resume_phase = "waiting" if order.phase == "seating" else order.phase
		order.phase = "seating"
		customers.seated.append(order)
		customers.legacy_waiting = pending
		sm.get("_state")["restaurant_customers"] = customers
		return commit(sm, before, {"resumed":true})
	var modern := Portions.managed(sm.get("_state"))
	if (modern and Portions.complete(sm.get("_state"))) or (not modern and int(day.arrived)>=day.plan.size()):
		if customers.seated.is_empty() and customers.front.is_empty() and customers.queue.is_empty() and pending.is_empty():
			return settle(sm, "empty")
		return {"success":true, "created":false}
	if customers.seated.size() >= Catalog.SEATS.size() or not customers.front.is_empty() or not pending.is_empty() or float(day.arrival_left) > 0: return {"success":true, "created":false}
	var portion := Portions.available(sm.get("_state"),customers) if modern else {}
	if modern and portion.is_empty(): return {"success":true,"created":false}
	var planned: Dictionary = {"recipe":portion.recipe,"drink":int(round((int(day.arrived)+1)*0.3))>int(round(int(day.arrived)*0.3))} if modern else day.plan[int(day.arrived)]
	customers.serial = int(customers.serial) + 1
	var lesson := pending_drink_lesson(sm,customers)
	if not lesson.is_empty(): planned.drink = true
	var config: Dictionary = Catalog.rotating_customer(int(customers.serial))
	var order := {"id":"service_%d" % int(customers.serial), "customer_id":config.id, "item_id":planned.recipe,
		"item_name":Recipes.get_recipe(planned.recipe).name, "quantity":1, "phase":"arriving", "seat":-1,
		"cycle":true, "stage":"front", "remaining":FRONT_SECONDS, "wants_drink":planned.drink,
		"drink_done":not planned.drink, "food_done":false}
	if planned.drink: order.drink_ice = randi_range(0,1) if sm.freezer_unlocked() else 0
	if not lesson.is_empty():
		order.drink_ice = 0 if lesson=="warm" else 1
		order["drink_lesson"] = lesson
	if modern: order["portion_id"] = int(portion.id)
	customers.front = order
	day.arrived = int(day.arrived) + 1
	day.arrival_left = ARRIVAL_SECONDS
	sm.get("_state")[Day.KEY] = day
	sm.get("_state")["restaurant_customers"] = customers
	return commit(sm, before, {"created":true, "order":order})

static func pending_drink_lesson(sm: Node, customers: Dictionary) -> String:
	var read: Dictionary = sm.get("_state").get("ganlu_lessons_v1",{})
	var seated: Dictionary = sm.get("_state").get("ganlu_demand_seated_v1",{})
	for kind in ["warm","iced"]:
		if int(customers.serial) < (2 if kind=="warm" else 3): continue
		if read.get(kind,false) or seated.get(kind,false): continue
		# 已接单但仍在落座动画中的顾客占用该教学需求，避免重复派发。
		var reserved := false
		for order in customers.seated + customers.get("legacy_waiting",[]):
			if order.get("phase") == "leaving" or not order.has("drink_ice"): continue
			if ("iced" if int(order.drink_ice)>0 else "warm")==kind:
				reserved = true
				break
		if not reserved: return kind
	return ""

static func mark_drink_lesson_seated(sm: Node, order: Dictionary) -> void:
	if not managed(order) or order.get("phase")!="waiting" or not order.has("drink_ice"): return
	var flags: Dictionary = sm.get("_state").get("ganlu_demand_seated_v1",{}).duplicate()
	flags["iced" if int(order.drink_ice)>0 else "warm"] = true
	sm.get("_state")["ganlu_demand_seated_v1"] = flags

static func migrate_customers(sm: Node) -> Dictionary:
	if not sm.is_chapter_1_done() or sm.chapter_1_outro_state() != "done": return {"success":true}
	var customers: Dictionary = sm.restaurant_customers()
	if not sm._customers_valid(customers): return {"success":false, "reason":"invalid_state"}
	var changed: bool = customers != sm.get("_state").get("restaurant_customers", {})
	var before: Dictionary = sm.get("_state").duplicate(true)
	for order in customers.seated + customers.get("legacy_waiting", []):
		if managed(order): continue
		changed = true
		order.cycle = true
		order.stage = "food"
		order.remaining = FOOD_SECONDS
		if order.get("food_done",false) or order.phase in ["eating","farewell","leaving"]:
			order.stage = "done"
			if order.phase == "waiting": order.phase = "eating"
		elif order.has("drink_ice") and not order.get("drink_done",false):
			order.stage = "drink"
			order.remaining = DRINK_SECONDS
	if not changed: return {"success":true}
	sm.get("_state")["restaurant_customers"] = customers
	return commit(sm,before)

static func deliver_food(sm: Node, id: String) -> Dictionary:
	if not valid_day(Day.snapshot(sm)): return {"success":false,"reason":"invalid_state"}
	if Day.snapshot(sm).get("status") == "closing": return {"success":false,"reason":"closed"}
	var customers: Dictionary = sm.restaurant_customers()
	if not sm._customers_valid(customers): return {"success":false, "reason":"invalid_state"}
	for order in customers.seated:
		if order.id != id: continue
		if order.phase != "waiting": return {"success":false, "reason":"not_waiting"}
		var dish := ""
		for item in Recipes.RECIPES:
			if sm.dish_quality(item) > 0:
				dish = item
				break
		if dish.is_empty(): return {"success":false, "reason":"missing_dish"}
		var before: Dictionary = sm.get("_state").duplicate(true)
		var quality: int = sm.dish_quality(dish)
		var correct: bool = order.stage == "food" and dish == order.item_id
		var gold: int = Recipes.order_gold(dish) if correct else -2
		var reputation: int = int(sm.QUALITY_REPUTATION[quality]) if correct else 0
		if not sm.chest_reward_state_valid() or sm.gold_balance() > 9007199254740991 - maxi(0, gold): return {"success":false, "reason":"invalid_reward_state"}
		var inventory: Dictionary = sm.inventory_snapshot()
		var prepared: Dictionary = sm.prepared_dishes_snapshot()
		var freezer: Dictionary = sm.freezer_snapshot()
		var chilled := preload("res://scripts/restaurant/freezer_store.gd").carried_index(freezer,dish,quality,int(Time.get_unix_time_from_system()))
		var physical_id := int(freezer.carried[chilled].id) if chilled>=0 else 0
		inventory[dish] -= 1
		prepared[dish][str(quality)] -= 1
		sm._consume_chilled_dish(dish, quality, int(Time.get_unix_time_from_system()))
		order.stage = "done"
		order.food_done = true
		order.phase = "eating" if correct else "leaving"
		order.outcome = "served" if correct else "wrong_dish"
		var receipt := {"quality":quality, "gold_awarded":gold, "reputation_awarded":reputation, "item_id":dish, "outcome":order.outcome}
		receipt["gold_delta"] = maxi(0,sm.gold_balance()+gold)-sm.gold_balance()
		receipt["reputation_delta"] = reputation
		var receipts: Dictionary = sm.get("_state").get("restaurant_order_receipts", {}).duplicate(true)
		receipts[id] = receipt
		sm.get("_state")["restaurant_order_receipts"] = receipts
		sm.get("_state")["restaurant_customers"] = customers
		sm.get("_state")[sm.INVENTORY_KEY] = inventory
		sm.get("_state")[sm.PREPARED_DISHES_KEY] = prepared
		sm.get("_state")[sm.GOLD_KEY] = maxi(0, sm.gold_balance() + gold)
		sm.get("_state")[sm.REPUTATION_KEY] = sm.reputation() + reputation
		Portions.consume(sm.get("_state"),dish,quality,physical_id,"sold" if correct else "lost",int(order.get("portion_id",0)) if correct else 0)
		if not correct and Portions.managed(sm.get("_state")): Day.record_dish_loss(sm.get("_state"),{dish:1})
		Portions.cancel_exhausted(sm.get("_state"))
		return commit(sm, before, receipt)
	return {"success":false, "reason":"no_customer"}

## 只冻结已入账数据，不在结算窗中发奖。旧档只使用本日序号范围的回执。
static func settle(sm: Node, reason: String) -> Dictionary:
	var day := Day.snapshot(sm)
	if not valid_day(day): return {"success":false,"reason":"invalid_state"}
	if not sm.freezer_valid(): return {"success":false,"reason":"portion_inventory_mismatch"}
	if day.has("settlement"): return {"success":true}
	var before: Dictionary = sm.get("_state").duplicate(true)
	var modern := Portions.managed(sm.get("_state"))
	if modern:
		if not Portions.close(sm.get("_state"),sm.INVENTORY_KEY,sm.PREPARED_DISHES_KEY,sm.COOKING_STATE_KEY):
			sm.set("_state",before)
			return {"success":false,"reason":"portion_inventory_mismatch"}
		day = Day.snapshot(sm)
	var customers: Dictionary = sm.restaurant_customers()
	var first := int(day.get("start_serial", int(customers.serial) - int(day.get("arrived",0))))
	var stats := {"day":int(day.get("day",1)), "completed":0, "income":0, "deductions":0, "reputation":0, "reason":reason, "legacy":not day.has("start_gold")}
	stats["losses"] = day.get("dish_losses",{}).duplicate(true)
	stats["losses_known"] = modern
	stats["portions_complete"] = modern
	if modern:
		stats["menu_sold"] = day.portions.filter(func(u): return u.phase=="sold").size()
		stats["menu_lost"] = day.portions.filter(func(u): return u.phase=="lost").size()
	else: stats.legacy = true
	for key in sm.get("_state").get("restaurant_order_receipts", {}):
		if not str(key).begins_with("service_"): continue
		var serial := int(str(key).trim_prefix("service_"))
		if serial <= first or serial > int(customers.serial): continue
		var receipt: Dictionary = sm.get("_state")["restaurant_order_receipts"][key]
		var gold := int(receipt.get("gold_delta",receipt.get("gold_awarded",0)))
		stats.income += maxi(0,gold)
		stats.deductions += maxi(0,-gold)
		stats.reputation += int(receipt.get("reputation_delta",receipt.get("reputation_awarded",0)))
		if receipt.get("outcome") == "served": stats.completed += 1
		if receipt.get("outcome") == "wrong_dish" and not modern:
			var dish := str(receipt.get("item_id",""))
			if Recipes.RECIPES.has(dish): stats.losses[dish] = int(stats.losses.get(dish,0)) + 1
	for key in sm.get("_state").get("ganlu_service_v1",{}).get("receipts",{}):
		if not str(key).begins_with("service_"): continue
		var serial := int(str(key).trim_prefix("service_"))
		if serial <= first or serial > int(customers.serial): continue
		var receipt: Dictionary = sm.get("_state")["ganlu_service_v1"].receipts[key]
		var gold := int(receipt.get("gold_delta",receipt.get("gold",0)))
		stats.income += maxi(0,gold)
		stats.deductions += maxi(0,-gold)
	stats["net"] = stats.income - stats.deductions
	if not stats.legacy:
		stats.net = sm.gold_balance() - int(day.start_gold)
		stats.reputation = sm.reputation() - int(day.start_reputation)
	# 在座及前台保留离场演出；尚未显示的旧队列无罚撤销。
	var orders: Array = customers.seated.duplicate()
	if not customers.front.is_empty(): orders.append(customers.front)
	for order in orders:
		if order.get("stage") != "done": order.outcome = "closed"
		order.stage = "done"
		order.phase = "leaving"
		order.erase("resume_phase")
	customers.queue = []
	customers.legacy_waiting = []
	day.status = "closing"
	day.remaining = 0.0
	day["settlement"] = stats
	sm.get("_state")[Day.KEY] = day
	day["history"] = Day.settlement_history(sm,stats)
	sm.get("_state")[Day.KEY] = day
	sm.get("_state")["restaurant_customers"] = customers
	return commit(sm, before, {"settled":true})

static func acknowledge_settlement(sm: Node) -> Dictionary:
	var day := Day.snapshot(sm)
	if day.get("status") != "closing" or not day.has("settlement"): return {"success":false,"reason":"no_settlement"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	day["history"] = Day.settlement_history(sm,day.settlement)
	day.last_menu = day.get("menu",{}).duplicate(true)
	day.menu = {}
	day.status = "preparing"
	day["preparation_left"] = 3600.0
	if not sm.get("_state").get("preparation_lesson_seen",false): day["preparation_lesson_pending"] = true
	day.day = int(day.get("day",1)) + 1
	day["last_settlement"] = day.settlement
	day.erase("settlement")
	day["dish_losses"] = {}
	day["loss_tracking"] = true
	day.erase("portions")
	day.erase("portions_revision")
	var customers: Dictionary = sm.restaurant_customers()
	customers.front = {}
	customers.seated = []
	customers.queue = []
	customers.legacy_waiting = []
	sm.get("_state")[Day.KEY] = day
	sm.get("_state")["restaurant_customers"] = customers
	return commit(sm,before)
