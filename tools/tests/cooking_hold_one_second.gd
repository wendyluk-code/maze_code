extends "res://tools/tests/cooking_countdown_input.gd"
## 在真实餐厅场景注入鼠标输入，记录结束点击至结果展示的时间。
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	var expected := int(_arg("--expected-ms="))
	_check(_verify_isolation(), "隔离存档")
	_check(DisplayServer.get_name() != "headless", "实际图形渲染")
	if failures == 0:
		for trial in 3:
			await _prepare_collected()
			sm.acknowledge_cooking_guide()
			var modal = await _open_cooking()
			await _click(modal._start_button)
			var start := Time.get_ticks_msec()
			await _finish_click(modal)
			var saved: Dictionary = sm.data.duplicate(true)
			var pointer: float = modal._gauge.pointer_position
			_check(modal._finished and modal._panel.visible and not modal._result_popup.visible, "点击后保留料理台")
			await get_tree().create_timer(0.15).timeout
			await _send_key(KEY_SPACE)
			await _send_key(KEY_E)
			await _send_key(KEY_ESCAPE)
			_check(modal._panel.visible and not modal._result_popup.visible and sm.data == saved and modal._gauge.pointer_position == pointer, "停留期间输入不重复结算")
			await _capture(evidence, "hold_%d" % trial)
			_check(await _wait_seconds(func(): return modal._result_popup.visible, 3.0), "显示原结果弹窗")
			var elapsed := Time.get_ticks_msec() - start
			_check(elapsed >= expected - 50 and elapsed <= expected + 180, "点击至结果弹窗毫秒测量", {"trial":trial,"elapsed_ms":elapsed,"expected_ms":expected})
			_check(modal.visible and not modal._panel.visible and scene.get_node("Player").input_locked, "结果仍等待确认且锁定玩家")
			await get_tree().create_timer(0.35).timeout
			await _capture(evidence, "result_%d" % trial)
			await _click(modal._result_popup._confirm_button)
			_check(not modal.visible and not scene.get_node("Player").input_locked, "原确认按钮关闭并恢复玩家输入")
		await _prepare_collected()
		sm.acknowledge_cooking_guide()
		var modal = await _open_cooking()
		await _click(modal._start_button)
		await _finish_click(modal)
		var saved: Dictionary = sm.data.duplicate(true)
		modal.close_modal()
		modal.open_for_order()
		await get_tree().create_timer(2.3).timeout
		_check(modal.visible and modal._panel.visible and not modal._result_popup.visible and modal._result_hold_until_msec == 0 and sm.data == saved, "关闭重开清除旧等待且不重复产出")
		await _cleanup()
	var report := {"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name()}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("COOKING_HOLD ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
