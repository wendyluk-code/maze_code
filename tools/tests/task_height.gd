extends "res://tools/tests/team_ui_01.gd"

func _team_scene() -> void:
	_fresh()
	for scene_path in ["res://scenes/restaurant_map_2d.tscn", "res://scenes/maze_entry.tscn"]:
		maze = load(scene_path).instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.6).timeout
		var tracker = get_tree().get_first_node_in_group("order_tracking")
		tracker.set_process(false)
		tracker.show()
		await _click(tracker._task_button)
		var content = tracker._scroll.get_child(0)
		for item in content.get_children(): item.hide()
		tracker._exploration_task.show()
		tracker._exploration_name.text = "前往迷宫浅层·盐池"
		await get_tree().create_timer(0.3).timeout
		var short_height: float = tracker._panel.size.y
		_check(short_height < 200 and short_height > 50, "单任务按内容收缩" + scene_path + suffix)
		_check(not tracker._scroll.get_v_scroll_bar().visible, "短列表没有滚动条")
		await _capture_image("short_" + scene_path.get_file())
		var extra := Control.new()
		extra.custom_minimum_size = Vector2(100, 600)
		content.add_child(extra)
		await get_tree().create_timer(0.3).timeout
		_check(is_equal_approx(tracker._panel.size.y, 411), "长列表限制最大411高度")
		_check(tracker._scroll.get_v_scroll_bar().visible, "长列表显示滚动条")
		var event := InputEventMouseButton.new()
		event.position = tracker._scroll.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		get_viewport().push_input(event)
		await get_tree().process_frame
		_check(tracker._scroll.scroll_vertical > 0, "超高内容可滚动")
		await _capture_image("long_" + scene_path.get_file())
		extra.queue_free()
		await get_tree().create_timer(0.3).timeout
		_check(is_equal_approx(tracker._panel.size.y, short_height), "任务减少后再次收缩")
		_check(tracker._scroll.scroll_vertical == 0, "收缩后滚动位置恢复")
		maze.queue_free()
		await get_tree().process_frame
