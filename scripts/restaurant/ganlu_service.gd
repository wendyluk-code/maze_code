extends RefCounted
## 甘露水事务：杯子、冰度和奖励与订单一起保存，失败完整回滚。
const KEY := "ganlu_service_v1"
const TARGET := 0.65
const ICE_NAMES := ["常温", "加冰", "加冰", "加冰", "损坏"]

static func snapshot(sm: Node) -> Dictionary:
	var raw: Variant = sm.get("_state").get(KEY, {"held":{}, "slots":[{}, {}, {}], "receipts":{}})
	if raw is Dictionary and valid(raw):
		var result: Dictionary = raw.duplicate(true)
		for cup in [result.held] + result.slots:
			if cup.is_empty() or cup.get("chill_revision",1)==3: continue
			var old := float(cup.cold)
			# 旧档已达任一冰度保留为加冰，旧损坏保持损坏；未达标保留进度。
			cup.cold = 8.001 if cup.get("chill_revision",1)==2 and old>=18 else (3.0 if old>=3 else old)
			cup.chill_revision = 3
		return result
	return {"held":{}, "slots":[{}, {}, {}], "receipts":{}, "invalid":true}
static func cup_valid(cup: Dictionary) -> bool:
	if cup.is_empty(): return true
	return cup.get("amount") is float or cup.get("amount") is int

static func valid(state: Dictionary) -> bool:
	if state.get("invalid", false): return false
	if not state.get("held") is Dictionary or not state.get("slots") is Array or state.slots.size() != 3 or not state.get("receipts") is Dictionary: return false
	var cups: Array = [state.held] + state.slots
	for cup in cups:
		if not cup is Dictionary or not cup_valid(cup): return false
		if cup.is_empty(): continue
		if not is_finite(float(cup.amount)) or float(cup.amount) < 0 or float(cup.amount) > 1.2: return false
		if cup.get("phase") not in ["pouring", "ready"]: return false
		if not (cup.get("cold") is float or cup.get("cold") is int) or not is_finite(float(cup.cold)) or float(cup.cold) < 0 or float(cup.cold) > (8.001 if cup.get("chill_revision",1)==3 else (18 if cup.get("chill_revision",1)==2 else 9)): return false
	return true

