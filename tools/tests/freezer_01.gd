extends "res://tools/tests/ch2_entry_state.gd"
const F := preload("res://scripts/restaurant/freezer_store.gd")

func _completed() -> void:
	super._completed()
	# 冰柜经营回归从新解锁条件之后开始；剧情解锁另有独立场景验收。
	_check(sm.set_yufeng_salia_state("done").success, "御风剧情完成前置")
	_check(sm.acknowledge_freezer_notice(), "已读冰柜解锁提示前置")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		if _arg("--phase=") == "prepare":
			_cross_prepare()
		elif _arg("--phase=") == "resume":
			_cross_resume()
		else:
			_state_checks()
			for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
				DisplayServer.window_set_size(resolution)
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _freezer_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "results":results}, "\t"))
	print("FREEZER_01 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _cross_prepare() -> void:
	_completed()
	sm._active_save_path = "user://freezer-cross.json"
	_fresh(sm.FIRST_ORDER_ITEM_ID, 2)
	_check(sm.freezer_action("store",0,sm.FIRST_ORDER_ITEM_ID,2).success, "跨进程预备实际入柜")
	sm.data[F.KEY].stored[0].expires_at = int(Time.get_unix_time_from_system()) + 3
	_check(sm.save(), "保存即将到期批次后退出进程")

func _cross_resume() -> void:
	sm._active_save_path = "user://freezer-cross.json"
	sm.load_data()
	var ledger: Dictionary = sm.freezer_snapshot()
	_check(ledger.stored.size() == 1 and ledger.stored[0].quality == 2, "独立进程重载保留同一料理与星级")
	_check(int(ledger.stored[0].expires_at) <= int(Time.get_unix_time_from_system()), "游戏进程未运行期间仍然到期")
	_check(sm.freezer_action("withdraw",int(ledger.stored[0].id)).get("reason") == "expired", "重进拒绝取出已腐坏料理")

func _fresh(id: String, quality := 3) -> void:
	var prepared: Dictionary = sm.prepared_dishes_snapshot()
	sm.data.inventory[id] = sm.inventory_quantity(id) + 1
	prepared[id][str(quality)] += 1
	sm.data.prepared_dishes = prepared

func _state_checks() -> void:
	_completed()
	var id: String = sm.FIRST_ORDER_ITEM_ID
	var now := int(Time.get_unix_time_from_system())
	_fresh(id, 3)
	_check(sm.freezer_snapshot().stored.is_empty() and sm.dish_quality(id) == 3, "旧料理不凭空开始保鲜")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not sm.freezer_action("store", 0, id, 3).success and sm.data == before, "存入写盘失败完整回滚")
	sm._active_save_path = path
	_check(sm.freezer_action("store", 0, id, 3).success and sm.inventory_quantity(id) == 0, "存入从携带库存扣除一份")
	var unit: Dictionary = sm.freezer_snapshot().stored[0]
	_check(abs(int(unit.expires_at) - now - F.LIFETIME) <= 3 and unit.quality == 3, "首次入柜七天且保留星级")
	_check(not sm.freezer_action("store", 0, id, 3).success, "重复存入不能复制料理")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.freezer_action("withdraw", int(unit.id)).success and sm.data == before, "取出写盘失败完整回滚")
	_check(not sm.freezer_action("discard", int(unit.id)).success and sm.data == before, "丢弃写盘失败完整回滚")
	sm._active_save_path = path
	_check(sm.freezer_action("withdraw", int(unit.id)).success and sm.inventory_quantity(id) == 1, "取出恢复携带成品")
	_check(not sm.start_cooking(id).success, "有成品时不能再做一份")
	_check(sm.freezer_action("store", int(unit.id), id, 3).success and sm.freezer_snapshot().stored[0].expires_at == unit.expires_at, "取出再存绝不重置截止时间")
	sm.load_data()
	_check(sm.freezer_snapshot().stored[0].expires_at == unit.expires_at, "重载保存批次截止时间")
	sm.data[F.KEY].stored[0].expires_at = now - 1
	sm.save()
	sm.load_data()
	_check(not sm.freezer_action("withdraw", int(unit.id)).success and sm.freezer_snapshot().stored.size() == 1, "离线经过截止时间后保留腐坏料理且不能取出")
	_check(sm.freezer_action("discard", int(unit.id)).success and sm.freezer_snapshot().stored.is_empty(), "腐坏料理可丢弃")
	_check(not sm.freezer_action("discard", int(unit.id)).success, "重复丢弃不改变其他料理")
	for i in 20:
		_fresh(id, 1 + i % 3)
		_check(sm.freezer_action("store", 0, id, 1 + i % 3).success, "逐份入柜容量 %d" % (i+1))
	_fresh(id)
	before = sm.data.duplicate(true)
	_check(not sm.freezer_action("store", 0, id, 3).success and sm.data == before, "第21份拒绝且不丢食物")
	_check(not sm.freezer_action("withdraw", int(sm.freezer_snapshot().stored[0].id)).success, "已有成品不能取第二份")
	_check(sm.discard_carried_food(sm.discardable_carried_items()).success, "旧垃圾桶可处理携带成品")
	_check(sm.freezer_snapshot().stored.size() == 20, "旧垃圾桶不影响冷藏库存")
	sm.data[F.KEY] = F.empty()
	_fresh(id, 2)
	_fresh(id, 3)
	_check(sm.freezer_carried_options().size() == 2 and sm.carried_dish_count() == 2, "旧档多份多星成品保留")
	_check(sm.freezer_action("store", 0, id, 2).success and sm.freezer_action("store", 0, id, 3).success, "旧档可逐份整理")
	unit = sm.freezer_snapshot().stored[1]
	_check(sm.freezer_action("withdraw", int(unit.id)).success, "高星取出")
	sm.data[F.KEY].carried[0].expires_at = now
	_check(sm.dish_quality(id) == 0, "截止时间等于当前时间已不可交单")
	_check(not sm.freezer_action("store", int(unit.id), id, 3).success, "腐坏携带料理不可重存")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.freezer_action("discard_carried", int(unit.id), id, 3).success and sm.data == before, "携带腐坏丢弃写盘失败回滚")
	sm._active_save_path = path
	_check(sm.discard_carried_food(sm.discardable_carried_items()).success and sm.freezer_snapshot().carried.is_empty(), "旧丢弃流程同步移除保鲜账本")
	var ledger: Dictionary = sm.freezer_snapshot()
	for malformed in [null, {}, {"version":2}, {"version":1,"next_id":1,"stored":{},"carried":[]}]:
		sm.data[F.KEY] = malformed
		before = sm.data.duplicate(true)
		_check(not sm.freezer_valid() and not sm.freezer_action("store",0,id,3).success and sm.data == before, "损坏冷藏记录拒绝且不覆盖原值")
	sm.data[F.KEY] = ledger
	var duplicate: Dictionary = ledger.duplicate(true)
	duplicate.stored.append(duplicate.stored[0].duplicate(true))
	_check(not F.valid(duplicate, sm.prepared_dishes_snapshot()), "重复批次编号拒绝")
	_completed()
	# 无顾客也可按真实配方扣料制作并中断恢复。
	sm.data.inventory["rockmane_meat"] = 1
	sm.data.inventory["rock_salt"] = 1
	_check(sm.start_cooking(id).success, "章后没有订单也能备餐")
	sm.load_data()
	_check(sm.inventory_quantity(id) == 1 and sm.cooking_state().status == "idle", "备餐中断恢复只产出一份")
	_check(sm.freezer_carried_options()[0].expires_at == 0, "刚烹饪完成无限保鲜")
	# 同星级的过期份不能挤占可用鲜品；每个截止时间独立保留。
	sm.freezer_action("store", 0, id, 1)
	unit = sm.freezer_snapshot().stored[0]
	sm.freezer_action("withdraw", int(unit.id))
	sm.data[F.KEY].carried[0].expires_at = now - 1
	_fresh(id, 1)
	_check(sm.dish_quality(id) == 1 and sm.freezer_carried_options().size() == 2, "同星级腐坏份与未冷藏份分开辨认")
	_check(sm.freezer_action("store", 0, id, 1).success and sm.carried_dish_count() == 1 and sm.dish_quality(id) == 0, "仅存入未冷藏份，不移动同星级腐坏份")
	before = sm.data.duplicate(true)
	sm.freezer_snapshot()
	sm.freezer_carried_options()
	sm.dish_quality(id)
	_check(sm.data == before, "显示和查询不写入或更改状态")

