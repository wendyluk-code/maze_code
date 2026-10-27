extends Node
var failures := 0
var checks := 0
var sm: Node

func _ready() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ", label)

func seed_completed() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "res://output/day1_03/state.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	print("USERDIR ", ProjectSettings.globalize_path("user://"))
	for method in ["accept_first_order", "claim_first_order_ingredients", "cook_first_order", "deliver_first_order"]:
		var result: Dictionary = sm.call(method)
		print(method, " ", result)
		check(result.success, "首章真实事务 " + method)
	for expected in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(expected): continue
		if expected != "ready_to_depart": check(sm.advance_departure(expected).success, "首章准备 " + expected)
	for expected in ["party", "home", "maze", "title"]: check(sm.advance_chapter_1_outro(expected).success, "首章结束 " + expected)

func run() -> void:
	sm = get_node("/root/SaveManager")
	sm.data = sm._defaults()
	check(not sm.ensure_restaurant_customer().success and sm.restaurant_customers().front.is_empty(), "首章未完成不来客")
	seed_completed()
	# 当前版本逐位到店；先固定日期，隔离到店事务与每日日期维护。
	sm.data.restaurant_customers.daily_key = Time.get_date_string_from_system()
	var before_arrival: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	check(not sm.ensure_restaurant_customer().success and sm.data == before_arrival, "到店保存失败回滚")
	sm._active_save_path = "res://output/day1_03/state.json"
	check(sm.ensure_restaurant_customer().success, "章后未访迷宫即来客")
	check(sm.restaurant_customers().queue.is_empty() and sm.restaurant_customers().seated.is_empty(), "单客候场不占座")
	var queued_state: Dictionary = sm.restaurant_customers()
	check(sm.ensure_restaurant_customer().success and sm.restaurant_customers() == queued_state, "重复刷新不重生")
	sm.load_data()
	check(sm.restaurant_customers() == JSON.parse_string(JSON.stringify(queued_state)), "读档恢复前台及队列")
	var malformed: Dictionary = queued_state.duplicate(true)
	malformed.queue.append(malformed.front.duplicate(true))
	malformed.queue[0].id = "invalid_queue"
	malformed.queue[0].phase = "waiting"
	malformed.queue[0].seat = 0
	check(not sm._customers_valid(malformed), "候客队列拒绝混入已占座阶段")
	malformed = queued_state.duplicate(true)
	malformed.front.phase = "queued"
	check(not sm._customers_valid(malformed), "前台记录必须为前台阶段")
	var legacy: Dictionary = queued_state.duplicate(true)
	legacy.erase("queue")
	legacy.serial = 1
	sm.data.restaurant_customers = legacy
	check(sm.ensure_restaurant_customer().success and sm.restaurant_customers() == queued_state, "旧单前台档保留订单且不预生成队列")
	check(sm.record_maze_location("maze_entry", sm.MazeRoads.SPAWN).success, "真实进入事件")
	check(not sm.ensure_restaurant_customer().success, "迷宫内不来客")
	check(sm.record_maze_location("restaurant", sm.MazeRoads.SPAWN).success, "返店事件")
	var ids: Array = []
	for index in range(3):
		check(sm.ensure_restaurant_customer().success, "第%d位来客" % (index + 1))
		var order: Dictionary = sm.restaurant_customers().front
		ids.append(order.id)
		var inventory: Dictionary = sm.inventory_snapshot()
		var before: Dictionary = sm.data.duplicate(true)
		sm._active_save_path = ""
		check(not sm.accept_restaurant_customer(order.id).success and sm.data == before, "接单保存失败原子回滚")
		sm._active_save_path = "res://output/day1_03/state.json"
		check(sm.accept_restaurant_customer(order.id).success, "原子预留座位")
		check(sm.inventory_snapshot() == inventory, "接单不发料")
		check(order.item_id in sm.unlocked_recipe_ids(), "接单自动收录食谱")
		check(not sm.accept_restaurant_customer(order.id).success, "重复输入不重复接单")
		check(sm.advance_restaurant_customer(order.id, "seating", "waiting").success, "入座检查点")
	check(not sm.ensure_restaurant_customer().success and sm.restaurant_customers().front.is_empty(), "三席满座不生成第四客")
	check(sm.customer_orders_active().size() == 3, "独立三订单")
	check(sm.quest_snapshot().active.filter(func(q): return q.type == "order").size() == 3, "任务展示三实例")
	check(sm.quest_snapshot().active.any(func(q): return q.type == "exploration"), "探索主线任务保留")
	check(sm.save(), "保存三单")
	sm.load_data()
	check(sm.customer_orders_active().size() == 3, "重载三单三席")
	check(not sm.deliver_restaurant_customer(ids[0]).success, "无料理不可交付")
	# 隔离测试通过仓库真实取料；不改变生产库存默认值。
	for config in sm.CustomerCatalog.CUSTOMERS:
		var recipe: Dictionary = sm.RecipeCatalog.get_recipe(config.recipe)
		for id in recipe.ingredients: sm.data.warehouse_stock[id] = 2
		check(sm.take_warehouse_items(recipe.ingredients).success, "真实取料 " + config.recipe)
		check(sm.start_cooking(config.recipe).success, "真实扣料 " + config.recipe)
		if config.recipe == "slime_candy":
			sm.load_data()
			check(sm.inventory_quantity(config.recipe) == 1, "中断烹饪读档恢复一份")
		else: check(sm.finish_first_order_cooking(3).success, "真实烹饪产出 " + config.recipe)
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	check(not sm.deliver_restaurant_customer(ids[1]).success and sm.data == before, "交付保存失败全量回滚")
	sm._active_save_path = "res://output/day1_03/state.json"
	var gold: int = sm.gold_balance()
	check(sm.deliver_restaurant_customer(ids[1]).success, "指定第二单交付")
	check(sm.restaurant_customer_order(ids[0]).phase == "waiting" and sm.restaurant_customer_order(ids[2]).phase == "waiting", "不串第一第三单")
	check(sm.gold_balance() == gold + 20, "第二单20金币")
	check(sm.inventory_quantity("slime_candy") == 1 and sm.inventory_quantity("brick_snail_sashimi") == 0 and sm.inventory_quantity("lizard_tail_skewer") == 1, "只消耗指定料理")
	before = sm.data.duplicate(true)
	check(not sm.deliver_restaurant_customer(ids[1]).success and sm.data == before, "重复结算无奖励")
	check(not sm.ensure_restaurant_customer().success, "餐后演出仍占座")
	for phases in [["eating", "farewell"], ["farewell", "leaving"], ["leaving", "departed"]]:
		check(sm.advance_restaurant_customer(ids[1], phases[0], phases[1]).success, "离场检查点 " + phases[1])
	check(not sm.ensure_restaurant_customer().success and sm.restaurant_customers().front.is_empty(), "离开后不循环生成第四单")
	check(sm.deliver_restaurant_customer(ids[0]).success and sm.deliver_restaurant_customer(ids[2]).success, "第一第三单独立交付")
	check(sm.gold_balance() == gold + 70, "三单合计70金币")
	check(sm.save(), "保存结算状态")
	sm.load_data()
	check(sm.gold_balance() == gold + 70 and not sm.deliver_restaurant_customer(ids[2]).success, "读档不重复发奖")
	var valid_state: Dictionary = sm.data.duplicate(true)
	sm.data.restaurant_customers.daily_key = "2000-01-01"
	check(not sm.ensure_restaurant_customer().success and sm.restaurant_customers().front.is_empty(), "跨天不重置一次性顾客")
	var duplicate := {"id":"restaurant_4", "customer_id":"mage", "item_id":"slime_candy", "item_name":"史莱姆糖块", "quantity":1, "phase":"front", "seat":-1}
	sm.data.restaurant_customers.front = duplicate
	sm.data.restaurant_customers.serial = 4
	var before_cleanup: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	check(not sm.ensure_restaurant_customer().success and sm.data == before_cleanup, "旧重复客人清理保存失败回滚")
	sm._active_save_path = "res://output/day1_03/state.json"
	check(not sm.ensure_restaurant_customer().success and sm.restaurant_customers().front.is_empty(), "旧存档未接循环客人撤下")
	sm.load_data()
	check(not sm.ensure_restaurant_customer().success and sm.restaurant_customers().front.is_empty(), "重新读档不循环来客")
	sm.data.restaurant_customers = {"seated": [null]}
	check(not sm.ensure_restaurant_customer().success and not sm.deliver_restaurant_customer(ids[0]).success, "损坏顾客记录拒绝来客和结算")
	sm.data = valid_state
	print("DAY1_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
