extends "res://tools/tests/ch2_chest_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		if failures: break
		DisplayServer.window_set_size(resolution)
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		await get_tree().process_frame
		await _hud_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trajectory":trajectory,"display":DisplayServer.get_name()}, "\t"))
	get_tree().quit(1 if failures else 0)

func _hud_flow() -> void:
	_completed()
	sm._active_save_path = "user://save.json"
	_check(sm.save(), "保存本分辨率前置")
	await _open_scene()
	await _settle()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	_check(not hud.gold_counter.visible and hud.reputation_counter.is_visible_in_tree(), "未获币餐厅隐藏金币且保留已结算声望")
	_counter(hud.reputation_counter, sm.reputation(), "reputation.png")
	_group(tracker, [hud.reputation_counter, hud.gold_counter])
	var settled: Dictionary = sm.data.duplicate(true)
	sm.data.erase(sm.FIRST_ORDER_SETTLEMENT_KEY)
	await _settle()
	_check(not hud.reputation_counter.visible, "无首单结算凭证时即使有声望也隐藏")
	sm.data = settled
	await _settle()
	await _shot("restaurant_before_gold")
	await _home_check(0, false)
	await _enter_from_restaurant()
	_check(maze.gold_counter.is_visible_in_tree() and maze.find_children("ReputationCounter", "", true, false).is_empty(), "迷宫未获币也显示金币且没有声望组件")
	_counter(maze.gold_counter, 0, "gold.png")
	_group(maze.task_tracker, [maze.gold_counter])
	await _shot("maze_before_gold")
	var trunk: PackedVector2Array = Roads.roads()[0].points
	await _route(trunk.slice(1,8), "hud_to_first_chest")
	await _move_to(Vector2(750,352), "hud_first_chest")
	opened = 0
	await _collect("entry_corridor_north", true)
	await _settle()
	_check(maze.gold_counter.is_visible_in_tree() and sm.is_gold_display_unlocked(), "成功开箱关闭弹窗后金币随任务恢复显示")
	_counter(maze.gold_counter, 100, "gold.png")
	_group(maze.task_tracker, [maze.gold_counter])
	await _shot("maze_after_gold")
	await _click(maze.task_tracker._task_button)
	_check(maze.task_tracker._expanded, "金币不阻挡任务按钮展开")
	await _click(maze.map_ui.mini_button)
	await _settle()
	_check(maze.map_ui.expanded and not maze.gold_counter.is_visible_in_tree() and not maze.task_tracker._task_button.is_visible_in_tree(), "大地图同隐藏金币与任务")
	await _shot("maze_map_hides_currency")
	await _send_key(KEY_ESCAPE)
	await _settle()
	_check(not maze.player.input_locked and maze.gold_counter.is_visible_in_tree(), "关闭大地图输入与金币恢复")
	# 沿原道路返回石门，执行真实二次确认和跨场景转场。
	await _move_to(trunk[7], "hud_return_corridor")
	await _route(_reversed(trunk.slice(0,8)), "hud_return_gate")
	await _send_key(KEY_E)
	await _settle()
	_check(maze.confirmation.visible and not maze.gold_counter.is_visible_in_tree(), "通行确认同步隐藏金币与任务")
	await _shot("maze_confirmation")
	await _send_key(KEY_ESCAPE)
	await _settle()
	_check(not maze.player.input_locked and maze.gold_counter.is_visible_in_tree(), "取消通行恢复金币与输入")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")) and not Transition.is_active(get_tree()), 240), "携带金币实际返回餐厅")
	scene = get_tree().current_scene
	maze = null
	await _settle()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	tracker = get_tree().get_first_node_in_group("order_tracking")
	_counter(hud.gold_counter, 100, "gold.png")
	_check(hud.gold_counter.is_visible_in_tree() and hud.reputation_counter.is_visible_in_tree(), "餐厅同时显示声望与金币")
	_check(hud.reputation_counter.get_global_rect().end.x < hud.gold_counter.get_global_rect().position.x, "声望在金币左侧且互不重叠")
	_group(tracker, [hud.reputation_counter, hud.gold_counter])
	await _shot("restaurant_after_gold")
	await _home_check(100, true)
	sm.data.gold = 0
	_check(sm.save(), "等价消费零余额夹具落盘")
	sm.load_data()
	await _settle()
	_check(hud.gold_counter.is_visible_in_tree() and hud.gold_counter.value_label.text == "0", "餐厅获得后归零重载仍显示0")
	await _enter_from_restaurant()
	await _settle()
	_check(maze.gold_counter.is_visible_in_tree() and maze.gold_counter.value_label.text == "0", "再次进入迷宫零余额仍显示")
	await _shot("maze_zero_balance")
	await _close_scene()
	maze = null

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _counter(counter, value: int, icon_file: String) -> void:
	_check(counter.value_label.text == str(value) and counter.icon.texture.resource_path.ends_with(icon_file), "图标与实时数值：" + icon_file)
	_check(counter.icon.size == Vector2(36,36) and counter.icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and counter.icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "图标36像素等比平滑：" + icon_file)
	_check(counter.value_label.get_theme_font_size("font_size") == 18, "数值字号18：" + icon_file)
	_check(counter.mouse_filter == Control.MOUSE_FILTER_IGNORE and counter.value_label.mouse_filter == Control.MOUSE_FILTER_IGNORE and counter.icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "资源组件不拦截输入")
	_check(counter.find_children("*", "Label", true, false).size() == 1, "常驻只含数值无资源名称")

