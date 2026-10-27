extends "res://tools/tests/day1_customers_scene.gd"

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/r1/" + label + "_%dx%d.png" % [get_viewport().size.x, get_viewport().size.y])

func wheel(at: Vector2, button: MouseButton, count: int) -> void:
	for index in count:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = button
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().process_frame
	await pause()

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	check(sm.ensure_restaurant_customer().success, "建立三位隔离顾客")
	for index in 3:
		check(sm.ensure_restaurant_customer().success, "推进前台候客")
		var id: String = sm.restaurant_customers().front.id
		check(sm.accept_restaurant_customer(id).success, "真实接单事务")
		check(sm.advance_restaurant_customer(id, "seating", "waiting").success, "入座检查点")
	restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	await pause(1.0)
	flow = get_tree().get_first_node_in_group("restaurant_customers")
	player = restaurant.get_node("Player")
	var hud := get_tree().get_first_node_in_group("restaurant_hud")
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	check(hud.find_children("BackpackEntry", "", true, false).is_empty(), "餐厅没有背包入口")
	check(hud._recipe_entry.visible, "餐厅菜谱入口保留")
	await click(tracker._task_button)
	await pause(0.4)
	check(absf(tracker._panel.get_global_rect().end.y - 477.0) < 1.0, "任务面板底边固定477像素")
	check(tracker._scroll.get_v_scroll_bar().visible, "溢出出现垂直滑块")
	check(not tracker._scroll.get_h_scroll_bar().visible, "任务无水平滚动")
	await shot("tasks_top")
	var player_position: Vector2 = player.position
	await wheel(tracker._scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, 12)
	check(tracker._scroll.scroll_vertical > 0 and tracker._expanded, "滚轮下拉且面板保持展开")
	check(player.position == player_position, "滚轮不移动玩家")
	check(absf(tracker._panel.get_global_rect().end.y - 477.0) < 1.0, "滚动不改变面板高度")
	await shot("tasks_scrolled")
	var bar: VScrollBar = tracker._scroll.get_v_scroll_bar()
	bar.gui_input.connect(func(event):
		if event is InputEventMouseButton or event is InputEventMouseMotion: print("BAR_EVENT ", event, " value=", bar.value))
	await wheel(tracker._scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP, 50)
	await pause(0.4)
	var press := InputEventMouseButton.new()
	press.position = Vector2(bar.get_global_rect().get_center().x, bar.get_global_rect().position.y + 60)
	var hover := InputEventMouseMotion.new()
	hover.position = press.position
	Input.parse_input_event(hover)
	await get_tree().process_frame
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(press.position.x, bar.get_global_rect().end.y - 25)
	motion.relative = motion.position - press.position
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
	press.position = motion.position
	press.pressed = false
	Input.parse_input_event(press)
	await pause()
	check(tracker._scroll.scroll_vertical > 200, "鼠标拖动滑块可达列表下部")
	await shot("tasks_drag_bottom")
	tracker.collapse_details()
	player.global_position = stand(restaurant.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	await pause(0.4)
	var before: Dictionary = sm.data.duplicate(true)
	await key(KEY_E)
	check(sm.data == before and not player.input_locked and not flow.busy, "无成品上菜不改状态也不锁输入")
	# 第二位顾客料理必须直接交给第二单，不能误交第一单。
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe("brick_snail_sashimi")
	for id in recipe.ingredients: sm.data.warehouse_stock[id] = 1
	check(sm.take_warehouse_items(recipe.ingredients).success, "仓库真实取料")
	player.global_position = stand(restaurant.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.global_position
	await pause(0.4)
	await key(KEY_E)
	var cooking := get_tree().get_first_node_in_group("cooking_modal")
	check(cooking._open, "真实E打开烹饪")
	await click(cooking._start_button)
	await pause(1.0)
	await key(KEY_SPACE)
	await pause(0.8)
	check(cooking._result_popup.visible, "料理结果弹窗正常显示")
	await shot("cooked_result")
	await key(KEY_E)
	await pause(0.2)
	check(sm.restaurant_customer_order("restaurant_2").phase == "eating", "结果确认后直接交付对应第二单")
	check(sm.restaurant_customer_order("restaurant_1").phase == "waiting", "不同配方第一单未误交")
	check(not cooking._open and not player.input_locked, "结果关闭且输入恢复")
	check(flow.find_children("*", "SproutModal", true, false).is_empty(), "顾客流程无订单选择弹窗")
	check(sm.inventory_quantity("brick_snail_sashimi") == 0, "交付消耗一份成品")
	await shot("direct_delivery")
	var receipts: Dictionary = sm.data.restaurant_order_receipts.duplicate(true)
	var rewards := Vector2(sm.reputation(), sm.gold_balance())
	flow.deliver_ready_order("brick_snail_sashimi")
	check(sm.data.restaurant_order_receipts == receipts and Vector2(sm.reputation(), sm.gold_balance()) == rewards, "重复交付不重复结算")
	await pause(2.2)
	for press_index in 2:
		if flow._dialog.visible: await key(KEY_E)
	await pause(1.0)
	# 第一单用真实烹饪事务准备成品，故意使交付保存失败。
	recipe = sm.RecipeCatalog.get_recipe("slime_candy")
	for id in recipe.ingredients: sm.data.warehouse_stock[id] = 1
	check(sm.take_warehouse_items(recipe.ingredients).success, "失败场景取料")
	check(sm.start_cooking("slime_candy").success, "失败场景开始料理")
	check(sm.finish_first_order_cooking(2).success, "失败场景保存成品")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	flow.deliver_ready_order("slime_candy")
	check(sm.data == before and not player.input_locked, "交付保存失败成品奖励订单均回滚且输入恢复")
	sm._active_save_path = "res://output/day1_03/state.json"
	player.global_position = stand(restaurant.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	await pause(0.4)
	await key(KEY_E)
	check(sm.restaurant_customer_order("restaurant_1").phase == "eating", "吧台真实E直接重试交付无选择框")
	check(sm.inventory_quantity("slime_candy") == 0, "重试只消耗一份")
	receipts = sm.data.restaurant_order_receipts.duplicate(true)
	sm.load_data()
	check(sm.data.restaurant_order_receipts == JSON.parse_string(JSON.stringify(receipts)), "交付凭证读档一致")
	await pause(2.2)
	for press_index in 2:
		if flow._dialog.visible: await key(KEY_E)
	await pause(1.0)
	check(not player.input_locked, "顾客离席对白后输入恢复")
	# 同一公共任务控件在迷宫仍使用原布局，背包保持本趟暂存用途。
	restaurant.queue_free()
	await pause(0.3)
	check(sm.record_maze_location("maze_entry", sm.MazeRoads.SPAWN).success, "隔离存档进入迷宫")
	var maze: Node = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await pause(1.0)
	check(maze.backpack_entry.visible, "迷宫保留背包入口")
	await click(maze.backpack_entry)
	check(maze.backpack_warehouse._open and maze.player.input_locked, "迷宫真实点击打开暂存背包并锁定移动")
	await shot("maze_backpack")
	await key(KEY_ESCAPE)
	check(not maze.backpack_warehouse._open and not maze.player.input_locked, "迷宫背包关闭恢复输入")
	print("R1_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
