extends "res://tools/tests/ch1_qte_03_input.gd"

const EXPLANATION := "订单制作会分成【领取食材】和【制作料理】两部分，先去仓库领取食材吧。"

## CH1-ORDER-EXPLAIN：接单后真实对白、高亮和仓库衔接验收。
## 通过真实 InputEventKey/MouseButton 驱动，不直接 emit pressed。
func _run() -> void:
	var output_dir := _arg("--output-dir=")
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "测试存档目录隔离")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			await _run_explain(resolution, output_dir)
		await _run_skip_cleanup(output_dir)
		await _run_leave_cleanup()
		await _run_same_instance()
	var engine_log := _arg("--engine-log=")
	if not engine_log.is_empty():
		var log_text := FileAccess.get_file_as_string(engine_log)
		_check(not log_text.contains("ERROR:") and not log_text.contains("SCRIPT ERROR:"), "引擎日志无运行错误", {"log": engine_log})
	var report := {"ticket": "CH1-ORDER-EXPLAIN", "checks": checks, "failures": failures,
		"results": results, "user_dir": ProjectSettings.globalize_path("user://"), "display": DisplayServer.get_name()}
	var report_path := _arg("--report=")
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _run_explain(resolution: Vector2i, output_dir: String) -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	_check(DisplayServer.window_get_size() == resolution and get_viewport().get_visible_rect().size == Vector2(resolution), "实际窗口与视口尺寸匹配", {"size": str(resolution)})
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	_check(await _wait_until(func(): return _is_stage_type(3, "interact"), 240), "到达前台接单步骤")
	await _send_key(KEY_E)
	_check(sm.current_order().get("status") == "in_progress", "真实E成功接单")
	_check(await _wait_until(func(): return _is_order_explanation(), 60), "接单后进入芽芽说明对白")
	_check(tracker.get("_expanded") and tracker.get("_explanation_highlight"), "说明期间任务展开且两块子任务高亮")
	_check(not guide.toast.visible, "接单后不显示已接到订单toast")
	_check(guide.dialog.visible and guide.dialog.get("speaker_name").text == "芽芽", "对白显示芽芽姓名与对话框")
	_check(guide.dialog.get("dialog_text").text.length() < EXPLANATION.length(), "接单E不会跳过新对白的逐字显示")
	_check(guide.dialog.get("portrait_texture").texture.resource_path == "res://assets/characters/yaya_portrait.png", "复用芽芽头像")
	_check(player.input_locked, "对白期间锁定玩家输入")
	var panel: Control = tracker.get("_panel")
	var ingredients: Control = tracker.get("_subtask_panels")[0]
	var cooking: Control = tracker.get("_subtask_panels")[1]
	_check(panel.get_child(0).get_child(0).get_theme_stylebox("panel").border_color == Color("#987039"), "主任务块不高亮")
	_check(ingredients.get_theme_stylebox("panel").border_color == Color("#4c83ff") and cooking.get_theme_stylebox("panel").border_color == Color("#4c83ff"), "领取食材和制作料理边框蓝色高亮")
	_check(panel.size.x == 260.0 and ingredients.size.x > 0 and cooking.size.x > 0, "高亮不改变面板布局")
	await get_tree().create_timer(0.04).timeout
	await RenderingServer.frame_post_draw
	_check(panel.modulate.a > 0.0 and panel.modulate.a < 1.0 and panel.position.y > 56 and panel.position.y < 66, "保留接单展开动画中间态", {"alpha": panel.modulate.a, "y": panel.position.y})
	await _capture(output_dir, "explain_middle_%dx%d" % [resolution.x, resolution.y])
	var order_before: Dictionary = sm.current_order().duplicate(true)
	var receipt_tween: Tween = tracker.get("_expand_tween")
	tracker.show_order_receipt(sm.current_order())
	_check(tracker.get("_expand_tween") == receipt_tween and _is_order_explanation(), "重复回执不重启动画或对白")
	await _click(tracker.get("_task_button"))
	_check(tracker.get("_expanded") and _is_order_explanation(), "说明期间点击当前任务保持展开且不推进对白")
	await _send_key(KEY_E)
	await get_tree().process_frame
	_check(guide.dialog.visible and sm.current_order() == order_before, "重复E仅补全对白，不重复接单")
	_check(guide.dialog.get("dialog_text").text == EXPLANATION, "芽芽台词逐字准确")
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_check(panel.modulate.a == 1 and panel.position.y == 66 and guide.dim.visible, "最终面板与既有对白遮罩并存")
	await _capture(output_dir, "explain_dialog_%dx%d" % [resolution.x, resolution.y])
	var sizes := [panel.size, ingredients.size, cooking.size]
	# 站到仓库但不修改教程：对白完成的同一E不得穿透打开仓库。
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return not guide.dialog.visible and int(tm.current_stage) == 4, 90), "对白完成后恢复仓库阶段")
	_check(not tracker.get("_explanation_highlight") and not player.input_locked, "对白完成清除高亮并恢复输入")
	_check("仓库" in guide.hint_label.text and not guide.dim.visible, "对白完成恢复仓库指引并关闭遮罩")
	_check(not scene.get_node("UIOverlay/WarehouseModal").visible, "完成对白的E不穿透打开仓库")
	_check(sizes == [panel.size, ingredients.size, cooking.size], "撤销高亮前后布局尺寸完全一致")
	await _capture(output_dir, "explain_final_%dx%d" % [resolution.x, resolution.y])
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	_check(await _wait_until(func(): return _is_stage_type(4, "interact"), 240), "移动到仓库阶段")
	await _send_key(KEY_E)
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	_check(await _wait_until(func(): return warehouse.visible, 60), "对白后真实E打开仓库")
	await _click(warehouse.get("_meat_slot").get("_icon_button"))
	await _click(warehouse.get("_salt_slot").get("_icon_button"))
	await _click(warehouse.get("_claim_button"))
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "对白后真实领取食材成功")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _run_skip_cleanup(output_dir: String) -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	_check(await _wait_until(func(): return _is_stage_type(3, "interact"), 240), "跳过场景到达接单步骤")
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return _is_order_explanation(), 60), "跳过场景进入说明")
	await _click(guide.get("skip_button"))
	await get_tree().process_frame
	_check(not tm.active and not guide.visible and not guide.dialog.visible, "跳过说明关闭教程遮罩")
	_check(not tracker.get("_explanation_highlight") and not player.input_locked and player.is_physics_processing(), "跳过说明清理高亮与玩家锁")
	await _reload_accepted_scene()

