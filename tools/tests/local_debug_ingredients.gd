extends "res://tools/tests/local_debug.gd"

func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	var debug = get_node("/root/LocalDebug")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_seed()
		for phase in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(phase)
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _open_scene()
			await _type_code()
			_check(debug.panel.visible and get_tree().paused, "实际暗号唤出并暂停")
			await _ingredients(debug)
			debug.tabs.current_tab = 1
			var scroll: ScrollContainer = debug.tabs.get_child(1).get_child(1)
			scroll.scroll_vertical = 10000
			await get_tree().process_frame
			await get_tree().process_frame
			var last_id: String = debug.ingredient_rows.keys().back()
			var last: Dictionary = debug.ingredient_rows[last_id]
			await _click(last.selected)
			last.quantity.text = "1"
			var previous: int = sm.warehouse_snapshot().get(last_id, 0)
			await _click(debug.ingredient_submit)
			_check(sm.warehouse_snapshot().get(last_id, 0) == previous + 1, "滚动到末尾食材可以选择补充")
			await _shot("debug_ingredients_bottom")
			await _send_key(KEY_ESCAPE)
			_check(not debug.panel.visible and not get_tree().paused and scene.get_node("Player").can_process(), "关闭恢复场景输入和暂停")
			debug.open_panel()
			debug.tabs.current_tab = 0
			await get_tree().process_frame
			var gold: int = sm.gold_balance()
			debug.amount.value = 7
			for button in debug.panel.find_children("*", "Button", true, false):
				if button.text == "增加金币": await _click(button)
			_check(sm.gold_balance() == gold + 7, "原资源操作回归")
			debug.close_panel()
			await _close_scene()
		get_tree().paused = true
		debug.open_panel()
		debug.close_panel()
		_check(get_tree().paused, "保留原暂停状态")
		get_tree().paused = false
	FileAccess.open(_arg("--report="), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
