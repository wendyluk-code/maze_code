extends "res://tools/tests/elder_01_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(OS.get_user_data_dir().replace("\\", "/").contains("/output/yf_01/"), "隔离存档")
	_seed()
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.2).timeout
	# 合法路口右缘首次向北走过，距旧圆心18像素，旧12像素圈会漏掉。
	maze.player.position = Vector2(410, 724)
	maze.camera.snap_to_target()
	_check(Roads.is_walkable(maze.player.position), "路口边缘起点合法")
	_set_keys([KEY_W])
	for i in 60:
		await get_tree().physics_frame
		if maze.yufeng_salia.is_busy() or maze.player.position.y <= 694: break
	_set_keys([])
	_check(maze.yufeng_salia.is_busy(), "首次沿路口边缘行走立即触发")
	print("YF_FIRST_PASS position=", maze.player.position, " phase=", maze.yufeng_salia.phase)
	if not maze.yufeng_salia.is_busy():
		maze.player.position = Vector2(392,694)
		maze.yufeng_salia.trigger()
	await get_tree().create_timer(1.0).timeout
	var event = maze.yufeng_salia
	for line in [0, 3]:
		event._show_line(line)
		event._dialog._advance()
		await _shot("portrait_" + str(line))
		_check(event._dialog.portrait_texture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "头像铺满内框：" + str(line))
		_check(event._dialog.portrait.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "头像按圆角框裁切：" + str(line))
		_check(event._dialog.portrait.has_node("PortraitBorder"), "边框在头像上层：" + str(line))
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(1.0).timeout
	_check(event.phase == "unseen" and not maze.player.input_locked, "取消后留在圈内不重播")
	# 使用真实方向输入离圈再进入。
	_set_keys([KEY_S])
	for i in 40:
		await get_tree().physics_frame
		if maze.player.position.distance_to(event.TRIGGER_POS) > 38: break
	_set_keys([])
	_set_keys([KEY_W])
	for i in 50:
		await get_tree().physics_frame
		if event.is_busy(): break
	_set_keys([])
	_check(event.is_busy(), "离圈后首次重新进入触发")
	await get_tree().create_timer(1.0).timeout
	await _key(KEY_ESCAPE)
	# 保存失败不能永久消耗本次进入；修复保存路径后无需绕圈即可重试。
	maze.player.position = Vector2(410,724)
	await get_tree().create_timer(0.1).timeout
	maze._busy = true
	maze.player.position = Vector2(410,694)
	await get_tree().create_timer(0.1).timeout
	_check(event.phase == "unseen", "其他模态流程占用时不抢登场")
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	maze._busy = false
	await get_tree().create_timer(0.1).timeout
	_check(event.phase == "unseen" and not maze.player.input_locked, "首次保存失败不锁住玩家")
	sm._active_save_path = save_path
	await get_tree().create_timer(1.2).timeout
	_check(event.is_busy(), "保存恢复后圈内有界重试无需绕行")
	await get_tree().create_timer(1.0).timeout
	await _key(KEY_ESCAPE)
	_finish()
