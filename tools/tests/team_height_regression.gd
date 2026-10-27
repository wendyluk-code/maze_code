extends "res://tools/tests/team_entry_01.gd"
## 真实餐厅首次打开已记忆的零饱腹队伍，覆盖初始化换行与容器尺寸收敛。
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			_completed()
			sm.cancel_maze_entry()
			sm.data[sm.TEAM_MEMORY_KEY] = ["yaya", "tieshan"]
			sm.data[Run.Progression.FOOD_KEY] = {"values":{"yaya":0.0,"tieshan":0.0},"at":Time.get_unix_time_from_system(),"paused":true}
			sm.save()
			await _restaurant()
			await get_tree().create_timer(0.3).timeout
			await _measure("remembered_zero_food")
			await _click(modal.slots[0])
			_check(modal.selector.visible, "头像可打开选择页")
			await _click(modal.selection_done)
			await _measure("return_from_selector")
			await _send_key(KEY_ESCAPE)
			_check(not modal.visible and not hud._player.input_locked, "Esc关闭并恢复输入")
			await _send_key(KEY_E)
			await _measure("reopened")
			await _click(modal.cancel_button)
			_check(not modal.visible and not hud._player.input_locked, "取消按钮可见可点击并恢复输入")
			_check(sm.remembered_maze_party() == ["yaya", "tieshan"] and sm.stamina() == 100, "查看取消不改变队伍记忆和体力")
			scene.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("TEAM_HEIGHT ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _measure(label: String) -> void:
	await get_tree().create_timer(0.1).timeout
	var rect: Rect2 = modal.team_panel.get_global_rect()
	_check(get_viewport().get_visible_rect().encloses(rect), label + "：面板完整位于视口", {"rect":str(rect),"minimum":str(modal.team_panel.get_combined_minimum_size())})
	_check(is_equal_approx(rect.size.y, minf(624, modal.size.y - 48)), label + "：恢复原定高度")
	_check(modal.warning.visible and modal.food_value.text == "0", label + "：零饱腹提示保留")
	await _capture_image(label)
