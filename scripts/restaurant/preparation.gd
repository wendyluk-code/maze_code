extends Node
## 在线准备期；不使用墙钟，因此离线不扣时间。
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const SECONDS := 3600.0
var checkpoint := 0.0

static func restricted(sm: Node) -> bool:
	return sm.is_chapter_1_done() and sm._state.get("first_exploration_gate_v1", "") == "done" and Day.snapshot(sm).get("status", "preparing") == "preparing"

static func allowed(sm: Node, target: String) -> bool:
	return not restricted(sm) or target in ["迷宫入口", "冒险者之家入口"]

static func expired(sm: Node) -> bool:
	var day := Day.snapshot(sm)
	return restricted(sm) and day.has("preparation_left") and float(day.preparation_left) <= 0

static func cookable(sm: Node) -> bool:
	for id in sm.unlocked_recipe_ids():
		if Recipes.order_gold(id)>0 and Day.validate_menu(sm,{id:1}).success: return true
	return false

static func tick(sm: Node, delta: float) -> bool:
	var day := Day.snapshot(sm)
	if not restricted(sm) or int(day.get("day",1))<2: return false
	if not day.has("preparation_left"): day.preparation_left = SECONDS
	day.preparation_left = maxf(0,float(day.preparation_left)-maxf(0,delta))
	sm._state[Day.KEY] = day
	return true

static func skip(sm: Node) -> Dictionary:
	if not expired(sm) or cookable(sm): return {"success":false,"reason":"not_allowed"}
	var before: Dictionary = sm._state.duplicate(true)
	var day := Day.snapshot(sm)
	day.status = "closing"
	day.menu = {}
	day.settlement = {"day":int(day.get("day",1)),"income":0,"deductions":0,"net":0,"reputation":0,"completed":0,"losses":{},"losses_known":true,"portions_complete":true,"menu_sold":0,"menu_lost":0,"closed_day":true}
	sm._state[Day.KEY] = day
	return preload("res://scripts/restaurant/service_cycle.gd").commit(sm,before)

func _process(delta: float) -> void:
	var sm := get_parent()
	var scene := get_tree().current_scene
	if scene == null or sm._replaying or sm._prologue_preview: return
	# 开始界面及存档选择不算在线游玩；计时不依赖餐厅节点。
	if not (scene.scene_file_path == sm.RESTAURANT_SCENE or scene.is_in_group("maze_entry") or scene.scene_file_path.contains("adventurer_home")): return
	if get_tree().get_first_node_in_group("preparation_lesson") != null: return
	if tick(sm,delta):
		checkpoint += delta
		if checkpoint >= 1.0:
			if sm.save(): checkpoint = 0.0
	else: checkpoint = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and checkpoint>0: get_parent().save()
