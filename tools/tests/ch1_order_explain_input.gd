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
	_check(_normal_subtask_borders(tracker), "领取食材和制作料理保持原规范边框")
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
	await _verify_breathing(tracker, output_dir, resolution)
	var sizes := [panel.size, ingredients.size, cooking.size]
	# 第二次 E 确认读完对白：任务逻辑立即收起，面板轻微上移淡出，且不穿透打开仓库。
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return not guide.dialog.visible and int(tm.current_stage) == 4, 90), "对白完成后恢复仓库阶段")
	_check(not tracker.get("_explanation_highlight") and not player.input_locked, "对白完成清除高亮并恢复输入")
	_check(not tracker.get("_expanded") and tracker.get("_panel").visible and tracker.get("_expand_tween") != null, "对白完成立即收起并播放淡出")
	await get_tree().create_timer(0.10).timeout
	await RenderingServer.frame_post_draw
	_check(tracker.get("_panel").modulate.a > 0.0 and tracker.get("_panel").modulate.a < 1.0 and tracker.get("_panel").position.y < 66, "对白收起保留上移淡出中间帧")
	await _capture(output_dir, "collapse_middle_%dx%d" % [resolution.x, resolution.y])
	await get_tree().create_timer(0.20).timeout
	_check(not tracker.get("_panel").visible and tracker.get("_expand_tween") == null, "对白收起动画结束隐藏面板")
	_check_highlight_cleared(tracker, "对白结束")
	_check("仓库" in guide.hint_label.text and not guide.dim.visible, "对白完成恢复仓库指引并关闭遮罩")
	_check(not scene.get_node("UIOverlay/WarehouseModal").visible, "完成对白的E不穿透打开仓库")
	_check(sizes == [panel.size, ingredients.size, cooking.size], "撤销高亮前后布局尺寸完全一致")
	await _capture(output_dir, "explain_final_%dx%d" % [resolution.x, resolution.y])
	await _click(tracker.get("_task_button"))
	await get_tree().create_timer(0.3).timeout
	_check(tracker.get("_expanded"), "对白后可手动再次展开任务")
	_check_highlight_cleared(tracker, "手动再次展开")
	await _capture(output_dir, "manual_reopen_%dx%d" % [resolution.x, resolution.y])
	await get_tree().create_timer(1.9).timeout
	_check_highlight_cleared(tracker, "手动展开等待完整呼吸周期后")
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
	_check_highlight_cleared(tracker, "跳过说明")
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
	_check_highlight_cleared(tracker, "离树")
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
	_check_highlight_cleared(tracker, "重进")
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
	var breathing_tween: Tween = tracker.get("_highlight_tween")
	tracker.set_explanation_highlight(true)
	_check(tracker.get("_highlight_tween") == breathing_tween, "重复开启高亮不创建额外呼吸动画")
	tracker.collapse_details()
	_check_highlight_cleared(tracker, "主动收起")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _is_order_explanation() -> bool:
	return tm.active and tm.idx >= 0 and tm.idx < tm.steps.size() and bool(tm.steps[tm.idx].get("order_explanation", false))

func _normal_subtask_borders(tracker: Node) -> bool:
	for panel in tracker.get("_subtask_panels"):
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if style.border_color != Color("#dfcaa5") or style.bg_color != Color("#fff8e8"):
			return false
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			if style.get_border_width(side) != 1 or style.get_content_margin(side) != 10:
				return false
	return true

func _check_highlight_cleared(tracker: Node, context: String) -> void:
	var clean: bool = not tracker.get("_explanation_highlight") and tracker.get("_highlight_tween") == null
	for panel in tracker.get("_subtask_panels"):
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		clean = clean and style.shadow_size == 0 and style.shadow_color.a == 0.0
	_check(clean and _normal_subtask_borders(tracker), context + "无呼吸动画或残留发光，恢复原边框")

func _verify_breathing(tracker: Node, output_dir: String, resolution: Vector2i) -> void:
	var elapsed := 0.0
	var captured_peak := false
	var captured_low := false
	var borders_unchanged := true
	var synchronized := true
	var min_alpha := 1.0
	var max_alpha := 0.0
	while elapsed < 2.1:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var first: StyleBoxFlat = tracker.get("_subtask_panels")[0].get_theme_stylebox("panel")
		var second: StyleBoxFlat = tracker.get("_subtask_panels")[1].get_theme_stylebox("panel")
		borders_unchanged = borders_unchanged and _normal_subtask_borders(tracker)
		synchronized = synchronized and is_equal_approx(first.shadow_color.a, second.shadow_color.a)
		min_alpha = minf(min_alpha, first.shadow_color.a)
		max_alpha = maxf(max_alpha, first.shadow_color.a)
		if first.shadow_color.a >= 0.90 and not captured_peak:
			captured_peak = true
			await _capture(output_dir, "breathing_peak_%dx%d" % [resolution.x, resolution.y])
		# 已批准的高光保持低谷可见（透明度约 0.38），不再呼吸至全透明。
		if first.shadow_color.a >= 0.37 and first.shadow_color.a <= 0.45 and not captured_low:
			captured_low = true
			await _capture(output_dir, "breathing_low_%dx%d" % [resolution.x, resolution.y])
	_check(captured_peak and captured_low and synchronized and min_alpha >= 0.37, "两个子任务同步完成暖色发光呼吸周期", {
		"min_alpha": min_alpha, "max_alpha": max_alpha, "synchronized": synchronized,
		"captured_peak": captured_peak, "captured_low": captured_low})
	_check(borders_unchanged, "整个呼吸周期原边框、底色和内边距不变")

func _is_stage_type(stage: int, step_type: String) -> bool:
	return tm.active and tm.idx >= 0 and tm.idx < tm.steps.size() and int(tm.steps[tm.idx].get("stage", 0)) == stage and str(tm.steps[tm.idx].get("type", "")) == step_type
