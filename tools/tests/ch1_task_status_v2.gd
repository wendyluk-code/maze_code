extends "res://tools/tests/ch1_qte_03_input.gd"

var evidence := ""
var suffix := ""

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _flow()
	var report := {"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name(), "user_dir": ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await _capture(evidence, label + suffix)

func _flow() -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	_check(await _wait_until(func(): return tm.idx == 9, 240), "接单步骤")
	await _send_key(KEY_E)
	_check(tracker._explanation_highlight and guide.dialog.visible, "接单首帧启动高光与对白")
	var glow: StyleBoxFlat = tracker._subtask_panels[0].get_theme_stylebox("panel")
	_check(glow.shadow_color.a > 0.8 and glow.shadow_size == 10, "首帧高光强度已显著非透明", {"alpha": glow.shadow_color.a})
	_check(glow.border_color == Color("#dfcaa5") and glow.border_width_left == 1, "原规范边框保持不变")
	for kind in ["order", "ingredients", "cooking"]:
		_check(tracker._status_icons[kind].progress == 0.0 and tracker._status_icons[kind].size.x == 20, "未完成固定圆圈占位：" + kind)
	await _shot("highlight_first_frame")
	await get_tree().create_timer(0.28).timeout
	await _shot("pending_circles")
	_check(tracker._expand_tween == null, "展开完成清理Tween")
	await get_tree().create_timer(0.26).timeout
	_check(glow.shadow_color.a >= 0.37 and glow.shadow_color.a < 0.75, "呼吸低谷仍可见")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await get_tree().create_timer(0.3).timeout
	_check(not tracker._explanation_highlight and glow.shadow_size == 0, "对白结束无高光残留")
	await _click(tracker._task_button)
	await get_tree().create_timer(0.3).timeout
	_check(tracker._expanded and glow.shadow_color.a == 0, "手动展开仅普通边框")
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	_check(await _wait_until(func(): return tm.idx == 11, 240), "仓库步骤")
	await _send_key(KEY_E)
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._salt_slot._icon_button)
	await _click(warehouse._claim_button)
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "真实取货事务成功")
	await _verify_animation(tracker, "ingredients")
	# 收起结束后重复回执不得重新展开；读档恢复仅最终态。
	tracker.collapse_details()
	await get_tree().create_timer(0.3).timeout
	tracker.play_completion_feedback("ingredients")
	_check(not tracker._expanded and tracker._completion_tween == null, "重复取货回执不展开不重播")
	tracker.refresh_saved_state()
	_check(not tracker._expanded and tracker._status_icons.ingredients.progress == 1.0, "存档刷新只呈现完成态")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	_check(await _wait_until(func(): return tm.idx == 13, 240), "到达烹饪步骤")
	await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	await _click(modal._start_button)
	await _click(modal._finish_button)
	_check(await _wait_until(func(): return not modal.visible, 240), "真实起锅结束关闭面板")
	await _verify_animation(tracker, "cooking")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	_check(await _wait_until(func(): return tm.idx == 15, 240), "到达交单步骤")
	tracker.collapse_details()
	await get_tree().create_timer(0.3).timeout
	await _send_key(KEY_E)
	_check(sm.current_order().get("status") == "completed", "真实E交付成功")
	await _verify_animation(tracker, "order")
	# 在真实订单已完成状态下构造新的显示实例，验证恢复不重播。
	tracker.hide_tracking()
	tracker.refresh_saved_state()
	for kind in ["ingredients", "cooking", "order"]:
		tracker.play_completion_feedback(kind)
	_check(not tracker._expanded and tracker._completion_tween == null, "隐藏恢复及重复完成不重播")
	# 仅回退显示态测试中断；真实存档保持已完成。
	tracker._presented.order = false
	tracker.play_completion_feedback("order")
	await get_tree().create_timer(0.34).timeout
	tracker.collapse_details()
	_check(tracker._completion_tween == null and tracker._status_icons.order.progress == 1.0, "收起中断描勾落最终态")
	for button in [tracker._order_status, tracker._meat_status, tracker._salt_status, tracker._cook_status]:
		_check(button.scale == Vector2.ONE, "中断后计数无缩放残留")
	# 收起过程收到新完成反馈会反向展开，不能沿用收起Tween。
	tracker._presented.order = false
	tracker.play_completion_feedback("order")
	await get_tree().create_timer(0.8).timeout
	_check(tracker._expanded and tracker._panel.visible and tracker._status_icons.order.progress == 1.0, "收起中收到完成能反向展开并绘勾")
	tracker._presented.order = false
	tracker.play_completion_feedback("order")
	_check(not tracker._completion_waiting and tracker._completion_tween != null, "已展开完成Tween释放后可立即绘勾")
	tracker.refresh_saved_state()
	await get_tree().create_timer(0.5).timeout
	_check(tracker._status_icons.order.progress == 1.0 and tracker._completion_tween == null, "动画中刷新不替换活跃样式")
	# 同实例从已完成状态回到新一轮：旧动画不能盖回完成态。
	var saved: Dictionary = sm.data.duplicate(true)
	tracker._presented.order = false
	tracker.play_completion_feedback("order")
	sm.data = sm._defaults()
	tracker.refresh_saved_state()
	_check(not tracker.visible and tracker._completion_tween == null and tracker._status_icons.order.progress == 0.0, "同实例进度回退清理旧勾动画")
	sm.data = saved
	tracker.refresh_saved_state()
	tracker._presented.order = false
	tracker.play_completion_feedback("order")
	get_tree().root.remove_child(scene)
	_check(not tm.active and tracker._completion_tween == null and tracker._expand_tween == null and not tracker._explanation_highlight, "动画中离树完整清理")
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	tracker.refresh_saved_state()
	_check(not tracker._expanded and tracker._status_icons.order.progress == 1.0, "同实例重新入树恢复最终态不重播")
	tm.start()
	tracker._presented.order = false
	tracker.play_completion_feedback("order")
	tm.skip_all()
	_check(not tracker._panel.visible and tracker._completion_tween == null and not tracker._explanation_highlight, "跳过清理全部反馈")
	scene.queue_free()
	await get_tree().process_frame

func _verify_animation(tracker: Node, kind: String) -> void:
	_check(tracker._expanded and tracker._completion_waiting, kind + "：完成先展开")
	_check(tracker._status_icons[kind].progress == 0.0, kind + "：展开中仍圆圈")
	for button in tracker._targets(kind):
		_check(button.text == "0/1" and button.get_theme_stylebox("normal").bg_color == Color("#f4e2bd"), kind + "：展开中旧计数米色")
	tracker.refresh_saved_state()
	_check(tracker._status_icons[kind].progress == 0.0, kind + "：刷新不能抢先覆盖动画")
	await _shot(kind + "_before_check")
	_check(await _wait_until(func(): return tracker._status_icons[kind].progress > 0.12, 120), kind + "：开始实际描勾")
	var progress: float = tracker._status_icons[kind].progress
	_check(progress < 0.8 and tracker._expand_tween == null and tracker._panel.modulate.a == 1.0, kind + "：展开结束后勾路径中间态", {"progress": progress})
	if kind == "ingredients":
		_check(tracker._meat_status.get_theme_stylebox("normal").bg_color == tracker._salt_status.get_theme_stylebox("normal").bg_color, "两个材料同步渐绿")
	var style: StyleBoxFlat = tracker._targets(kind)[0].get_theme_stylebox("normal")
	_check(style.bg_color != Color("#f4e2bd") and style.bg_color != Color("#dce8c6"), kind + "：米色到既有绿色中间态")
	await _shot(kind + "_check_mid")
	await get_tree().create_timer(0.5).timeout
	_check(tracker._completion_tween == null and tracker._status_icons[kind].progress == 1.0, kind + "：勾描绘完成")
	for button in tracker._targets(kind):
		_check(button.text == "1/1" and button.get_theme_stylebox("normal").bg_color == Color("#dce8c6"), kind + "：完成统一绿色")
	await _shot(kind + "_check_end")
