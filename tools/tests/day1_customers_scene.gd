extends "res://tools/tests/day1_customers.gd"
var restaurant: Node
var flow: Node
var player: Node2D

func pause(seconds := 0.25) -> void:
	await get_tree().create_timer(seconds).timeout

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await pause(0.1)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await pause(0.15)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/day1_03/" + label + "_%dx%d.png" % [get_viewport().size.x, get_viewport().size.y])

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	await pause(1.0)
	flow = get_tree().get_first_node_in_group("restaurant_customers")
	player = restaurant.get_node("Player")
	check(is_instance_valid(flow), "餐厅顾客控制器就绪")
	check(flow.actors.size() == 3 and sm.restaurant_customers().seated.is_empty(), "章后直接餐厅三人排队")
	player.global_position = stand(restaurant.get_node("InteractPoints/Register"))
	player.last_valid = player.global_position
	await pause(0.8)
	await shot("initial_queue")
	check_outside("初始候客")
	await boundary_shot()
	# 在接单渐隐中读回未接单档：旧异步演出必须停止，三人仍在外侧。
	var outside_save: Dictionary = sm.data.duplicate(true)
	var first_id: String = sm.restaurant_customers().front.id
	check(sm.accept_restaurant_customer(first_id).success, "建立接单转场中断场景")
	flow._sync()
	await pause(0.1)
	sm.data = outside_save
	check(sm.save(), "恢复未接单隔离存档")
	sm.load_data()
	flow._sync()
	await pause(0.75)
	check_outside("旧入场回调取消")
	check(sm.customer_orders_active().is_empty(), "旧入场不推进或占座")
	# 销毁场景再读档，验证队列顺序与外侧锚点一并恢复。
	restaurant.queue_free()
	await pause(0.3)
	sm.load_data()
	restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	await pause(0.7)
	flow = get_tree().get_first_node_in_group("restaurant_customers")
	player = restaurant.get_node("Player")
	check_outside("读档重建候客")
	for index in range(3):
		player.global_position = stand(restaurant.get_node("InteractPoints/Register"))
		player.last_valid = player.global_position
		await pause(0.4)
		await key(KEY_E)
		await pause(0.3)
		check(flow.busy and flow._dialog.visible, "真实E触发前台对白")
		var config: Dictionary = flow.Catalog.CUSTOMERS[index]
		check(flow._dialog.speaker_name.text == config.name and flow._dialog.portrait_texture.texture.resource_path == config.portrait, "正式姓名和独立头像")
		await shot("order_dialog_%d" % index)
		for press in range(2):
			if flow._dialog.visible: await key(KEY_E)
		await pause(1.0)
		check(sm.customer_orders_active().size() == index + 1, "对白结束接单并入座")
		check_outside("接单后剩余候客")
		if index == 0: await shot("first_seated_two_outside")
	await shot("three_seats")
	await calibration()
	await key(KEY_E)
	check(sm.restaurant_customers().front.is_empty(), "真实满座交互不生成第四客")
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	tracker._toggle_tasks()
	await pause(0.4)
	await shot("three_orders_tasks")
	tracker.collapse_details()
	# 真实销毁并重建餐厅，恢复三席且不重复接单。
	restaurant.queue_free()
	await pause(0.3)
	sm.load_data()
	restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	await pause(0.6)
	flow = get_tree().get_first_node_in_group("restaurant_customers")
	player = restaurant.get_node("Player")
	check(flow.actors.size() == 3 and sm.customer_orders_active().size() == 3, "场景重进恢复三席三单")
	var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
	warehouse.open_backpack()
	check(warehouse._slot_by_id.has("wood") and warehouse._slot_by_id.has("moondew_honey"), "既有背包及新食材槽兼容")
	warehouse.close_modal()
	# 测试材料从隔离仓库取出，再通过原料理UI真实开始/结束。
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe("brick_snail_sashimi")
	for id in recipe.ingredients: sm.data.warehouse_stock[id] = 1
	check(sm.take_warehouse_items(recipe.ingredients).success, "隔离仓库真实取料")
	player.global_position = stand(restaurant.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.global_position
	await pause(0.5)
	await key(KEY_E)
	var cooking := get_tree().get_first_node_in_group("cooking_modal")
	check(cooking._open, "真实E打开原烹饪UI")
	await shot("cooking_recipe")
	await click(cooking._start_button)
	await pause(1.0)
	await key(KEY_SPACE)
	await pause(0.8)
	await shot("cooking_result")
	# 原评分弹窗点击继续。
	await key(KEY_E)
	await key(KEY_ENTER)
	await pause(0.3)
	if cooking._open: cooking._on_cancel_pressed()
	player.global_position = stand(restaurant.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	await pause(0.5)
	await key(KEY_E)
	check(flow._modal.visible, "真实吧台打开指定订单选择")
	await shot("delivery_selection")
	await click(flow._modal._cancel_button)
	check(not player.input_locked and not flow.busy, "取消选择恢复输入")
	await key(KEY_E)
	await click(flow._choices.get_child(1))
	await pause(2.2)
	check(sm.restaurant_customer_order("restaurant_2").phase == "farewell", "满意动画后餐后对白")
	await shot("farewell")
	for press in range(2):
		if flow._dialog.visible: await key(KEY_E)
	await pause(1.2)
	check(sm.restaurant_customers().front.get("id") == "restaurant_4", "离场后实际第四客出现")
	check_outside("第四客")
	check(not player.input_locked, "对白完成恢复输入")
	await shot("fourth_customer")
	print("DAY1_SCENE_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check_outside(label: String) -> void:
	var state: Dictionary = sm.restaurant_customers()
	var waiting: Array = []
	if not state.front.is_empty(): waiting.append(state.front)
	waiting.append_array(state.queue)
	var previous := Vector2(INF, INF)
	for order in waiting:
		var foot: Vector2 = flow.actors[order.id].position
		check(int(order.seat) == -1 and foot.x > 600 and foot.y <= 220, label + "：未接单留在外侧道路")
		check(foot.x < previous.x and foot.y < previous.y, label + "：按顺序向左后方")
		previous = foot
		for target_name in ["Register", "BarCounter"]:
			var target: Node2D = restaurant.get_node("InteractPoints/" + target_name)
			check(not Geometry2D.is_point_in_polygon(foot, target.world_foreground_polygon()), label + "：不站柜台实体 " + target_name)
		for seat in flow.Catalog.SEATS:
			check(foot.distance_to(seat) > 150, label + "：不占吧台座位")
	for order in state.seated:
		if order.phase == "waiting":
			check(flow.actors[order.id].position == flow.Catalog.SEATS[int(order.seat)] + Vector2(0, 24), label + "：仅已接单入座")

func boundary_shot() -> void:
	# 仅验收叠加：红线描出前台、吧台实体轮廓，绿线连接外侧候客脚底。
	var marks := Node2D.new()
	restaurant.add_child(marks)
	marks.z_index = 90
	for target_name in ["Register", "BarCounter"]:
		var outline := Line2D.new()
		outline.points = restaurant.get_node("InteractPoints/" + target_name).world_foreground_polygon()
		outline.closed = true
		outline.width = 3
		outline.default_color = Color(1, 0.2, 0.2)
		marks.add_child(outline)
	var queue_line := Line2D.new()
	queue_line.points = PackedVector2Array([flow.Catalog.COUNTER, flow.Catalog.QUEUE[0], flow.Catalog.QUEUE[1]])
	queue_line.width = 4
	queue_line.default_color = Color(0.1, 1, 0.3)
	marks.add_child(queue_line)
	await shot("queue_boundary_evidence")
	marks.queue_free()


func stand(target: Node2D) -> Vector2:
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if player.is_walkable_footprint(candidate):
				player.global_position = candidate
				if player.nearest_interactable() == target: return candidate
	return target.global_position

# 仅隔离验收：同一餐厅摄像机下并列原铁山节点及三位顾客，逐行核对脸部尺寸。
func calibration() -> void:
	flow.set_process(false)
	var iron: Node2D = load("res://scenes/guest_placeholder.tscn").instantiate()
	restaurant.add_child(iron)
	iron.settle_seated()
	iron.position = Vector2(600, 520)
	var saved: Dictionary = {}
	var index := 0
	for id in flow.actors:
		saved[id] = flow.actors[id].position
		flow.actors[id].position = Vector2(300 + index * 155, 520)
		index += 1
	# 铁山在最后，三顾客在前；使用同一个世界坐标尺度。
	iron.position.x = 810
	for row in range(4):
		for column in range(4):
			for id in flow.actors:
				flow._frame(flow.actors[id], sm.restaurant_customer_order(id).customer_id, row, column)
				check(flow.actors[id].flip_h == (row in [1, 2]), "动作朝向 %s/%d/%d" % [id, row, column])
			await shot("calibration_%d_%d" % [row, column])
	for id in flow.actors:
		flow.actors[id].position = saved[id]
		flow._frame(flow.actors[id], sm.restaurant_customer_order(id).customer_id, 1, 0)
	iron.queue_free()
	flow.set_process(true)
