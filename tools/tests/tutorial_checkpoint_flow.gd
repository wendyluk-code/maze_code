extends SceneTree
## 正式餐厅对白输入与读档回归，所有存档均在启动器指定的隔离目录。

var sm
var tm
var scene: Node
var results: Array = []
var failures := 0
var report_path := ""

func _init() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool) -> void:
	results.append({"label": label, "passed": passed})
	if not passed:
		failures += 1
		print("FAIL: ", label)

func _arg(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return ""

func _run() -> void:
	report_path = _arg("--report=")
	var isolation := OS.get_environment("MAZE_CHECKPOINT_PROFILE").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if isolation.is_empty() or not actual.begins_with(isolation + "/") or report_path.is_empty():
		push_error("拒绝在非隔离存档中运行检查点验收")
		quit(2)
		return
	sm = root.get_node("SaveManager")
	tm = root.get_node("TutorialManager")
	if "--resume" in OS.get_cmdline_user_args():
		await _resume_from_menu()
		_write_report(actual)
		return
	sm.data = sm._defaults()
	sm.data.prologue_done = true
	_check("建立隔离存档", sm.save())
	await _open_scene()
	_check("正式餐厅自动启动首句", tm.active and tm.idx == 0)
	await _confirm_line()
	_check("确认首句后立即写下一步", _disk_checkpoint().get("next_index") == 1)
	await _reload()
	_check("重进接续第二句", tm.idx == 1 and tm.guide.dialog.speaker_name.text == "你")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _confirm_line()
	_check("写盘失败不推进对白", tm.idx == 1 and tm.guide.dialog.visible)
	sm._active_save_path = path
	await _reload()
	_check("失败后重进仍保留上一检查点", tm.idx == 1)
	await _confirm_line()
	await _confirm_line()
	var deadline := Time.get_ticks_msec() + 15000
	while tm.active and tm.steps[tm.idx].get("type") == "cutscene_guest" and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("客人过场正常完成", tm.active and tm.steps[tm.idx].get("speaker") == "？？？")
	await _confirm_line()
	var multi_index: int = tm.idx
	await _confirm_line()
	_check("多句对白第一句确认后记录行号", _disk_checkpoint().get("line_index", 0) == 1)
	await _reload()
	_check("多句对白重进接续未确认句", tm.idx == multi_index and str(tm.guide.dialog._lines[0]).begins_with("你不会连"))
	await _confirm_line()
	_check("对白结束恢复自由移动", not tm.player.input_locked)
	_check("找到前台合法交互站位", _stand_near(tm.resolve_target("前台")))
	await process_frame
	await process_frame
	var old_checkpoint: Dictionary = _disk_checkpoint()
	await _press_e()
	_check("实际按E接单并进入说明对白", sm.lifecycle_stage() == "order_accepted" and tm._order_explanation_pending)
	path = sm._active_save_path
	sm._active_save_path = ""
	await _confirm_line()
	_check("接单说明保存失败仍可重试", tm._order_explanation_pending and tm.guide.dialog.visible)
	sm._active_save_path = path
	await _confirm_line()
	_check("接单说明重试成功写入仓库引导", tm.current_stage == 4 and not tm._order_explanation_pending)
	# 真实经营事务先提交、教程检查点尚未更新时退出，也不能回退。
	tm._cancel_current_run()
	sm.data[sm.TUTORIAL_CHECKPOINT_KEY] = old_checkpoint
	_check("模拟较早教程检查点与已提交接单并存", sm.save())
	await _reload()
	_check("旧对白检查点不覆盖接单结果", tm.current_stage == 4)
	tm._cancel_current_run()
	_check("取料事务成功", sm.claim_first_order_ingredients().success)
	await _reload()
	_check("重进保留食材及制作阶段", tm.current_stage == 5 and sm.carried_ingredients().get("rock_salt", 0) == 1)
	tm._cancel_current_run()
	_check("料理事务成功", sm.cook_first_order().success)
	await _reload()
	_check("重进保留料理及上菜阶段", tm.current_stage == 6)
	tm._cancel_current_run()
	_check("交单事务成功", sm.deliver_first_order().success)
	await _reload()
	var reputation: int = sm.reputation()
	_check("重进保留结算及收尾阶段", tm.current_stage == 7 and reputation > 0)
	await _confirm_line()
	await _reload()
	_check("收尾对白逐句续接且不重复奖励", tm.steps[tm.idx].get("wrapup_id") == "meat" and sm.reputation() == reputation)
	tm._cancel_current_run()
	var before: String = FileAccess.get_file_as_string(sm._active_save_path)
	sm.begin_replay()
	_check("重播不会改写检查点文件", sm.save_tutorial_checkpoint(1, "step:1:dialog:你") and FileAccess.get_file_as_string(sm._active_save_path) == before)
	sm.end_replay()
	# 为第二个独立进程留下一个通过实际对白输入生成的独立档。
	_check("建立供进程重启验证的独立档", sm.create_new_game().success)
	sm.data.prologue_done = true
	_check("存储已看序章状态", sm.save())
	await _open_scene()
	await _confirm_line()
	var marker := FileAccess.open("user://checkpoint_slot.txt", FileAccess.WRITE)
	marker.store_string(sm._active_save_path)
	marker.close()
	await _capture("before_exit.png")
	_write_report(actual)

func _write_report(actual: String) -> void:
	var report := {"checks": results.size(), "failures": failures, "results": results, "user_dir": actual}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CHECKPOINT_FLOW ", results.size(), " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _resume_from_menu() -> void:
	var slot := FileAccess.get_file_as_string("user://checkpoint_slot.txt")
	_check("上一进程留下独立档", slot.begins_with("user://saves/") and FileAccess.file_exists(slot))
	change_scene_to_file("res://scenes/start_screen.tscn")
	await scene_changed
	await process_frame
	# 与点击存档列表条目相同的信号，贯穿正式开始界面、序章和餐厅入口。
	current_scene.save_modal.slot_requested.emit(slot)
	var deadline := Time.get_ticks_msec() + 15000
	while (not tm.active or not is_instance_valid(tm.guide) or not get_nodes_in_group("prologue_transition").is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("全新进程通过存档列表加载正确档案", sm._active_save_path == slot and tm.active)
	if not tm.active:
		return
	_check("进程重启后接续未确认对白", tm.idx == 1 and tm.guide.dialog.speaker_name.text == "你")
	await _capture("after_restart.png")
	await _confirm_line()
	_check("继续后写回选中的独立档", _disk_checkpoint().get("next_index") == 2)
	_check("不会意外创建旧版默认存档", not FileAccess.file_exists("user://save.json") or sm._active_save_path != "user://save.json")

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(report_path.get_base_dir().path_join(filename))

func _disk_checkpoint() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(sm._active_save_path))
	return parsed.get("tutorial_checkpoint", {}) if parsed is Dictionary else {}

func _open_scene() -> void:
	change_scene_to_file("res://scenes/restaurant_map_2d.tscn")
	await scene_changed
	await process_frame
	await process_frame
	scene = current_scene

func _reload() -> void:
	tm._cancel_current_run()
	sm.load_data()
	await _open_scene()

func _press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = false
	root.push_input(event)
	await process_frame

func _confirm_line() -> void:
	var dialog = tm.guide.dialog
	if not dialog.visible or dialog._line_idx >= dialog._lines.size():
		_check("待确认对白可见", false)
		return
	if dialog._shown < str(dialog._lines[dialog._line_idx]).length():
		await _press_e()
	await _press_e()

func _stand_near(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	var player = tm.player
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if not player.is_walkable_footprint(candidate):
				continue
			player.global_position = candidate
			if player.nearest_interactable() == target:
				player.last_valid = candidate
				return true
	return false
