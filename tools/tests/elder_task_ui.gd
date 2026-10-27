extends "res://tools/tests/team_ui_01.gd"
const NEAR := Vector2(839,503)

func _team_scene() -> void:
	_fresh()
	sm.data.inventory.wood = 0
	_check(sm.record_maze_location("maze_entry", NEAR).success, "站位保存")
	_check(sm.accept_elder_firewood(NEAR).success, "原事务接取木材任务")
	_check(sm.register_customer_order("wood_ui_order", sm.FIRST_ORDER_ITEM_ID).success, "登记订单")
	_check(sm.accept_waiting_customer_order().success, "接取订单")
	for scene_path in ["res://scenes/restaurant_map_2d.tscn", "res://scenes/maze_entry.tscn"]:
		maze = load(scene_path).instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.7).timeout
		var tracker = get_tree().get_first_node_in_group("order_tracking")
		tracker.refresh_saved_state()
		await _click(tracker._task_button)
		await get_tree().create_timer(0.3).timeout
		_check(not tracker._order_status.visible and not tracker._exploration_status.visible, "所有主任务隐藏数量" + scene_path)
		_check(tracker._collection_name.text == "帮助白虎爷爷收集木材", "探索说明准确")
		_check(sm.quest_snapshot().active.any(func(q): return q.id == "elder_firewood" and q.type == "exploration" and q.subtasks.size() == 1), "任务定义改型及子任务")
		_check(tracker._exploration_task.visible and tracker._collection_task.visible, "两项探索同时显示")
		_check(tracker._collection_status.get_parent().get_child(0).custom_minimum_size == Vector2(28,28), "木材复用28像素订单图标")
		tracker._scroll.ensure_control_visible(tracker._collection_subtasks)
		await get_tree().create_timer(0.1).timeout
		for wood in [0,3,11,12,15]:
			sm.data.inventory.wood = wood
			tracker.refresh_saved_state()
			await get_tree().create_timer(0.1).timeout
			_check(tracker._collection_status.text == "%d/12" % wood, "实际木材数量%s" % wood)
			_check(tracker._status_icons.collection_materials.progress == (1.0 if wood >= 12 else 0.0), "材料子任务勾选%s" % wood)
			_check(tracker._status_icons.collection.progress == 0.0, "未交付主任务不勾选%s" % wood)
			if wood in [3,12]: await _capture_image(scene_path.get_file() + "_wood_%s" % wood)
		if scene_path.contains("maze_entry"):
			maze.player.position = NEAR
			_check(sm.record_maze_location("maze_entry",NEAR).success, "交付位置记录")
			var path = sm._active_save_path
			sm._active_save_path = ""
			_check(not sm.deliver_elder_firewood(NEAR).success, "保存失败拒绝交付")
			tracker.refresh_saved_state()
			_check(tracker._status_icons.collection.progress == 0 and tracker._collection_feedback_left == 0, "保存失败不勾主任务")
			sm._active_save_path = path
			_check(sm.deliver_elder_firewood(NEAR).success, "真实事务成功交付")
			tracker.refresh_saved_state()
			_check(tracker._status_icons.collection.progress == 1 and tracker._collection_task.visible, "交付后主任务打勾")
			_check(sm.elder_firewood_state().wood == 3, "扣除12保留余量")
			await _capture_image("delivered")
			await get_tree().create_timer(1.6).timeout
			_check(not tracker._collection_task.visible and not tracker._collection_subtasks.visible, "完成反馈后归档移除")
			_check(not sm.deliver_elder_firewood(NEAR).success, "重复交付拒绝")
			sm.load_data()
			tracker.refresh_saved_state()
			_check(not tracker._collection_task.visible and sm.elder_firewood_state().status == "archived", "重载保持归档不重播")
		_check(tracker._panel.size.y <= 411.1, "面板仍限高")
		maze.queue_free()
		await get_tree().process_frame
