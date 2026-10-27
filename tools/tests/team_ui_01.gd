extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _team_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path}, "\t"))
	print("TEAM_UI_01 ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _team_scene() -> void:
	_fresh()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	maze.toast_label.dismiss()
	var flow = maze.capture_flow
	var details = flow.character_details
	var food_before: Dictionary = Run.Progression.satiety_snapshot(sm).values.duplicate(true)
	await _capture_image("normal")
	_check(maze.capture_flow.party_panel.get_parent() == maze._task_host, "队伍与任务共享显隐层")
	_check(is_equal_approx(flow.party_panel.size.x - flow.party_food.get_rect().end.x, 8), "总饱腹距右边缘8像素")
	_check(flow.party_food.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "总饱腹文字右对齐")
	flow.set_process(false)
	var saved_food_text: String = flow.party_food.text
	for value in ["2/3", "0/3", "12/24", "100/100"]:
		flow.party_food.text = value
		await get_tree().process_frame
		await get_tree().process_frame
		_check(is_equal_approx(flow.party_panel.size.x - flow.party_food.get_rect().end.x, 8), "不同位数饱腹度保留右边距：" + value)
		_check(flow.party_food.size.x >= flow.party_food.get_minimum_size().x and flow.party_food.position.x >= 52, "饱腹度完整且不挤队伍标题：" + value)
		await _capture_image("satiety_" + value.replace("/", "_"))
	flow.party_food.text = saved_food_text
	flow.set_process(true)
	_check(flow.member_buttons.size() == 2, "仅两名成员可点击")
	for id in ["yaya", "tieshan"]:
		var button: Button = flow.member_buttons[id]
		var icon: TextureRect = button.get_parent().get_child(2)
		_check(icon.size == Vector2(24,24), "派系图标24像素且不撑开头像：" + id)
		_check(icon.texture.resource_path.ends_with("grass.png" if id == "yaya" else "earth.png"), "头像正确派系：" + id)
		await _click(button)
		_check(details.visible and details.character_id == id and details.attributes.visible, "点击头像打开正确属性：" + id)
		_check(not flow.party_panel.is_visible_in_tree() and not maze._task_host.visible, "详情打开隐藏任务与队伍")
		await _capture_image(id + "_attributes")
		await _click(details.tabs[1])
		_check(details.selected_tab == 1 and details.skills.visible and not details.skill_titles[0].text.is_empty(), "点击现有技能页：" + id)
		await _capture_image(id + "_skills")
		var position_before: Vector2 = maze.player.position
		Input.action_press("ui_down")
		await get_tree().create_timer(0.15).timeout
		Input.action_release("ui_down")
		await _send_key(KEY_E)
		await _click(maze.backpack_entry)
		_check(maze.player.position == position_before and not maze.backpack_warehouse.visible and not maze.confirmation.visible and not flow.dialog.visible, "详情隔离移动交互及遮罩点击：" + id)
		if id == "yaya": await _click(details._close_button)
		else: await _send_key(KEY_ESCAPE)
		await get_tree().process_frame
		_check(not details.visible and not maze.player.input_locked and maze.player.is_physics_processing() and flow.party_panel.is_visible_in_tree(), "关闭/Esc恢复迷宫：" + id)
	var slots: Array[Node] = flow.party_panel.get_children().filter(func(n): return n is Panel)
	for i in [2,3]:
		await _click(slots[i])
		_check(not details.visible and slots[i].get_child_count() == 1, "空位无派系且点击无动作：" + str(i))
	await _click(maze.map_ui.mini_button)
	await get_tree().process_frame
	_check(maze.map_ui.expanded and not flow.party_panel.is_visible_in_tree(), "地图打开隐藏队伍")
	await _capture_image("map")
	await _send_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(flow.party_panel.is_visible_in_tree(), "地图关闭恢复队伍")
	maze._open_backpack()
	await get_tree().create_timer(0.2).timeout
	_check(not maze.capture_flow.party_panel.is_visible_in_tree(), "背包打开隐藏队伍")
	await _capture_image("backpack")
	await _send_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(flow.party_panel.is_visible_in_tree() and not maze.player.input_locked, "背包关闭恢复队伍和输入")
	maze.player.position = Roads.ENTRANCE
	await get_tree().create_timer(0.2).timeout
	await _click(maze.entrance_prompt.button)
	await get_tree().process_frame
	_check(maze.confirmation.visible and not flow.party_panel.is_visible_in_tree(), "通行确认隐藏队伍")
	await _send_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(flow.party_panel.is_visible_in_tree(), "通行取消恢复队伍")
	_check(Run.Progression.satiety_snapshot(sm, Time.get_unix_time_from_system()+999999).values == food_before, "浏览与迷宫等待不恢复饱腹")
	maze.player.position = Catalog.find("slime_1").position
	await get_tree().create_timer(0.4).timeout
	_check(flow.dialog.visible and flow.dialog.victory and not flow.party_panel.is_visible_in_tree(), "捕获弹窗隐藏队伍")
	await _capture_image("capture")
	await _click(flow.dialog._cancel_button)
	await get_tree().create_timer(0.4).timeout
	_check(flow.party_panel.is_visible_in_tree(), "捕获取消恢复队伍")
	maze.player.position = Catalog.find("lizard_1").position
	await get_tree().create_timer(0.4).timeout
	_check(flow.dialog.visible and not flow.dialog.victory and not flow.party_panel.is_visible_in_tree(), "战力不足隐藏队伍")
	await _capture_image("weak")
	await _click(flow.dialog._confirm_button)
	await get_tree().process_frame
	_check(flow.party_panel.is_visible_in_tree() and not maze.player.input_locked, "战力不足关闭恢复")
	var resume_position: Vector2 = maze.player.position
	Input.action_press("ui_up")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_up")
	_check(maze.player.position.distance_to(resume_position) > 0.1, "关闭后真实方向输入恢复移动")
	maze.queue_free()
	await get_tree().process_frame
