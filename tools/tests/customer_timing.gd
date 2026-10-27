extends "res://tools/tests/npc_01_scene.gd"

func held(code: Key, seconds: float) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await pause(seconds)
	e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	Input.parse_input_event(e)
	await pause(0.05)

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	sm.data.capture_first_visit_started = true
	sm.save()
	await reopen()
	check(sm.restaurant_customers().front.is_empty(), "静止不来男01")
	player.input_locked = true
	await held(KEY_D, 0.25)
	player.input_locked = false
	await held(KEY_RIGHT, 0.25)
	check(float(sm.data.get("customer_01_walk_seconds", 0)) == 0.0, "锁定输入及方向键不计WASD移动")
	await held(KEY_D, 0.6)
	await held(KEY_A, 0.6)
	check(sm.restaurant_customers().front.is_empty(), "不足两秒不来客")
	var progress: float = sm.data.get("customer_01_walk_seconds", 0.0)
	check(progress > 0.6 and progress < 2.0, "真实WASD位移累计")
	await reopen()
	check(is_equal_approx(float(sm.data.get("customer_01_walk_seconds", 0)), progress), "移动进度读档保留")
	await held(KEY_D, 0.6)
	await held(KEY_A, 0.6)
	await pause(0.4)
	check(sm.restaurant_customers().front.get("id") == "restaurant_1", "累计两秒生成男01")
	# 关闭首客教学，随后冻结视觉，单独验证事务条件。
	for i in 4:
		await key(KEY_E)
		await pause(0.2)
	flow.set_process(false)
	var point: Vector2 = sm.MazeRoads.SPAWN
	check(sm.record_maze_location("maze_entry", point).success, "接单前进迷宫")
	check(sm.record_maze_location("restaurant", point).success, "接单前回餐厅")
	check(sm.accept_restaurant_customer("restaurant_1").success, "接男01")
	check(not sm.ensure_restaurant_customer().success, "接单前往返不计入女05")
	check(preload("res://scripts/maze/capture_run.gd").begin(sm, point).success, "接单后进入迷宫")
	sm.load_data()
	check(sm.data.get("customer_05_trip_started", false), "迷宫中读档保留本趟资格")
	check(not sm.ensure_restaurant_customer().success, "迷宫中不来客")
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	check(not preload("res://scripts/maze/capture_run.gd").finish(sm, false, point).success and not sm.data.get("customer_05_returned", false), "返回保存失败不解锁女05")
	sm._active_save_path = save_path
	check(preload("res://scripts/maze/capture_run.gd").finish(sm, false, point).success, "接单后回餐厅")
	check(sm.ensure_restaurant_customer().success, "回餐厅生成女05")
	check(sm.accept_restaurant_customer("restaurant_2").success, "接女05")
	check(not sm.ensure_restaurant_customer().success, "接女05不生成男08")
	check(sm.advance_restaurant_customer("restaurant_2", "seating", "waiting").success, "女05入座")
	var order: Dictionary = sm.restaurant_customer_order("restaurant_2")
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
	for ingredient in recipe.ingredients: sm.data.warehouse_stock[ingredient] = 1
	check(sm.take_warehouse_items(recipe.ingredients).success, "取料")
	check(sm.start_cooking(order.item_id).success and sm.finish_first_order_cooking(2).success, "制作二星")
	check(sm.deliver_restaurant_customer(order.id).success, "交付女05")
	check(not sm.ensure_restaurant_customer().success, "交付后进食不来男08")
	check(sm.customer_review(order.id) == "吃着还凑合，至少填饱肚子了。", "评价读取真实二星凭证")
	sm.advance_restaurant_customer(order.id, "eating", "farewell")
	check(not sm.ensure_restaurant_customer().success, "对白未结束不来男08")
	flow.set_process(true)
	flow._sync()
	await pause(0.4)
	await shot("customer_timing_two_star")
	for i in 3: await key(KEY_E)
	await pause(1.1)
	check(sm.restaurant_customer_order(order.id).is_empty(), "实际对白结束离场完成")
	check(sm.ensure_restaurant_customer().success, "离场后生成男08")
	sm.load_data()
	check(sm.restaurant_customers().front.get("id") == "restaurant_3", "男08读档保持")
	for quality in [1,3]:
		sm.data.restaurant_order_receipts[order.id].quality = quality
		check(sm.customer_review(order.id) == ("真美味啊，下次还来！" if quality == 3 else "……怎么有股糊糊的味道，勉强能吃吧。"), "星级评价%d" % quality)
	print("TIMING_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
