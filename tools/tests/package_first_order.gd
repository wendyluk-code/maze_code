extends "res://tools/tests/cooking_countdown_input.gd"
## 对照用户卡住的存档阶段，用真实输入验证领取、取消、读档、烹饪、交付。

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			case_label = str(resolution.x)
			await _warehouse_to_delivery()
		await _cleanup()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("PACKAGE_FIRST_ORDER ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _load_saved_restaurant() -> void:
	await _cleanup()
	sm.load_data()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.3).timeout
	tm.start()
	await get_tree().process_frame
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	if hud._recipe_unlock.visible:
		await _send_key(KEY_E)
		await get_tree().create_timer(0.6).timeout
		_check(not hud._recipe_unlock.visible, "E确认菜谱解锁演出")
	var player = scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	player.last_valid = player.global_position
	await get_tree().physics_frame
	await get_tree().create_timer(0.15).timeout

func _warehouse_to_delivery() -> void:
	await _cleanup()
	sm.data = sm._defaults()
	sm._active_save_path = "user://package-first-order.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success, "建立已接首单真实存档")
	await _load_saved_restaurant()
	var player = scene.get_node("Player")
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	_check(tm.current_stage == 4 and not player.input_locked, "恢复截图中的领取食材阶段")
	await _send_key(KEY_E)
	_check(warehouse.visible and warehouse._open and player.input_locked, "仓库E打开并锁定背景")
	if not warehouse.visible:
		return
	await _capture(evidence, "warehouse_open_" + case_label)
	await _send_key(KEY_ESCAPE)
	_check(not warehouse.visible and not player.input_locked and not sm.first_order_progress().ingredients_claimed, "Esc取消不领料且恢复输入")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	await get_tree().process_frame
	await _click(ui._buttons[scene.get_node("InteractPoints/Store")])
	_check(warehouse.visible, "点击场景交互按钮同样打开仓库")
	await _click(warehouse._cancel_button)
	_check(not warehouse.visible and not player.input_locked, "鼠标取消恢复输入")
	_check(sm.save(), "保存未领取阶段")
	await _load_saved_restaurant()
	player = scene.get_node("Player")
	warehouse = scene.get_node("UIOverlay/WarehouseModal")
	await _send_key(KEY_E)
	_check(warehouse.visible and not sm.first_order_progress().ingredients_claimed, "重进未领取阶段仍可E打开")
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._salt_slot._icon_button)
	_check(not warehouse._claim_button.disabled, "选齐两种材料启用取出")
	await _click(warehouse._claim_button)
	_check(not warehouse.visible and not player.input_locked and sm.first_order_progress().ingredients_claimed, "真实鼠标领取成功并释放输入")
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "两种食材各到账一份")
	await _load_saved_restaurant()
	player = scene.get_node("Player")
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.lifecycle_stage() == "ingredients_collected", "读档保留材料且不重复领取")
	var modal = await _open_cooking()
	_check(modal.visible and player.input_locked, "E打开料理台与教学")
	await _send_key(KEY_E)
	_check(not modal._lesson_paused and not modal._started, "E关闭教学不透传开始")
	await _click(modal._cancel_button)
	_check(not modal.visible and not player.input_locked, "烹饪前取消恢复输入并保留材料")
	modal = await _open_cooking()
	await _click(modal._start_button)
	_check(modal._started, "鼠标开始真实烹饪")
	await _finish_click(modal)
	_check(await _wait_seconds(func(): return modal._result_popup.visible, 4.0), "完成料理显示确认结果")
	await get_tree().create_timer(0.35).timeout
	await _click(modal._result_popup._confirm_button)
	_check(not modal.visible and not player.input_locked and sm.lifecycle_stage() == "dish_ready", "确认料理后恢复输入并持有成品")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	_check(sm.has_first_order_settlement(), "吧台E完成真实交单")
	await _capture(evidence, "delivered_" + case_label)
	sm.load_data()
	_check(sm.has_first_order_settlement(), "重载保留交单凭证")

func _open_cooking() -> Control:
	var player = scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.global_position
	# 正式移动步骤先通过物理帧完成，再触发交互，避免在 move_to 中过早投递 E。
	await get_tree().create_timer(0.3).timeout
	await _send_key(KEY_E)
	return scene.get_node("HUD/CookingModal")