func _run_leave_cleanup() -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	await _wait_until(func(): return _is_stage_type(3, "interact"), 240)
	await _send_key(KEY_E)
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	_check(_is_order_explanation(), "离树场景处于接单说明")
	get_tree().root.remove_child(scene)
	_check(not tm.active and not tracker.get("_explanation_highlight") and not player.input_locked and not guide.dim.visible, "对白中离树立即清理锁、高亮、遮罩")
	scene.free()
	await _reload_accepted_scene()

func _reload_accepted_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await get_tree().process_frame
	sm.load_data()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var player := scene.get_node("Player")
	_check(int(tm.current_stage) == 4 and not guide.dialog.visible and not tracker.get("_explanation_highlight"), "已接单重进恢复仓库、不重复说明")
	_check(not player.input_locked and not guide.dim.visible and not tracker.get("_expanded"), "重进无输入锁、遮罩或旧动画")
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	await _wait_until(func(): return _is_stage_type(4, "interact"), 240)
	await _send_key(KEY_E)
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	_check(warehouse.visible, "重进后仍可E打开必要仓库领取")
	await _click(warehouse.get("_meat_slot").get("_icon_button"))
	await _click(warehouse.get("_salt_slot").get("_icon_button"))
	await _click(warehouse.get("_claim_button"))
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "重进未跳过必要领取事务")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _run_same_instance() -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	await _wait_until(func(): return _is_stage_type(3, "interact"), 240)
	await _send_key(KEY_E)
	tm._cancel_current_run()
	tracker.collapse_details()
	# 同组件保留已知订单ID，以独立夹具重置到合法接单前状态，复现重播边界。
	sm.data = sm._defaults()
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	sm.save()
	tm.start()
	await get_tree().process_frame
	await _reach_frontdesk()
	await _wait_until(func(): return _is_stage_type(3, "interact"), 240)
	await _send_key(KEY_E)
	_check(_is_order_explanation() and tracker.get("_expanded") and tracker.get("_panel").visible and tracker.get("_explanation_highlight"), "同实例同订单ID重播仍展开高亮")
	_check(scene.get_node("UIOverlay/TutorialGuide").tree_exiting.get_connections().size() == 1, "同实例重启仅保留本轮离树回调")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _is_order_explanation() -> bool:
	return tm.active and tm.idx >= 0 and tm.idx < tm.steps.size() and bool(tm.steps[tm.idx].get("order_explanation", false))

func _is_stage_type(stage: int, step_type: String) -> bool:
	return tm.active and tm.idx >= 0 and tm.idx < tm.steps.size() and int(tm.steps[tm.idx].get("stage", 0)) == stage and str(tm.steps[tm.idx].get("type", "")) == step_type
