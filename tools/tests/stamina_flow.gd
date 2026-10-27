extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0 and "--resume-stamina" in OS.get_cmdline_user_args():
		sm._active_save_path = "user://chapter-ending-test.json"
		sm.load_data()
		_check(sm.stamina() == 60, "独立进程恢复已扣除体力60")
		_check(not sm._maze_entry_pending, "独立进程无待扣费标记")
		var old_path: String = sm._active_save_path
		_check(sm.create_new_game().success and sm.stamina() == 100, "换至新档为100不串档")
		sm._active_save_path = old_path
		sm.load_data()
		_check(sm.stamina() == 60, "切回旧档仍为60")
	elif failures == 0:
		_state_checks()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%d" % resolution.x
			await _stamina_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("STAMINA ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _state_checks() -> void:
	_completed()
	_check(sm.stamina() == 100, "初始100")
	sm.data.erase("stamina")
	sm.save()
	sm.load_data()
	_check(sm.stamina() == 100, "旧档缺字段100")
	sm.data.stamina = {"value": 50, "at": 1000}
	_check(sm.stamina_snapshot(1299).value == 50, "299秒不恢复")
	_check(sm.stamina_snapshot(1300).value == 51, "300秒恢复1")
	_check(sm.stamina_snapshot(1750) == {"value":52,"at":1600}, "保留不足5分钟余数")
	_check(sm.stamina_snapshot(999).value == 50, "时钟回拨不恢复")
	_check(sm.stamina_snapshot(100000) == {"value":100,"at":100000}, "恢复封顶且停止累计")
	sm.data.stamina = {"value":50,"at":int(Time.get_unix_time_from_system()) - 600}
	sm.save()
	sm.load_data()
	_check(sm.stamina() == 52, "离线恢复与重载一致")
	var saved_bytes := FileAccess.get_file_as_bytes(sm._active_save_path)
	for i in 10: sm.stamina()
	_check(FileAccess.get_file_as_bytes(sm._active_save_path) == saved_bytes, "显示查询不反复写盘")
	sm.data.stamina = {"value":100,"at":1000}
	_check(sm.request_maze_entry().success, "确认预留进入")
	_check(not sm.request_maze_entry().success, "重复确认被拒绝")
	var path: String = sm._active_save_path
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.record_maze_location("maze_entry", Roads.SPAWN).success and sm.data == before, "保存失败体力与位置一起回滚")
	sm._active_save_path = path
	_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success and sm.stamina() == 80, "重试只扣20且满值无历史积累")
	_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success and sm.stamina() == 80, "重复位置保存不扣费")
	sm.load_data()
	_check(sm.stamina() == 80 and not sm._maze_entry_pending, "读档不重复扣费")
	sm.data.stamina = {"value":19,"at":int(Time.get_unix_time_from_system())}
	_check(not sm.request_maze_entry().success and sm.stamina() == 19, "不足20拒绝")
	sm.data.stamina.value = 20
	_check(sm.request_maze_entry().success and sm.record_maze_location("maze_entry", Roads.SPAWN).success and sm.stamina() == 0, "恰好20允许并扣至0")

func _click_control(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	get_viewport().warp_mouse(pos)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame

func _stamina_flow() -> void:
	_completed()
	await _open_scene()
	tm._cancel_current_run()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	hud._player.input_locked = false
	await get_tree().process_frame
	var energy = get_tree().get_first_node_in_group("stamina_counter")
	_check(energy.counter.value_label.text == "100/100", "餐厅右上体力")
	var hover := InputEventMouseMotion.new()
	hover.position = energy.info.get_global_rect().get_center()
	get_viewport().warp_mouse(hover.position)
	get_viewport().push_input(hover)
	await get_tree().create_timer(1.0).timeout
	await _shot("restaurant_hover")
	_check(energy.hint_panel.get_child(0).text == "每5分钟恢复1点", "悬停说明")
	hud._open_confirmation("迷宫")
	_check(hud.confirm_button.text == "是" and hud.cancel_button.text == "否", "确认按钮否是")
	await _shot("confirm")
	await _click_control(hud.cancel_button)
	_check(sm.stamina() == 100 and not hud._player.input_locked and not hud.confirmation.visible, "点击否不扣费并恢复输入")
	sm.data.stamina = {"value":19,"at":int(Time.get_unix_time_from_system())}
	hud._open_confirmation("迷宫")
	_check(hud.confirm_button.disabled, "不足体力禁用是")
	await _send_key(KEY_E)
	_check(hud.confirmation.visible and not sm._maze_entry_pending, "不足体力按E不能绕过")
	await _shot("insufficient")
	await _send_key(KEY_ESCAPE)
	_check(not hud.confirmation.visible and not hud._player.input_locked, "Esc取消恢复输入")
	sm.data.stamina = {"value":100,"at":int(Time.get_unix_time_from_system())}
	hud._open_confirmation("迷宫")
	await _click_control(hud.confirm_button)
	await get_tree().create_timer(1.5).timeout
	var maze = get_tree().get_first_node_in_group("maze_entry")
	_check(is_instance_valid(maze) and sm.stamina() == 80, "点击是进入真实迷宫扣20")
	if not is_instance_valid(maze): return
	energy = get_tree().get_first_node_in_group("stamina_counter")
	_check(energy.counter.value_label.text == "80/100" and not maze.player.input_locked, "迷宫显示80且可操作")
	_check(not energy.get_global_rect().intersects(maze.map_ui.mini_button.get_global_rect()), "体力不与小地图重叠")
	hover.position = energy.info.get_global_rect().get_center()
	get_viewport().warp_mouse(hover.position)
	get_viewport().push_input(hover)
	await get_tree().create_timer(1.0).timeout
	await _shot("maze")
	maze.confirmation.open_destination("餐厅")
	_check(not maze.confirmation.confirm_button.disabled and maze.confirmation.question.visible and not maze.confirmation._cost_row.visible, "原通行确认正常且不显示体力消费")
	maze.confirmation.hide()
	maze.return_to_restaurant()
	await get_tree().create_timer(1.5).timeout
	_check(sm.stamina() == 80, "返回餐厅不消耗")
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	hud._open_confirmation("迷宫")
	await _click_control(hud.confirm_button)
	await get_tree().create_timer(1.5).timeout
	_check(sm.stamina() == 60, "再次进入再次扣20")
	sm.load_data()
	_check(sm.stamina() == 60, "跨场景消耗持久化")
	scene = get_tree().current_scene
	await _close_scene()