static func commit(sm: Node, state: Dictionary) -> Dictionary:
	if not valid(state): return {"success":false, "reason":"invalid_state"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	sm.get("_state")[KEY] = state
	if sm.save(): return {"success":true}
	sm.set("_state", before)
	return {"success":false, "reason":"save_failed"}

static func begin(sm: Node) -> Dictionary:
	var state := snapshot(sm)
	if not valid(state) or sm.hands_occupied(): return {"success":false, "reason":"hands_full"}
	state.held = {"amount":0.0, "cold":0.0, "phase":"pouring", "chill_revision":3}
	return commit(sm, state)

static func finish(sm: Node, amount: float) -> Dictionary:
	if not is_finite(amount) or pour_factor(amount) <= 0: return {"success":false,"reason":"invalid_amount"}
	var state := snapshot(sm)
	if not valid(state) or state.held.get("phase", "") != "pouring": return {"success":false, "reason":"already_finished"}
	state.held = {"amount":clampf(amount, 0, 1.2), "cold":0.0, "phase":"ready", "chill_revision":3}
	return commit(sm, state)

static func discard(sm: Node) -> Dictionary:
	var state := snapshot(sm)
	state.held = {}
	return commit(sm, state)

static func grade(cup: Dictionary) -> int:
	var cold := float(cup.get("cold",0))
	if cup.get("chill_revision",1)!=3:
		if cup.get("chill_revision",1)==2 and cold>=18: return 4
		return 1 if cold>=3 else 0
	if cold > 8.0: return 4
	return 1 if cold >= 3.0 else 0

static func fill(cup: Dictionary) -> float:
	return clampf(float(cup.get("cold",0))/3.0,0,1)

static func chilling(cup: Dictionary) -> bool:
	return not cup.is_empty() and float(cup.get("cold",0)) < 3.0
static func pour_factor(amount: float) -> float:
	if amount > 1.0 or amount <= 0: return 0.0
	var error := absf(amount - TARGET)
	if error <= 0.050001: return 1.0
	if error <= 0.150001: return 0.5
	return 0.0

static func ice_factor(actual: int, wanted: int) -> float:
	if actual == 4: return 0.0
	var difference := absi(actual - (1 if wanted>0 else 0))
	return 1.0 if difference == 0 else (0.5 if difference == 1 else 0.0)

static func slot(sm: Node, index: int) -> Dictionary:
	var state := snapshot(sm)
	if not sm.freezer_unlocked() or not valid(state) or index < 0 or index > 2: return {"success":false, "reason":"unavailable"}
	if state.slots[index].is_empty():
		if state.held.get("phase", "") != "ready" or float(state.held.get("amount", 0)) <= 0: return {"success":false, "reason":"empty_cup"}
		state.slots[index] = state.held
		state.held = {}
	else:
		if chilling(state.slots[index]): return {"success":false, "reason":"chilling"}
		if sm.hands_occupied(): return {"success":false, "reason":"hands_full"}
		state.held = state.slots[index]
		# 取出暂停累计进度，重放不重置达标窗口或过冰状态。
		state.slots[index] = {}
	return commit(sm, state)

static func tick(sm: Node, delta: float) -> void:
	# 只累计餐厅运行时间；暂停、退出和离线不累计。其他事务会保存当前精度。
	var state := snapshot(sm)
	if not valid(state): return
	for cup in state.slots:
		if not cup.is_empty(): cup.cold = minf(8.001, float(cup.cold) + maxf(0, delta))
	sm.get("_state")[KEY] = state

static func deliver(sm: Node, id: String) -> Dictionary:
	var state := snapshot(sm)
	if not valid(state): return {"success":false, "reason":"invalid_state"}
	if state.held.get("phase", "") != "ready" or float(state.held.get("amount", 0)) <= 0: return {"success":false, "reason":"empty_cup"}
	var customers: Dictionary = sm.restaurant_customers()
	if not sm._customers_valid(customers): return {"success":false, "reason":"invalid_state"}
	for order in customers.seated:
		if order.id != id: continue
		if order.get("cycle", false): return _deliver_cycle(sm, state, customers, order)
		if order.phase != "waiting" or not order.has("drink_ice") or order.get("drink_done", false) or state.receipts.has(id): return {"success":false, "reason":"no_demand"}
		var factor := ice_factor(grade(state.held), int(order.drink_ice)) if pour_factor(float(state.held.amount)) > 0 else 0.0
		var reward := 5 + int(2 * factor) - (2 if grade(state.held)==4 else 0)
		if not sm.chest_reward_state_valid() or sm.gold_balance() > 9007199254740991 - reward: return {"success":false, "reason":"invalid_reward"}
		var before: Dictionary = sm.get("_state").duplicate(true)
		state.receipts[id] = {"gold":reward, "cup":state.held.duplicate(true), "wanted":order.drink_ice}
		state.held = {}
		order.drink_done = true
		if order.get("food_done", false): order.phase = "eating"
		sm.get("_state")[KEY] = state
		sm.get("_state")["restaurant_customers"] = customers
		sm.get("_state")[sm.GOLD_KEY] = sm.gold_balance() + reward
		if sm.save(): return {"success":true, "gold":reward, "factor":factor}
		sm.set("_state", before)
		return {"success":false, "reason":"save_failed"}
	return {"success":false, "reason":"no_demand"}

static func _deliver_cycle(sm: Node, state: Dictionary, customers: Dictionary, order: Dictionary) -> Dictionary:
	if order.phase != "waiting": return {"success":false, "reason":"no_demand"}
	if grade(state.held)==4:
		var before: Dictionary = sm.get("_state").duplicate(true)
		# 复用无料理消耗的离场结算；罚款与声望实际扣除写同一回执。
		order.stage = "drink"
		preload("res://scripts/restaurant/service_cycle.gd").timeout(sm,order)
		order.outcome = "spoiled_drink"
		sm.get("_state")["restaurant_order_receipts"][order.id].outcome = "spoiled_drink"
		state.held = {}
		sm.get("_state")[KEY] = state
		sm.get("_state")["restaurant_customers"] = customers
		return preload("res://scripts/restaurant/service_cycle.gd").commit(sm,before,{"angry":true,"gold":-2,"factor":0.0})
	var wanted: bool = order.stage == "drink" and not state.receipts.has(order.id)
	var factor := 0.0
	var reward := 0
	var penalty := 0
	if wanted:
		# 能从准备完成弹窗端走的水均通过倒量判定；冰度仍独立匹配。
		factor = ice_factor(grade(state.held), int(order.drink_ice)) if pour_factor(float(state.held.amount)) > 0 else 0.0
		# 不达标水只扣一金币并继续料理；冰镇计时、杯子等级保持原规则。
		penalty = 1 if factor < 1.0 else 0
		reward = -1 if penalty else 7
	if not sm.chest_reward_state_valid() or sm.gold_balance() > 9007199254740991 - maxi(0,reward): return {"success":false, "reason":"invalid_reward"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	if wanted:
		var reputation_reward := 5 if factor>=1.0 else 0
		sm.get("_state")[sm.REPUTATION_KEY] = sm.reputation()+reputation_reward
		state.receipts[order.id] = {"gold":reward, "gold_delta":maxi(0,sm.gold_balance()+reward)-sm.gold_balance(), "penalty":penalty, "cup":state.held.duplicate(true), "wanted":order.drink_ice}
		state.receipts[order.id]["reputation_delta"] = reputation_reward
		preload("res://scripts/restaurant/service_cycle.gd").wait_for_food(order)
	state.held = {}
	sm.get("_state")[KEY] = state
	sm.get("_state")["restaurant_customers"] = customers
	sm.get("_state")[sm.GOLD_KEY] = maxi(0,sm.gold_balance() + reward)
	return preload("res://scripts/restaurant/service_cycle.gd").commit(sm, before, {"gold":reward, "factor":factor, "penalty":penalty, "question":not wanted})