func _freezer_flow() -> void:
	_completed()
	sm.record_customer_walk(2.0)
	_check(sm.ensure_restaurant_customer().success, "首次行走后生成顾客")
	var order: Dictionary = sm.restaurant_customers().front
	_check(sm.accept_restaurant_customer(order.id).success, "真实接单")
	sm.data["ch2_guide_01"] = {"revision":2,"step":"done","seen":{},"banked":{}}
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
	sm.data.warehouse_stock = recipe.ingredients.duplicate()
	_check(sm.take_warehouse_items(recipe.ingredients).success, "真实配方取料")
	await _open_scene()
	await get_tree().create_timer(0.9).timeout
	var player = scene.get_node("Player")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.freezer.visible, "远处冰柜默认关闭")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	var cooking = get_tree().get_first_node_in_group("cooking_modal")
	_check(cooking.visible, "真实E打开料理台")
	if cooking._lesson_paused: await _send_key(KEY_E)
	await _click(cooking._start_button)
	await get_tree().create_timer(5.9).timeout
	_check(sm.inventory_quantity(order.item_id) == 1, "真实烹饪生成料理")
	for i in 4:
		if not cooking.visible: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	_check(not player.input_locked, "料理确认后恢复输入")
	player.global_position = _stand(scene.get_node("InteractPoints/Fridge"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	var freezer = hud.freezer
	_check(freezer.visible and player.input_locked, "实际靠近冰柜E打开并锁定玩家")
	await _shot("01_empty_and_held")
	await _click(freezer.held.get_node("StoreDish"))
	_check(sm.freezer_snapshot().stored.size() == 1 and sm.inventory_quantity(order.item_id) == 0, "真实存入按钮移动料理")
	await _shot("02_stored")
	var unit: Dictionary = sm.freezer_snapshot().stored[0]
	await _click(freezer.batches.find_child("Discard_%d" % int(unit.id), true, false))
	_check(freezer.confirmation.visible, "垃圾桶打开二次确认")
	await _send_key(KEY_ESCAPE)
	_check(not freezer.confirmation.visible and freezer.visible and player.input_locked and sm.freezer_snapshot().stored.size() == 1, "取消只关闭确认且保留冰柜输入锁")
	await _click(freezer.batches.find_child("Withdraw_%d" % int(unit.id), true, false))
	_check(sm.inventory_quantity(order.item_id) == 1, "详情取出图标恢复成品")
	await _send_key(KEY_ESCAPE)
	_check(not freezer.visible and not player.input_locked, "Esc关闭恢复输入")
	sm.save()
	sm.load_data()
	_check(sm.freezer_snapshot().carried[0].expires_at == unit.expires_at, "取出后重进保留期限")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _send_key(KEY_E)
	_check(sm.inventory_quantity(order.item_id) == 1 and sm.freezer_snapshot().carried.size() == 1 and sm.gold_balance() == before.gold, "冷藏料理交单保存失败保留料理和期限且不发奖励")
	sm._active_save_path = path
	sm.data[F.KEY].carried[0].expires_at = int(Time.get_unix_time_from_system()) - 1
	await _send_key(KEY_E)
	_check(sm.inventory_quantity(order.item_id) == 1 and sm.gold_balance() == before.gold, "实际吧台拒绝腐坏料理且不发奖励")
	sm.data[F.KEY].carried[0].expires_at = unit.expires_at
	await _send_key(KEY_E)
	_check(sm.inventory_quantity(order.item_id) == 0 and sm.freezer_snapshot().carried.is_empty() and sm.gold_balance() > before.gold, "冷藏取出后真实吧台交单成功并消费账本")
	await _shot("03_delivered")
	# 真实存入事务创建多个独立批次；仅截止时间由夹具模拟时间经过。
	for id in sm.RecipeCatalog.RECIPES:
		for i in (6 if id == order.item_id else 1):
			_fresh(id, i % 3 + 1)
			sm.freezer_action("store", 0, id, i % 3 + 1)
	var now := int(Time.get_unix_time_from_system())
	sm.data[F.KEY].stored[0].expires_at = now - 10
	sm.data[F.KEY].stored[1].expires_at = now + 3600
	sm.save()
	player.global_position = _stand(scene.get_node("InteractPoints/Fridge"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	freezer.selected = order.item_id
	freezer._refresh()
	await _shot("04_batches_all")
	_check(freezer.left_scroll.get_v_scroll_bar().visible and freezer.right_scroll.get_v_scroll_bar().visible, "两栏使用独立可见滚动条")
	_check(freezer.panel.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y and freezer.held.get_global_rect().end.y <= freezer.panel.get_global_rect().end.y, "双分辨率主体与固定存入区未溢出")
	freezer.right_scroll.scroll_vertical = 180
	await get_tree().process_frame
	_check(freezer.right_scroll.scroll_vertical > 0 and freezer.left_scroll.scroll_vertical == 0, "右侧多批次可独立滚动")
	freezer.left_scroll.scroll_vertical = 30
	await get_tree().process_frame
	var left_bar: VScrollBar = freezer.left_scroll.get_v_scroll_bar()
	_check((freezer.left_scroll.scroll_vertical > 0 if left_bar.max_value > left_bar.page else freezer.left_scroll.scroll_vertical == 0) and freezer.right_scroll.scroll_vertical > 0, "左侧有溢出时独立滚动，无溢出时保持完整可见")
	await _shot("05_batches_scroll")
	await _tab(freezer.tabs, 1)
	_check(freezer.batches.get_child_count() == 1, "临近到期只包含24小时内未腐坏料理")
	await _shot("06_near_expiry")
	await _tab(freezer.tabs, 2)
	_check(freezer.batches.get_child_count() == 1 and freezer.batches.find_children("Withdraw_*", "Button", true, false).is_empty(), "腐坏卡片只有垃圾桶")
	await _shot("07_expired")
	var trash = freezer.batches.find_children("Discard_*", "Button", true, false)[0]
	var stored_before_discard: int = sm.freezer_snapshot().stored.size()
	await _click(trash)
	await _shot("08_discard_confirmation")
	await _click(freezer.confirmation.confirm_button)
	_check(sm.freezer_snapshot().stored.size() == stored_before_discard - 1, "确认丢弃仅扣所选一份")
	await _send_key(KEY_ESCAPE)
	_check(not player.input_locked and player.is_physics_processing(), "丢弃完成关闭恢复物理移动")
	player.global_position = player.walk_zone.get_spawn_point(player.collision_radius_world())
	player.last_valid = player.global_position
	var position_before: Vector2 = player.global_position
	Input.action_press("ui_right")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("ui_right")
	_check(player.global_position.distance_to(position_before) > 1.0, "关闭后实际方向输入移动主角")
	await _send_key(KEY_E)
	_check(not freezer.visible, "远离冰柜按E不会误开")
	# 页面不关闭时跨过真实截止秒数，按钮与筛选会同步更新。
	player.global_position = _stand(scene.get_node("InteractPoints/Fridge"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	await _tab(freezer.tabs, 0)
	var deadline_unit: Dictionary = sm.data[F.KEY].stored[0]
	deadline_unit.expires_at = int(Time.get_unix_time_from_system()) + 2
	freezer.selected = deadline_unit.recipe_id
	freezer._refresh()
	get_tree().paused = true
	await get_tree().create_timer(2.5, true).timeout
	get_tree().paused = false
	await get_tree().create_timer(1.1).timeout
	_check(freezer.batches.find_child("Withdraw_%d" % int(deadline_unit.id), true, false) == null, "暂停也计时，恢复后过期卡片撤下取出按钮")
	await _shot("09_live_expiry")
	freezer.dismiss()
	await _close_scene()

func _tab(tabs: TabBar, index: int) -> void:
	var point := tabs.global_position + tabs.get_tab_rect(index).get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame

