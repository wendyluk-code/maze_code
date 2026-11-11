extends RefCounted
const KEY := "first_exploration_gate_v1"
const CHECKPOINT := "first_exploration_checkpoint_v1"
const RETRY_NOTICE := "first_exploration_retry_notice"

static func legacy_baseline(sm: Node) -> Dictionary:
	# 用户批准：没有入场快照的旧首探档重置至首章已完成。
	var current: Dictionary = sm.get("_state")
	var base: Dictionary = sm._defaults()
	for key in [sm.SLOT_META_KEY, sm.PROLOGUE_DONE_KEY, sm.CHAPTER_1_DONE_KEY, sm.CURRENT_ORDER_KEY, sm.FIRST_ORDER_PROGRESS_KEY, sm.FIRST_ORDER_SETTLEMENT_KEY, sm.WRAPUP_KEY, sm.COOKING_GUIDE_KEY, sm.TUTORIAL_CHECKPOINT_KEY, "tutorial_done", "chapter_1_intro", "chapter_1_outro"]:
		if current.has(key): base[key] = current[key]
	base["warehouse_stock"] = {sm.ROCKMAN_MEAT_ID:0, sm.ROCK_SALT_ID:0}
	base[sm.UNLOCKED_RECIPES_KEY] = [sm.FIRST_ORDER_ITEM_ID]
	base[sm.GOLD_KEY] = int(current.get(sm.FIRST_ORDER_SETTLEMENT_KEY,{}).get("gold_awarded",0))
	base[sm.REPUTATION_KEY] = int(current.get(sm.FIRST_ORDER_SETTLEMENT_KEY,{}).get("reputation_awarded",0))
	var salt_quest: Variant = current.get(sm.QUEST_JOURNAL_KEY,{}).get("instances",{}).get(sm.SALT_POOL_QUEST_ID)
	if salt_quest is Dictionary:
		base[sm.QUEST_JOURNAL_KEY].instances[sm.SALT_POOL_QUEST_ID] = salt_quest.duplicate(true)
	base[KEY] = "active"
	return base

static func remember(sm: Node, food: Dictionary) -> void:
	if not pending(sm): return
	var state: Dictionary = sm.get("_state")
	var before := state.duplicate(true)
	before.erase(CHECKPOINT)
	before.erase(RETRY_NOTICE)
	before[preload("res://scripts/characters/character_progression.gd").FOOD_KEY] = {"values":food.values.duplicate(true), "at":food.at, "paused":false}
	state[CHECKPOINT] = before

static func rollback(sm: Node) -> Dictionary:
	var previous: Dictionary = sm.get("_state").duplicate(true)
	var checkpoint: Variant = previous.get(CHECKPOINT)
	if not checkpoint is Dictionary or checkpoint.is_empty():
		checkpoint = legacy_baseline(sm)
	var restored: Dictionary = checkpoint.duplicate(true)
	restored[KEY] = "active"
	restored[RETRY_NOTICE] = true
	restored.erase("capture_run_v1")
	restored.erase("capture_first_visit_started")
	restored.erase("ch2_guide_01")
	restored.erase("first_business_intro_pending")
	restored[sm.MAZE_STATE_KEY] = sm._empty_maze_state()
	var food_key := preload("res://scripts/characters/character_progression.gd").FOOD_KEY
	var food: Dictionary = restored.get(food_key, {"values":{}})
	food["at"] = Time.get_unix_time_from_system()
	food["paused"] = false
	restored[food_key] = food
	sm.set("_state", restored)
	if sm.save(): return {"success":true, "rolled_back":true}
	sm.set("_state", previous)
	return {"success":false,"reason":"save_failed"}

static func pending(sm: Node) -> bool:
	var state: Dictionary = sm.get("_state")
	if state.has(KEY): return state[KEY] == "active"
	return not state.get("capture_first_visit_started",false) and not sm.maze_exploration_state().chapter_2_started

static func departure(sm: Node) -> bool:
	return sm.is_chapter_1_done() and sm.chapter_1_outro_state()=="done" and pending(sm) and sm.maze_exploration_state().region=="restaurant"

static func return_message(sm: Node, bank: bool) -> String:
	if not pending(sm): return ""
	# 首探战败由返程事务恢复入场快照，不完成教学。
	var run: Dictionary = sm.get("_state").get("capture_run_v1",{})
	if not bank and run.get("active",false) and float(run.get("combat",{}).get("hp",1))<=0: return ""
	if not bank: return "请先完成当前探索"
	if not sm.elder_backpack_unlocked(): return "请先接取并完成白虎爷爷的任务"
	var bag: Dictionary = run.get("bag", {})
	if bag.is_empty(): return "请先捕获魔物，带回食材再结束探索"
	var stock: Dictionary = sm.warehouse_snapshot()
	for id in bag: stock[id] = int(stock.get(id,0)) + int(bag[id])
	var recipes := preload("res://scripts/cooking/recipe_catalog.gd")
	for id in sm.unlocked_recipe_ids():
		if recipes.order_gold(id) <= 0: continue
		var enough := true
		for item in recipes.get_recipe(id).ingredients:
			if int(stock.get(item,0)) < int(recipes.get_recipe(id).ingredients[item]): enough = false
		if enough: return ""
	return "请先收集能制作一道料理的食材，再结束探索"