func _group(tracker, counters: Array) -> void:
	for counter in counters:
		_check(counter.get_parent() == tracker._task_button.get_parent() and counter.get_canvas_layer_node() == tracker._task_button.get_canvas_layer_node() and counter.z_index == tracker._task_button.z_index, "计数器与任务按钮同父同画布同绘制层")
		_check(not counter.get_global_rect().intersects(tracker._task_button.get_global_rect()), "计数器不重叠任务按钮")
		_check(absf(counter.get_global_rect().get_center().y - tracker.entry_rect().get_center().y) < 1.0, "计数器与任务入口垂直居中")
	tracker.modulate.a = 0.4
	for counter in counters:
		_check(counter.modulate.a == tracker._task_button.modulate.a and counter.self_modulate.a == tracker._task_button.self_modulate.a, "共同继承父级透明度")
	tracker.modulate.a = 1.0
	tracker.hide()
	for counter in counters:
		_check(not counter.is_visible_in_tree(), "任务节点隐藏时资源同步隐藏")
	tracker.show()

func _home_check(amount: int, switch_slots: bool) -> void:
	var player = scene.get_node("Player")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().physics_frame
	await _settle()
	await _click(get_tree().get_first_node_in_group("ui_layer")._buttons[target])
	await _settle()
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(is_instance_valid(page), "鼠标进入真实冒险者之家")
	if not is_instance_valid(page): return
	_counter(page.gold_counter, amount, "gold.png")
	_check(page.gold_counter.is_visible_in_tree() and page.gold_counter.get_global_rect().position.x > page.back_button.get_global_rect().end.x and not page.gold_counter.get_global_rect().intersects(page.back_button.get_global_rect()), "之家始终显示金币且位于返回按钮右侧")
	_check(absf(page.gold_counter.get_global_rect().get_center().y - page.back_button.get_global_rect().get_center().y) < 1.0, "之家金币与返回按钮垂直居中")
	_check(page.find_children("ReputationCounter", "", true, false).is_empty() and page.find_children("TaskPanel", "", true, false).is_empty(), "之家没有餐厅任务或声望")
	await _shot("home_gold_" + str(amount))
	await _click(page.character_buttons.yaya)
	await _settle()
	_check(page.cards_modal.visible and page.cards_modal.get_canvas_layer_node().layer > page.gold_counter.get_canvas_layer_node().layer and page.back_button.disabled, "卡牌详情位于金币上方且隔离返回输入")
	await _shot("home_details_" + str(amount))
	await _send_key(KEY_ESCAPE)
	_check(not page.cards_modal.visible and not page.back_button.disabled, "关闭详情恢复页面输入")
	if switch_slots:
		DirAccess.make_dir_recursive_absolute("user://saves")
		var prior := "user://saves/hud-flow-old.json"
		_check(sm._write_atomic(prior, sm.data), "保存换档夹具")
		_check(sm.create_new_game().success, "真实创建新槽")
		await _settle()
		_check(page.gold_counter.value_label.text == "0" and not sm.is_gold_display_unlocked(), "同一个之家实例换新档实时显示0且不串资格")
		_check(sm.load_save_slot(prior).success, "真实切回获币旧槽")
		await _settle()
		_check(page.gold_counter.value_label.text == str(amount) and sm.is_gold_display_unlocked(), "同一个之家实例切回恢复实际金币")
	await _click(page.back_button)
	await _settle()
	_check(get_tree().get_nodes_in_group("adventurer_home").is_empty() and player.can_process() and not player.input_locked, "点击返回原餐厅并恢复输入")
	await _send_key(KEY_E)
	await _settle()
	page = get_tree().get_first_node_in_group("adventurer_home")
	_check(is_instance_valid(page) and page.gold_counter.value_label.text == str(amount) and page.find_children("GoldCounter", "", true, false).size() == 1, "重开之家数值正确且无重复组件")
	await _send_key(KEY_ESCAPE)
	await _settle()
	_check(get_tree().get_nodes_in_group("adventurer_home").is_empty() and player.can_process(), "Esc再次返回且恢复输入")

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(maze) and maze.loot_modal.visible:
		_check(not maze.gold_counter.is_visible_in_tree() and not maze.task_tracker._task_button.is_visible_in_tree(), "奖励弹窗同步隐藏任务和金币：" + label)
		_check(sm.is_gold_display_unlocked(), "奖励入账资格已解锁但仍服从任务父层")
	if label == "save_failure_retryable":
		_check(not sm.is_gold_display_unlocked() and maze.gold_counter.is_visible_in_tree() and maze.gold_counter.value_label.text == "0", "真实开箱写入失败仍显示金币0且不解锁餐厅资格")
	await super._shot(label)
