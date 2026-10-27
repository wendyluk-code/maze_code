extends "res://tools/tests/team_entry_01.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			_completed()
			sm.cancel_maze_entry()
			await _restaurant()
			await _click(modal.slots[0])
			for index in [1,3,2,0]:
				var point: Vector2 = modal.tabs.global_position + modal.tabs.get_tab_rect(index).get_center()
				for pressed in [true,false]:
					var event := InputEventMouseButton.new()
					event.position = point
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = pressed
					get_viewport().push_input(event)
					await get_tree().process_frame
				_check(modal.tabs.current_tab == index, "真实鼠标切换分类%d" % index)
				if index == 1: _check(modal.checks.has("yaya"), "草系包含芽芽")
				if index == 3: _check(modal.checks.is_empty(), "雷系空态")
				if index == 2: _check(modal.checks.has("tieshan"), "土系包含铁山")
			await _click(modal.checks.yaya)
			await _click(modal.selection_done)
			_check(modal.selected.has("yaya") and not modal.selector.visible, "确认选择返回组队")
			await _click(modal.slot_names[0])
			_check(modal.details.visible, "打开真实角色详情")
			for index in [1,0]:
				await _click(modal.details.tabs[index])
				_check(modal.details.selected_tab == index, "手绘详情页签切换")
				for state in ["font_hover_color", "font_hover_pressed_color"]:
					_check(modal.details.tabs[index].get_theme_color(state) == SproutTheme.CREAM, "深色手绘选中页签保持浅色文字")
			await RenderingServer.frame_post_draw
			await _capture(_arg("--output-dir="), "details" + suffix)
			await _send_key(KEY_ESCAPE)
			await _click(modal.close_button)
			_check(not modal.visible and not hud._player.input_locked, "组队关闭恢复玩家输入")
			var warehouse = get_tree().get_first_node_in_group("warehouse_modal")
			warehouse.open_empty_stock()
			await get_tree().process_frame
			await _send_key(KEY_ESCAPE)
			_check(not warehouse.visible and not hud._player.input_locked, "仓库关闭恢复输入")
			load("res://scripts/ui/adventurer_home.gd").open_page(get_tree())
			await get_tree().process_frame
			var home = get_tree().get_first_node_in_group("adventurer_home")
			for index in [1,0]:
				await _click(home.tabs[index])
				_check(home.selected_tab == index and home.summon_panel.visible == (index == 1), "之家手绘页签实际切换")
				_check(home.tabs[index].get_theme_color("font_hover_pressed_color") == home.tabs[index].GOLD, "之家选中页签文字一致")
			await RenderingServer.frame_post_draw
			await _capture(_arg("--output-dir="), "home" + suffix)
			await _click(home.back_button)
			_check(scene.process_mode != Node.PROCESS_MODE_DISABLED, "之家关闭恢复餐厅")
			scene.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
