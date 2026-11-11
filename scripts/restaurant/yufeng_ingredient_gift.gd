extends RefCounted
## 御风赠礼直接入仓；回执、食谱解锁与剧情阶段同一次提交。
const Catalog = preload("res://scripts/cooking/recipe_catalog.gd")
const KEY := "yufeng_ingredients_granted_v1"
const ITEMS := {"white_truffle":3,"jade_lily":3,"golden_bird_nest":3}
const RECIPES := ["truffle_beetle_legs","jade_lily_silverfish","bird_nest_crab"]

static func grant(sm: Node) -> Dictionary:
	var state: Dictionary = sm.get("_state")
	if state.get(KEY, false): return {"success":true,"created":false}
	if sm.yufeng_salia_record().phase != "gift_pending": return {"success":false,"reason":"invalid_phase"}
	var raw = state.get("warehouse_stock", {})
	if not raw is Dictionary: return {"success":false,"reason":"invalid_inventory"}
	var stock: Dictionary = sm.warehouse_snapshot()
	for id in ITEMS:
		var amount = raw.get(id, 0)
		if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or amount < 0 or floor(float(amount)) != amount or amount > 9007199254740991 - ITEMS[id]:
			return {"success":false,"reason":"invalid_inventory"}
		stock[id] = int(stock.get(id, 0)) + ITEMS[id]
	var before := state.duplicate(true)
	var recipes: Array = sm.unlocked_recipe_ids()
	for id in RECIPES:
		if id not in recipes: recipes.append(id)
	state["warehouse_stock"] = stock
	preload("res://scripts/restaurant/restaurant_day.gd").record_task_loot(state, ITEMS)
	state[sm.UNLOCKED_RECIPES_KEY] = recipes
	state[KEY] = true
	var record: Dictionary = sm.yufeng_salia_record()
	record.phase = "gift_reward"
	record.line = 0
	state[sm.YUFENG_SALIA_KEY] = record
	if not sm.save():
		sm.set("_state",before)
		return {"success":false,"reason":"save_failed"}
	return {"success":true,"created":true}

static func presentation_valid(sm: Node, phase: String) -> bool:
	var granted: bool = sm.get("_state").get(KEY, false) == true
	if phase == "gift_pending": return not granted
	return granted
