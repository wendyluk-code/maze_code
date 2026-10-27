extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离存档目录")
	if failures == 0:
		if _arg("--mode=") == "resume":
			sm._active_save_path = "user://chapter-ending-test.json"
			sm.load_data()
			_check(sm.discardable_carried_items().is_empty(), "独立进程恢复：食材与料理已全部丢弃")
			_check(sm.inventory_quantity("wood") == 12 and sm.inventory_quantity("quest_token") == 7, "独立进程恢复：木材与任务物品保留")
			_check(sm.warehouse_snapshot().get("slime_gel") == 5, "独立进程恢复：仓库保留")
		elif _arg("--mode=") == "keys":
			for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
				DisplayServer.window_set_size(resolution)
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _scene_checks()
		else:
			_state_checks()
			if _arg("--mode=") == "flow":
				for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
					DisplayServer.window_set_size(resolution)
					suffix = "_%dx%d" % [resolution.x,resolution.y]
					await _scene_checks()
					await _restaurant_regression()
				await _tutorial_restriction()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("TRASH01 ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _stock() -> void:
	sm.data.inventory = {"rockmane_meat":2,"rock_salt":3,"slime_gel":4,"slime_candy":2,"salt_grilled_rockmane":3,"wood":12,"quest_token":7}
	sm.data.prepared_dishes = {"slime_candy":{"1":1,"2":1,"3":0},"salt_grilled_rockmane":{"1":1,"2":1,"3":1}}
	sm.data.warehouse_stock = {"slime_gel":5,"rock_salt":4}

func _state_checks() -> void:
	_completed()
	_check(sm.ensure_restaurant_customer().success, "生成真实顾客订单")
	var customer_id: String = sm.restaurant_customers().front.id
	_check(sm.accept_restaurant_customer(customer_id).success and sm.advance_restaurant_customer(customer_id, "seating", "waiting").success, "真实接单入座后验证丢弃不取消订单")
	_stock()
	var items: Dictionary = sm.discardable_carried_items()
	_check(items.size() == 5 and not items.has("wood") and not items.has("quest_token"), "白名单只含全部随身食材料理")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm.data.chapter_1_done = false
	var locked: Dictionary = sm.data.duplicate(true)
	_check(sm.discard_carried_food(items).reason == "chapter_locked" and sm.data == locked, "事务层第一章未结束拒绝且不扣物品")
	sm.data = before.duplicate(true)
	sm._active_save_path = "user://missing-directory/failure.json"
	_check(sm.discard_carried_food(items).reason == "save_failed" and sm.data == before, "真实文件写入失败完整回滚")
	sm._active_save_path = path
	_check(sm.discard_carried_food({"rock_salt":1}).reason == "changed" and sm.data == before, "过期确认清单拒绝且不改状态")
	_check(sm.discard_carried_food(items).success, "失败后重试成功原子丢弃")
	_check(sm.discardable_carried_items().is_empty(), "全种类多数量全部清空")
	_check(sm.inventory_quantity("wood") == 12 and sm.inventory_quantity("quest_token") == 7 and sm.data.warehouse_stock == before.warehouse_stock, "非食物与仓库保留")
	for key in ["current_order","restaurant_customers","reputation","gold","first_order_progress","chapter_1_departure"]:
		_check(sm.data.get(key) == before.get(key), "不取消订单不推进交付不返还奖励：" + key)
	_check(sm.prepared_dishes_snapshot().salt_grilled_rockmane == {"1":0,"2":0,"3":0} and sm.prepared_dishes_snapshot().slime_candy == {"1":0,"2":0,"3":0}, "全部料理星级余额清零")
	before = sm.data.duplicate(true)
	_check(sm.discard_carried_food(items).reason == "empty" and sm.data == before, "重复确认不重复扣除")
	sm.load_data()
	_check(sm.discardable_carried_items().is_empty(), "重新加载不恢复已丢弃成品")

func _key(key: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	event.echo = echo
	get_viewport().push_input(event)
	await get_tree().process_frame
	if not echo:
		event = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = false
		get_viewport().push_input(event)
		await get_tree().process_frame

func _scene_checks() -> void:
	_completed()
	_stock()
	sm.ensure_restaurant_customer()
	await _open_scene()
	await get_tree().create_timer(0.5).timeout
	var player = scene.get_node("Player")
	var trash = scene.get_node("InteractPoints/TrashBin")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.discard_flow
	var modal = flow.confirmation
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	await get_tree().create_timer(0.8).timeout
	_check(player.is_walkable_footprint(player.global_position) and player.nearest_interactable() == trash, "垃圾桶右侧可站立且为最近目标")
	var button: Control = ui._buttons[trash]
	_check(button.visible and button.scene_file_path == "res://scenes/ui/interact_button.tscn" and button.get_node("Content/KeyIcon/KeyIcon/KeyLabel").text == "E", "复用原交互按钮显示E丢弃")
	await _shot("bin_near")
	await _key(KEY_B)
	_check(not modal.visible, "B不触发丢弃")
	await _key(KEY_E)
	_check(modal.visible and player.input_locked and not player.is_physics_processing() and modal.cancel_button.has_focus(), "E打开确认并默认取消、锁定输入")
	_check(modal.item_list.text.contains("岩鬃肉 × 2") and modal.item_list.text.contains("史莱姆糖块 × 2") and not modal.item_list.text.contains("wood"), "名称数量准确且排除非食物")
	await _shot("confirm")
	var before: Dictionary = sm.data.duplicate(true)
	await _key(KEY_E)
	await _key(KEY_E)
	await _key(KEY_E, true)
	_check(modal.visible and sm.data == before, "确认框E与长按E不扣物品")
	await _key(KEY_ENTER)
	_check(not modal.visible and sm.data == before and not player.input_locked, "默认Enter取消且恢复输入")
	await _click(button)
	_check(modal.visible, "真实鼠标打开确认")
	await _key(KEY_ESCAPE)
	_check(not modal.visible and sm.data == before and player.is_physics_processing(), "Esc不改库存且恢复物理输入")
	await _key(KEY_E)
	await _click(modal.cancel_button)
	_check(not modal.visible and sm.data == before, "取消按钮不改库存")
	await _key(KEY_E)
	var path: String = sm._active_save_path
	sm._active_save_path = "user://missing-directory/failure.json"
	await _click(modal.confirm_button)
	_check(modal.visible and sm.data == before and hud.toast_label.text.contains("保存失败"), "界面保存失败留框且全量回滚")
	await _shot("save_failed")
	sm._active_save_path = path
	await _click(modal.confirm_button)
	await get_tree().process_frame
	_check(not modal.visible and sm.discardable_carried_items().is_empty() and hud.toast_label.text == "已丢弃", "确认成功只扣一次并提示")
	_check(player.get_node("CarriedMaterialIcons").get_child_count() == 0 and not player.input_locked, "成功后携物图标清空、恢复输入")
	await _shot("discarded")
	await _key(KEY_E)
	_check(not modal.visible and hud.toast_label.text == "没有可丢弃的食材或料理", "空手提示且不弹确认")
	for id in sm.RecipeCatalog.INGREDIENTS:
		sm.data.inventory[id] = 999
	for id in sm.RecipeCatalog.RECIPES:
		sm.data.inventory[id] = 999
	await _key(KEY_E)
	await get_tree().process_frame
	_check(modal.item_scroll.get_v_scroll_bar().visible and get_viewport().get_visible_rect().encloses(modal.confirm_button.get_global_rect()), "全食材料理长清单可滚动且确认按钮完整可见")
	await _shot("all_food_scroll")
	await _key(KEY_ESCAPE)
	player.global_position = Vector2(290,545)
	player.last_valid = player.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.nearest_interactable() != trash and not button.visible, "相邻冰柜更近时垃圾桶按钮隐藏")
	await _key(KEY_B)
	_check(not modal.visible, "B不能越过最近目标触发垃圾桶")
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	_stock()
	sm.data.chapter_1_done = false
	await _key(KEY_E)
	_check(not modal.visible and hud.toast_label.text == "请先完成当前任务", "章末前准确限制文案且桶可见")
	sm.data.chapter_1_done = true
	# 碰撞使用真实物理移动；右侧抵住桶后还能向下沿通道行走。
	Input.action_press("ui_left")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("ui_left")
	_check(player.global_position.x >= 250 and player.global_position.x < 290, "实际向左行走被桶碰撞挡住")
	Input.action_press("ui_down")
	await get_tree().create_timer(0.35).timeout
	Input.action_release("ui_down")
	_check(player.global_position.y > 600, "桶下方通道可通过")
	player.global_position = Vector2(600,850)
	player.last_valid = player.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await _key(KEY_E)
	_check(not button.visible and not modal.visible, "离开隐藏且远处E无效")
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	player.input_locked = true
	await _key(KEY_E)
	_check(not modal.visible, "对话过场输入锁期间不能触发")
	player.input_locked = false
	player.set_physics_process(false)
	await _key(KEY_E)
	_check(not modal.visible, "其他窗口物理暂停期间不能触发")
	player.set_physics_process(true)
	await _close_scene()

func _restaurant_regression() -> void:
	_completed()
	sm.data.ch2_guide_01 = {"step":"done","revision":2,"seen":{},"banked":{}}
	sm.data.inventory = {"wood":12}
	sm.data.warehouse_stock = {}
	for id in sm.RecipeCatalog.INGREDIENTS:
		sm.data.warehouse_stock[id] = 5
	sm.ensure_restaurant_customer()
	await _open_scene()
	await get_tree().create_timer(0.4).timeout
	var player = scene.get_node("Player")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.customer_flow
	var modal = hud.discard_flow.confirmation
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	player.last_valid = player.global_position
	await _key(KEY_E)
	await get_tree().process_frame
	_check(flow._dialog.visible, "回归：E打开前台接单对白")
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	await _key(KEY_E)
	_check(not modal.visible and player.input_locked, "真实接单对白中E不能触发垃圾桶")
	for index in range(2):
		if flow._dialog.visible: await _key(KEY_E)
	await get_tree().create_timer(1.0).timeout
	_check(sm.customer_orders_active().size() == 1 and not player.input_locked, "回归：接单入座恢复输入")
	var order: Dictionary = sm.customer_orders_active()[0]
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	player.last_valid = player.global_position
	await _key(KEY_E)
	var warehouse = get_tree().get_first_node_in_group("warehouse_modal")
	_check(warehouse.visible, "回归：E打开仓库")
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	await _key(KEY_E)
	_check(not modal.visible and warehouse.visible, "真实仓库窗口中E不触发垃圾桶")
	for id in recipe.ingredients:
		await _click(warehouse._slot_by_id[id]._icon_button)
	await _click(warehouse._claim_button)
	_check(sm.carried_ingredients() == recipe.ingredients and not player.input_locked, "回归：鼠标选料领取与输入恢复")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.global_position
	await _key(KEY_E)
	var cooking = get_tree().get_first_node_in_group("cooking_modal")
	_check(cooking.visible, "回归：E打开烹饪")
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	await _key(KEY_E)
	_check(not modal.visible and cooking.visible, "真实烹饪窗口中E不触发垃圾桶")
	await _click(cooking._start_button)
	await get_tree().create_timer(0.8).timeout
	await _key(KEY_SPACE)
	await get_tree().create_timer(0.8).timeout
	_check(sm.inventory_quantity(order.item_id) == 1 and sm.carried_ingredients().is_empty(), "回归：真实开始/结束烹饪扣料产生成品")
	await _shot("regression_cooked")
	await _key(KEY_E)
	await _key(KEY_ENTER)
	_check(not cooking.visible and not player.input_locked, "回归：关闭料理结果恢复输入")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	await _key(KEY_E)
	_check(sm.restaurant_customer_order(order.id).phase == "eating" and sm.inventory_quantity(order.item_id) == 0, "回归：E在吧台上菜消耗成品并结算")
	await _shot("regression_served")
	await _close_scene()

func _tutorial_restriction() -> void:
	await _prepare_scene()
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	for index in range(40):
		if tm.steps[tm.idx].get("type") == "move_to" and tm.steps[tm.idx].get("target") == "前台": break
		if guide.dialog.visible: await _key(KEY_E)
		await get_tree().create_timer(0.05).timeout
	_check(tm.steps[tm.idx].get("type") == "move_to" and tm.steps[tm.idx].get("target") == "前台", "真实对白输入进入前台移动教程")
	var player = scene.get_node("Player")
	player.global_position = Vector2(260,545)
	player.last_valid = player.global_position
	await get_tree().create_timer(0.6).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var before: Dictionary = sm.data.duplicate(true)
	await _key(KEY_E)
	_check(tm.active and not hud.discard_flow.confirmation.visible and guide.toast.text == "请先完成当前任务" and not hud.toast_label.visible and sm.data == before, "真实第一章移动教程：E准确提示且不推进任务、不叠提示")
	await _shot("chapter_locked")
	await _close_scene()
