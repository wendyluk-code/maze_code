extends "res://tools/tests/home_character_details.gd"

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
			_check(not debug.panel.visible, "默认隐藏")
			for digit in "78719": debug._digit(digit)
			_check(not debug.panel.visible, "错误暗号不打开")
			await _type_code()
			_check(debug.panel.visible and get_tree().paused, "暗号打开并暂停")
			var gold: int = sm.gold_balance()
			debug.amount.value = 17
			for button in debug.panel.find_children("*", "Button", true, false):
				if button.text == "增加金币": await _click(button)
			_check(sm.gold_balance() == gold + 17, "实际点击按钮按输入数量加金币")
			gold += 17
			_check(debug.grant("gold", 123).success and sm.gold_balance() == gold + 123, "加金币真实生效")
			var dust: int = sm.stardust_balance()
			_check(debug.grant("dust", 45).success and sm.stardust_balance() == dust + 45, "加星尘真实生效")
			var saved: Dictionary = sm.data.duplicate(true)
			var path: String = sm._active_save_path
			sm._active_save_path = ""
			_check(not debug.grant("gold", 1).success and sm.data == saved, "保存失败回滚")
			sm._active_save_path = path
			sm.load_data()
			_check(sm.gold_balance() == gold + 123 and sm.stardust_balance() == dust + 45, "读档保留调试货币")
			sm.data[Progression.FOOD_KEY] = {"values": {"yaya":0.0,"tieshan":0.0}, "at":Time.get_unix_time_from_system(), "paused":true}
			_check(debug.grant("food", 1).success, "增加队伍饱腹度")
			var food := Progression.satiety_snapshot(sm)
			_check(is_equal_approx(float(food.values.yaya) + float(food.values.tieshan), 1.0), "增加量按全队总量分配")
			_check(debug.grant("fill_food", 1).success, "一键补满")
			food = Progression.satiety_snapshot(sm)
			_check(food.values.yaya == 2 and food.values.tieshan == 1, "不超过角色上限")
			_check(not debug.grant("gold", -1).success, "拒绝负数")
			await _shot("debug_restaurant")
			await _send_key(KEY_ESCAPE)
			_check(not debug.panel.visible and not get_tree().paused and scene.get_node("Player").can_process(), "Esc关闭恢复输入")
			var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
			var player = scene.get_node("Player")
			player.position = _stand(target)
			player.last_valid = player.position
			await get_tree().physics_frame
			await get_tree().process_frame
			await _click(get_tree().get_first_node_in_group("ui_layer")._buttons[target])
			var page = get_tree().get_first_node_in_group("adventurer_home")
			await _click(page.character_buttons.yaya)
			for digit in "78789": debug._digit(digit)
			await _shot("debug_over_details")
			await _send_key(KEY_ESCAPE)
			_check(not debug.panel.visible and page.cards_modal.visible, "Esc只关闭调试面板保留原详情")
			await _send_key(KEY_ESCAPE)
			await _click(page.back_button)
			await _close_scene()
		get_tree().paused = true
		debug.open_panel()
		debug.close_panel()
		_check(get_tree().paused, "保留原暂停状态")
		get_tree().paused = false
		sm.begin_replay()
		_check(not debug.grant("gold", 1).success, "重播不污染正式档")
		sm.end_replay()
		var start_scene = load("res://scenes/start_screen.tscn").instantiate()
		get_tree().root.add_child(start_scene)
		await get_tree().process_frame
		await _type_code()
		_check(debug.panel.visible, "主菜单可按数字键唤出")
		await _shot("debug_start_screen")
		debug.close_panel()
		start_scene.queue_free()
		await get_tree().process_frame
		var Run = load("res://scripts/maze/capture_run.gd")
		var Roads = load("res://data/maze/entry_roads.gd")
		_check(Run.begin(sm, Roads.SPAWN).success, "建立真实探索")
		sm.data[Progression.FOOD_KEY].values = {"yaya":0.0, "tieshan":0.0}
		sm.data[Run.KEY].satiety = 0.0
		sm.save()
		var maze = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		await get_tree().process_frame
		await _type_code()
		_check(debug.panel.visible, "迷宫按数字键唤出")
		_check(debug.grant("fill_food", 1).success, "探索中补满成功")
		_check(Run.snapshot(sm).satiety == 3, "探索队伍总量同步为3")
		debug.close_panel()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(maze.capture_flow.party_food.text == "3/3", "迷宫HUD同步真实饱腹度")
		await _type_code()
		await _shot("debug_maze")
		debug.close_panel()
		maze.queue_free()
		await get_tree().process_frame
	FileAccess.open(_arg("--report="), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _type_code() -> void:
	for digit in [7,8,7,8,9]:
		var event := InputEventKey.new()
		event.keycode = KEY_0 + digit
		event.physical_keycode = KEY_0 + digit
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame
