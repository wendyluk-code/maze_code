extends "res://tools/tests/ch1_qte_03_input.gd"
const Layout := preload("res://scripts/restaurant/layout_anchors.gd")

func _capture(output_dir: String, label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await super._capture(output_dir, label)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "使用隔离存档目录")
	if failures == 0:
		if _arg("--mode=") == "first_order":
			await _first_order_current()
		else:
			await _layout_checks()
	var report := {"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name()}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	get_tree().quit(1 if failures else 0)

func _layout_checks() -> void:
	sm.data = sm._defaults()
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	for method in ["accept_first_order", "claim_first_order_ingredients", "cook_first_order", "deliver_first_order"]:
		_check(sm.call(method).success, "隔离档真实首单事务：" + method)
	for step in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(step) or step == "ready_to_depart": continue
		_check(sm.advance_departure(step).success, "首章准备：" + step)
	for step in ["party", "home", "maze", "title"]:
		_check(sm.advance_chapter_1_outro(step).success, "首章结束：" + step)
	sm.record_customer_walk(2.1)
	_check(sm.ensure_restaurant_customer().success, "行走前置后建立实际普通顾客")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	var player = scene.get_node("Player")
	_check(scene.get_node("BG").texture.resource_path == "res://assets/maps/restaurant_map.png", "恢复原始完整地图")
	for flat_prop in get_tree().get_nodes_in_group("restaurant_layout_props"):
		if scene.get_node("InteractPoints").is_ancestor_of(flat_prop):
			_check(not flat_prop.get_node("Art").visible, str(flat_prop.name) + "不重复绘制拆分图片")
	for stool_name in ["StoolLeft", "StoolMiddle", "StoolRight"]:
		var stool = scene.get_node("InteractPoints/BarCounter/" + stool_name)
		_check(stool.z_index == -3 and not stool.z_as_relative, stool_name + "绝对层级低于顾客")
	for counter_name in ["BarCounter", "Register"]:
		_check(scene.get_node("InteractPoints/" + counter_name).z_index == -1 and player.z_index == 0, counter_name + "始终低于主角")
	for prop_name in ["Cauldron", "FoodCart", "Fridge", "Store", "TrashBin"]:
		_check(scene.get_node("InteractPoints/" + prop_name).z_index == player.z_index and scene.y_sort_enabled and scene.get_node("InteractPoints").y_sort_enabled, prop_name + "与主角按落地点排序")
	var camera = scene.get_node("Camera")
	var flow = get_tree().get_first_node_in_group("restaurant_customers")
	flow._first_arrival_tutorial_done = true
	flow._arrival_tutorial_pending = false
	if flow._arrival_tutorial_busy:
		await _send_key(KEY_E)
		await _send_key(KEY_E)
	_check(player.spawn_ready and player.is_walkable_footprint(player.global_position), "实际餐厅出生点可站立")
	_check(player.is_walkable_footprint(scene.get_node("MazeReturnSpawn").position), "保留的迷宫返回点可站立")
	camera.paused = true
	camera.position = Vector2(724, 543)
	camera.zoom = Vector2(0.64, 0.64)
	_check(scene.y_sort_enabled and scene.get_node("InteractPoints").y_sort_enabled, "餐厅启用落地点前后排序")
	_check(scene.get_node_or_null("PropForeground") == null, "不再从旧底图采样家具遮挡")
	for name in ["Cauldron", "FoodCart", "Fridge", "BarCounter", "Register", "Store", "TrashBin"]:
		var prop = scene.get_node("InteractPoints/" + name)
		_check(prop.get_node("Art").texture != null and prop.get_node("Body/Collision").polygon.size() >= 3, name + "图片和碰撞已在场景中持久化")
		var stand := _stand(prop)
		player.position = stand
		player.last_valid = stand
		_check(player.is_walkable_footprint(stand) and player.nearest_interactable() == prop, name + "可接近且可选中交互")
		await get_tree().process_frame
		await get_tree().process_frame
		var button = scene.get_node("UIOverlay")._buttons.get(prop)
		_check(is_instance_valid(button) and button.is_visible_in_tree() and scene.get_node("UIOverlay").visible, name + "近距按钮及所属界面层可见")
		_check(button.get_global_rect().intersects(get_viewport().get_visible_rect()), name + "按钮显示在屏幕内")
		await _capture(_arg("--output-dir="), "prompt_" + name)
	player.position = Vector2(1000, 850)
	player.last_valid = player.position
	await _capture(_arg("--output-dir="), "layout_overview")
	var cart = scene.get_node("InteractPoints/FoodCart")
	var original: Vector2 = cart.position
	var blocked: Vector2 = original + Vector2(0, -40)
	_check(not player.is_walkable_footprint(blocked), "餐车原位置阻挡玩家")
	cart.position += Vector2(-140, -180)
	_check(player.is_walkable_footprint(blocked), "移动餐车后原位置释放，无旧掩码幽灵碰撞")
	_check(not player.is_walkable_footprint(cart.position + Vector2(0, -40)), "新位置随餐车阻挡")
	player.position = _stand(cart)
	player.last_valid = player.position
	_check(player.nearest_interactable() == cart, "移动餐车后交互位置同步")
	await _capture(_arg("--output-dir="), "cart_moved")
	cart.position = original
	var register = scene.get_node("InteractPoints/Register")
	var before_counter := Layout.counter(get_tree())
	register.position += Vector2(-60, 30)
	_check(Layout.counter(get_tree()).is_equal_approx(before_counter + Vector2(-60, 30)), "前台候客点跟随设施")
	flow._sync()
	var front: Dictionary = sm.restaurant_customers().front
	if not front.is_empty():
		_check(flow.actors[front.id].global_position.is_equal_approx(Layout.counter(get_tree())), "真实普通顾客按移动后前台定位")
		_check(flow.actors[front.id].z_index == -2, "普通顾客始终低于吧台和前台")
	register.position -= Vector2(-60, 30)
	var stool = scene.get_node("InteractPoints/BarCounter/StoolRight")
	var before_seat := Layout.seat(get_tree(), 0)
	stool.position += Vector2(40, -10)
	_check(Layout.seat(get_tree(), 0).is_equal_approx(before_seat + Vector2(40, -10)), "圆凳独立移动带动座位")
	var guest = load("res://scenes/guest_placeholder.tscn").instantiate()
	scene.add_child(guest)
	guest.settle_seated()
	_check(guest.global_position.is_equal_approx(Layout.seat(get_tree(), 0) + Vector2(0, 20)), "铁山落座使用新座位标记")
	_check(guest.z_index == -2 and guest.portrait.material == null, "铁山位于柜台后方且移除旧地图固定遮罩")
	await _capture(_arg("--output-dir="), "seat_moved")
	guest.queue_free()
	stool.position -= Vector2(40, -10)
	# 编辑态保存副本：只序列化场景原有节点和新道具，不把运行时HUD存回游戏。
	var edited = RESTAURANT.instantiate()
	edited.get_node("InteractPoints/FoodCart").position += Vector2(-100, 0)
	edited.get_node("InteractPoints/FoodCart").z_index = 2
	var decor = load("res://scenes/restaurant/props/decoration.tscn").instantiate()
	decor.name = "TestDecoration"
	decor.get_node("Art").texture = load("res://assets/restaurant_layout/stool_left.png")
	decor.get_node("Art").scale = Vector2(0.08, 0.08)
	edited.get_node("Decorations").add_child(decor)
	decor.owner = edited
	edited.set_editable_instance(decor, true)
	decor.position = Vector2(700, 900)
	# 保存为独立场景，使纹理等道具内部覆盖随资源一起持久化。
	var decor_resource := PackedScene.new()
	_check(decor_resource.pack(decor) == OK, "新增道具可封装为独立场景")
	_check(ResourceSaver.save(decor_resource, _arg("--output-dir=").path_join("new_decoration.tscn")) == OK, "新增道具保存成功")
	var packed := PackedScene.new()
	_check(packed.pack(edited) == OK, "布局可序列化")
	var path := _arg("--output-dir=").path_join("edited_layout.tscn")
	_check(ResourceSaver.save(packed, path) == OK, "布局副本保存成功")
	edited.free()
	var reopened = load(path).instantiate()
	_check(reopened.get_node("InteractPoints/FoodCart").position == original + Vector2(-100, 0), "重开布局保留位置")
	_check(reopened.get_node("InteractPoints/FoodCart").z_index == 2, "重开布局保留手动层级")
	_check(reopened.get_node("Decorations/TestDecoration/Art").texture != null, "新增道具图片随布局保存")
	reopened.free()
	var before: Dictionary = sm.data.duplicate(true)
	_check(sm.save(), "布局验收后存档可保存")
	sm.load_data()
	var differences := {}
	for key in before:
		if JSON.parse_string(JSON.stringify(sm.data.get(key))) != JSON.parse_string(JSON.stringify(before[key])):
			differences[key] = {"before": before[key], "after": sm.data.get(key)}
	_check(differences.is_empty(), "经营状态读档保持一致", differences)
	player.position = Vector2(1000, 850)
	player.last_valid = player.position
	var start: Vector2 = player.position
	Input.action_press("ui_left")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("ui_left")
	_check(player.position.x < start.x - 10, "实际方向输入可以移动")
	for spot in [Vector2(773, 530), Vector2(773, 850)]:
		player.position = spot
		player.last_valid = spot
		_check(player.is_walkable_footprint(spot), "料理台前后观察点可站立：" + str(spot))
		await _capture(_arg("--output-dir="), "depth_" + str(int(spot.y)))
	await _capture(_arg("--output-dir="), "layout_final")
	player.set_physics_process(false)
	for prop_name in ["Fridge", "FoodCart", "Cauldron"]:
		var prop = scene.get_node("InteractPoints/" + prop_name)
		var original_points: PackedVector2Array = prop.world_collision_polygon()
		for side in ["left", "right", "front", "back"]:
			var delta := Vector2(-100, -180)
			if side == "right": delta = Vector2(110, -180)
			if side == "front": delta = Vector2(0, 70)
			if side == "back": delta = Vector2(0, -280)
			player.global_position = prop.global_position + delta
			await _capture(_arg("--output-dir="), prop_name + "_" + side)
			_check(prop.get_node("Art").z_index == (-1 if side == "left" else 0), prop_name + side + "遮挡规则")
			_check(prop.world_collision_polygon() == original_points, prop_name + side + "碰撞轮廓未改变")
	player.set_physics_process(true)
	scene.queue_free()
	await get_tree().process_frame
	get_tree().set_meta("restaurant_return_from_maze", true)
	scene = load(path).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	var reloaded_player = scene.get_node("Player")
	_check(reloaded_player.spawn_ready and reloaded_player.position == Vector2(210, 940), "重开实际场景支持迷宫返回出生")
	var reloaded_decor = scene.get_node("Decorations/TestDecoration")
	_check(reloaded_decor.get_node("Art").is_visible_in_tree(), "新增道具在重开运行场景中可见")
	_check(not reloaded_decor.is_in_group("interactable"), "新增普通装饰不冒用设施业务")
	var reload_camera = scene.get_node("Camera")
	reload_camera.paused = true
	reload_camera.position = Vector2(724, 543)
	reload_camera.zoom = Vector2(0.64, 0.64)
	await _capture(_arg("--output-dir="), "saved_layout_reopened")
	scene.queue_free()
	await get_tree().process_frame

func _reach_interaction(target_name: String) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and tm.active:
		var step: Dictionary = tm.steps[tm.idx]
		var kind := str(step.get("type", ""))
		if kind in ["move_to", "interact"]:
			var target = tm.resolve_target(step.get("target", ""))
			var player = scene.get_node("Player")
			player.position = _stand(target)
			player.last_valid = player.position
			if kind == "interact" and step.get("target") == target_name and not player.input_locked:
				return true
		elif kind in ["dialog", "recipe_unlock"]:
			await _send_key(KEY_E)
		await get_tree().create_timer(0.08).timeout
	_check(false, "等待交互失败：" + target_name, {"index": tm.idx, "step": tm.steps[tm.idx] if tm.idx < tm.steps.size() else {}})
	return false

func _first_order_current() -> void:
	await _prepare_scene()
	if not await _reach_interaction("前台"): return
	await _send_key(KEY_E)
	_check(sm.has_active_order(), "真实E在新前台接单")
	if not await _reach_interaction("仓库"): return
	await _send_key(KEY_E)
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	var player = scene.get_node("Player")
	_check(warehouse.visible and player.input_locked, "新仓库打开领取窗并锁定输入")
	await _capture(_arg("--output-dir="), "warehouse")
	await _click(warehouse._cancel_button)
	_check(not warehouse.visible and not player.input_locked, "仓库取消恢复输入")
	await _send_key(KEY_E)
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._salt_slot._icon_button)
	await _click(warehouse._claim_button)
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "新仓库实际领取两种材料")
	_check(not warehouse.visible and not player.input_locked, "领取关闭并恢复输入")
	if not await _reach_interaction("魔法汤锅"): return
	await _send_key(KEY_E)
	var cooking = scene.get_node("HUD/CookingModal")
	_check(cooking.visible and player.input_locked, "新料理台E打开烹饪")
	if cooking._lesson_paused: await _send_key(KEY_E)
	await _capture(_arg("--output-dir="), "cooking_open")
	await _click(cooking._cancel_button)
	_check(not cooking.visible and not player.input_locked, "烹饪开始前取消恢复输入")
	await _send_key(KEY_E)
	if cooking._lesson_paused: await _send_key(KEY_E)
	await _click(cooking._start_button)
	_check(sm.cooking_state().status == "active", "鼠标开始实际料理事务")
	await get_tree().create_timer(0.6).timeout
	await _send_key(KEY_SPACE)
	_check(await _wait_until(func(): return cooking._result_popup.visible, 300), "空格起锅后显示结果")
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, "完成料理持有一份成品")
	_check(await _wait_until(func(): return cooking._result_popup._ready_for_input, 120), "等待结果淡入结束可确认")
	await _capture(_arg("--output-dir="), "cooking_result")
	await _send_key(KEY_E)
	if not await _reach_interaction("吧台"): return
	await _send_key(KEY_E)
	_check(sm.has_first_order_settlement() and sm.current_order().status == "completed", "新吧台E完成首单交付")
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 0 and sm.reputation() > 0, "交付扣成品并结算声望")
	await _capture(_arg("--output-dir="), "first_order_delivered")
	var reputation: int = sm.reputation()
	await _send_key(KEY_E)
	_check(sm.reputation() == reputation, "重复E不重复结算")
	tm._cancel_current_run()
	_check(not player.input_locked, "取消教程演出恢复玩家输入")
	scene.queue_free()
	await get_tree().process_frame
