extends "res://tools/tests/elder_01_flow.gd"

func _isolation() -> bool:
	return OS.get_user_data_dir().replace("\\", "/").contains("/output/yf_01/")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	evidence = _arg("--output-dir=")
	if evidence.is_empty(): evidence = "user://yf_01_screenshots"
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_isolation(), "实际用户目录隔离")
	_seed()
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.3).timeout
	_check(maze._entry_ready and not maze.player.input_locked, "迷宫真实场景就绪")
	maze.player.position = Roads.SPAWN
	maze.camera.snap_to_target()
	for point in [Vector2(1061,188),Vector2(995,225),Vector2(933,269),Vector2(860,295),Vector2(790,326),Vector2(725,369),Vector2(688,396),Vector2(613,421),Vector2(552,455),Vector2(534,499),Vector2(527,544),Vector2(497,578),Vector2(448,603),Vector2(413,646)]:
		await _move_to(point)
	_set_keys([KEY_S])
	for i in 60:
		await get_tree().physics_frame
		if maze.yufeng_salia.is_busy(): break
	_set_keys([])
	await get_tree().create_timer(1.2).timeout
	_check(maze.yufeng_salia.phase == "intro_pending" or maze.yufeng_salia.phase == "dialog", "实际行走进入事件")
	await _shot("yf_entry")
	if maze.yufeng_salia.phase == "dialog":
		await _key(KEY_ESCAPE)
		_check(maze.yufeng_salia.phase == "unseen" and not maze.player.input_locked and maze.player.is_physics_processing(), "对白Esc取消恢复输入")
		_set_keys([KEY_W])
		for i in 30:
			await get_tree().physics_frame
			if maze.player.position.distance_to(maze.yufeng_salia.TRIGGER_POS) > 38: break
		_set_keys([])
		_set_keys([KEY_S])
		for i in 50:
			await get_tree().physics_frame
			if maze.yufeng_salia.is_busy(): break
		_set_keys([])
		await get_tree().create_timer(1.2).timeout
		_check(maze.yufeng_salia.phase == "dialog", "取消后重新触发且旧timer未越代")
	var inputs := 0
	while maze.yufeng_salia.phase == "dialog" and inputs < 40:
		if int(maze.yufeng_salia._dialog.get_meta("yf_line", -1)) == 1:
			_check(maze.yufeng_salia._dialog.speaker_name.text == "你", "玩家对白署名为你")
			await _shot("yf_hero_named_you")
		await _key(KEY_SPACE if inputs % 2 else KEY_E)
		inputs += 1
	print("YF_DIALOG_PROGRESS phase=", maze.yufeng_salia.phase, " inputs=", inputs, " idx=", maze.yufeng_salia._dialog.get_meta("yf_line", -1))
	_check(maze.yufeng_salia.phase == "awaiting_battle", "五句对白由真实E输入推进")
	_check(sm.yufeng_salia_state() == "awaiting_battle", "待战状态原子保存")
	await _shot("yf_awaiting_battle")
	sm.load_data()
	_check(sm.yufeng_salia_state() == "awaiting_battle", "真实磁盘load保持待战")
	maze.queue_free()
	await get_tree().process_frame
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.25).timeout
	_check(maze.yufeng_salia.phase == "awaiting_battle" and not maze.yufeng_salia.is_busy(), "读档待战不重放且可移动")
	await _shot("yf_reload_waiting")
	_finish()
