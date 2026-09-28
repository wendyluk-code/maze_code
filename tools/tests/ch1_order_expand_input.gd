extends "res://tools/tests/ch1_qte_03_input.gd"

## 复用真实餐厅场景与单一路径键鼠输入，只改隔离测试存档。
func _run() -> void:
	var output_dir := _arg("--output-dir=")
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "测试存档目录隔离")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			await _prepare_scene()
			await _reach_frontdesk()
			var player := scene.get_node("Player")
			var tracker := scene.get_node("UIOverlay/OrderTracking")
			player.global_position = _stand(scene.get_node("InteractPoints/Register"))
			_check(await _wait_until(func(): return tm.idx == 9, 240), "到达前台接单步骤")
			await _send_key(KEY_E)
			_check(sm.current_order().get("status") == "in_progress", "真实E成功接单")
			var panel: Control = tracker.get("_panel")
			var button: Button = tracker.get("_task_button")
			var guide := scene.get_node("UIOverlay/TutorialGuide")
			await get_tree().create_timer(0.04).timeout
			await RenderingServer.frame_post_draw
			_check(tracker.get("_expanded") and panel.visible and panel.modulate.a > 0.0 and panel.modulate.a < 1.0 and panel.position.y > 56.0 and panel.position.y < 66.0, "自动展开有淡入下移中间态", {"alpha": panel.modulate.a, "y": panel.position.y, "size": str(panel.size), "scale": str(panel.scale)})
			_check(panel.scale == Vector2.ONE and panel.size.x >= 260.0, "动画不缩放文字与框条")
			_check(not guide.toast.visible and guide.dialog.visible, "接单反馈改为芽芽对白且无toast")
			_check(tracker.expanded_panel_rect() == panel.get_global_rect(), "动画中提示避让仍返回完整面板矩形")
			await _capture(output_dir, "middle_%dx%d" % [resolution.x, resolution.y])
			var receipt_tween: Tween = tracker.get("_expand_tween")
			tracker.refresh_saved_state()
			_check(tracker.get("_expand_tween") == receipt_tween, "刷新不重启动画")
			await get_tree().create_timer(0.35).timeout
			_check(panel.modulate.a == 1.0 and panel.position == Vector2(16, 66) and panel.visible, "动画结束面板稳定可读")
			for counter in ["_order_status", "_meat_status", "_salt_status", "_cook_status"]:
				_check(tracker.get(counter).text == "0/1", "保留初始计数" + counter)
			await RenderingServer.frame_post_draw
			await _capture(output_dir, "final_%dx%d" % [resolution.x, resolution.y])
			# 接单说明沿用标准对白输入，读完才继续仓库与后续动画回归。
			await _send_key(KEY_SPACE)
			if guide.dialog.visible:
				await _send_key(KEY_SPACE)
			var order_before: Dictionary = sm.current_order().duplicate(true)
			await _send_key(KEY_E)
			_check(sm.current_order() == order_before and tracker.get("_expand_tween") == receipt_tween and not receipt_tween.is_running(), "重复E不重播且不改变订单")
			await _click(button)
			_check(not panel.visible and not tracker.get("_expanded"), "真实点击收起任务")
			tracker.show_order_receipt(sm.current_order())
			sm.load_data()
			tracker.refresh_saved_state()
			_check(not panel.visible and tracker.get("_expand_tween") == null, "重复回执及读档刷新不展开")
			await _click(button)
			_check(tracker.get("_expand_tween").is_running(), "真实点击正常展开")
			await _click(button)
			await _assert_stays_closed(tracker, "动画中真实点击收起")
			await _click(button)
			tracker.hide_tracking()
			tracker.refresh_saved_state()
			await _assert_stays_closed(tracker, "动画中隐藏再刷新")
			await _click(button)
			tracker.hide()
			tracker.show()
			await _assert_stays_closed(tracker, "直接隐藏再显示")
			await _click(button)
			var parent := tracker.get_parent()
			parent.remove_child(tracker)
			parent.add_child(tracker)
			await _assert_stays_closed(tracker, "动画中离树再入树")
			# 真实 E 打开仓库，真实鼠标领取，再 E 打开料理台。
			player.global_position = _stand(scene.get_node("InteractPoints/Store"))
			_check(await _wait_until(func(): return tm.idx == 11, 240), "进入仓库交互步骤")
			await _click(button)
			_check(tracker.get("_expand_tween").is_running(), "仓库打开前动画正在运行")
			await _send_key(KEY_E)
			var warehouse := scene.get_node("UIOverlay/WarehouseModal")
			_check(warehouse.visible, "真实E打开仓库")
			await _assert_stays_closed(tracker, "仓库打开取消动画")
			await _capture(output_dir, "warehouse_%dx%d" % [resolution.x, resolution.y])
			await _click(warehouse.get("_meat_slot").get("_icon_button"))
			await _click(warehouse.get("_salt_slot").get("_icon_button"))
			await _click(warehouse.get("_claim_button"))
			_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "真实鼠标领取材料")
			player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
			_check(await _wait_until(func(): return tm.idx == 13, 240), "进入料理交互步骤")
			await _click(button)
			_check(tracker.get("_expand_tween").is_running(), "料理打开前动画正在运行")
			await _send_key(KEY_E)
			var cooking := scene.get_node("HUD/CookingModal")
			_check(cooking.visible, "真实E打开料理台")
			await _assert_stays_closed(tracker, "料理打开取消动画")
			await _capture(output_dir, "cooking_%dx%d" % [resolution.x, resolution.y])
			# 继续真实首单结算与既有对白，解锁后再点击地图。
			await _click(cooking.get("_start_button"))
			await get_tree().create_timer(3.9).timeout
			_check(await _wait_until(func(): return tm.idx == 14 and not cooking.visible, 240), "料理完成后恢复输入")
			player.global_position = _stand(scene.get_node("InteractPoints/Register"))
			_check(await _wait_until(func(): return tm.idx == 15, 240), "到达交付步骤")
			await _send_key(KEY_E)
			await _run_post_delivery_empty_warehouse()
			var departure := scene.get_node("UIOverlay/DeparturePanel")
			await get_tree().process_frame
			await _click(button)
			_check(tracker.get("_expand_tween").is_running(), "地图打开前动画正在运行")
			var map_button: Control = departure.get("_summary").get_child(0).get_child(1)
			await _click(map_button)
			_check(departure.get("_open"), "真实鼠标打开地图")
			await _assert_stays_closed(tracker, "地图打开取消动画")
			await _capture(output_dir, "map_%dx%d" % [resolution.x, resolution.y])
			await _send_key(KEY_ESCAPE)
			# 已接单存档创建全新组件，恢复列表内容但不自动播放。
			sm.save()
			var restored: Control = load("res://scenes/ui/order_tracking.tscn").instantiate()
			scene.get_node("UIOverlay").add_child(restored)
			await get_tree().process_frame
			await get_tree().process_frame
			_check(restored.visible and not restored.get("_expanded") and restored.get("_expand_tween") == null, "新组件从已有存档恢复不重播")
			restored.queue_free()
			tm._cancel_current_run()
			scene.queue_free()
			await get_tree().process_frame
	var report := {"checks": checks, "failures": failures, "results": results, "user_dir": ProjectSettings.globalize_path("user://"), "display": DisplayServer.get_name()}
	var f := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _assert_stays_closed(tracker: Control, label: String) -> void:
	await get_tree().create_timer(0.35).timeout
	_check(not tracker.get("_expanded") and not tracker.get("_panel").visible and tracker.get("_expand_tween") == null and tracker.expanded_panel_rect() == Rect2(), label + "且旧Tween不重开")
