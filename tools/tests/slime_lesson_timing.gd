extends "res://tools/tests/elder_01_flow.gd"
const Run = preload("res://scripts/maze/capture_run.gd")

func _walkthrough() -> void:
	_seed(0)
	sm.data[sm.MAZE_STATE_KEY] = sm._empty_maze_state()
	_check(Run.begin(sm, Roads.SPAWN).success, "建立隔离探索")
	# 固定道路站位以独立验证教学时序，不依赖随机出生布局。
	sm.data[Run.KEY].layout[0].position = [860.0,295.0]
	sm.data[Run.KEY].combat.layout = sm.data[Run.KEY].layout.duplicate(true)
	sm.data[Run.KEY].combat.actors.slime_1.position = [860.0,295.0]
	sm.data[Run.KEY].combat.hero = [1030.0,205.0]
	sm.data[sm.MAZE_STATE_KEY].position = [1030.0,205.0]
	for id in sm.data[Run.KEY].monsters:
		if id != "slime_1": sm.data[Run.KEY].monsters[id].status = "skipped"
	_check(Run.valid(Run.snapshot(sm)) and Roads.is_walkable(Vector2(1030,205)), "时序夹具状态与道路站位有效")
	# 本专项仅回归首次亮血条；新增喷射教学由 slime_spit_lesson 完整覆盖。
	sm.data.ch2_guide_01 = {"revision":2,"step":"explore","seen":{"05_switch":true,"05_guard":true,"05_spit_complete":true},"banked":{}}
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.1).timeout
	var g = maze.exploration_guide
	var flow = maze.capture_flow
	flow.window_focused = true
	maze.player.position = Vector2(1030,205)
	await get_tree().create_timer(0.1).timeout
	_check(not g.reading and not flow.monsters.slime_1.label.visible, "攻击范围外血条与教学都不显示")
	Input.action_press("ui_left")
	for frame in 90:
		await get_tree().physics_frame
		if flow.monsters.slime_1.label.visible: break
	Input.action_release("ui_left")
	_check(flow.monsters.slime_1.label.visible, "实际移动首次亮起slime_1血条")
	_check(maze.player.position.distance_to(flow.monsters.slime_1.position) > 150.0, "复现血条已亮但尚未进入150警戒半径")
	_check(g.reading and g.lesson_id == "05_power", "血条首次亮起的同帧弹攻击教学")
	if not g.reading:
		await _close_maze()
		return
	_check(sm.data[Run.KEY].combat.actors.slime_1.hp == 14, "教学发生在史莱姆未受伤时")
	await get_tree().create_timer(0.6).timeout
	await _key(KEY_E)
	await _shot("aggro_lesson")
	_check(g.guide.dim.visible and maze.player.input_locked, "蒙层与移动锁生效")
	var frozen: Dictionary = Run.snapshot(sm).combat
	await get_tree().create_timer(0.2).timeout
	_check(Run.snapshot(sm).combat == frozen, "阅读期间战斗完全暂停")
	await _finish_lesson(g)
	_check(not maze.player.input_locked and maze.player.is_physics_processing(), "关闭后恢复移动")
	_check(not flow.dialog.visible and sm.data[Run.KEY].combat.actors.slime_1.hp > 0, "关闭攻击教学不直接结算胜利")
	_check(sm.save(), "已读标记写盘")
	sm.load_data()
	_check(g._seen("05_power"), "读档保留已读标记")
	_check(not g.before_combat(Run.snapshot(sm)), "再次靠近不重播已读攻击教学")
	# 等价恢复样例：玩家先完成其他魔物的捕获教学，不能吞掉 slime_1 的转食材说明。
	sm.data.ch2_guide_01.seen["07_capture"] = true
	sm.data.ch2_guide_01.seen["11_suppress"] = true
	# 用真实鼠标输入击败目标，验证击败后的第二段教学。
	for attempt_index in 20:
		if flow.dialog.visible or g.reading: break
		var target := Run.Combat.vec(sm.data[Run.KEY].combat.actors.slime_1.position)
		maze.player.position = Roads.move_on_road(target, Vector2(55,-20))
		flow.window_focused = true
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = maze.get_viewport().get_canvas_transform() * target
			event.pressed = pressed
			get_viewport().push_input(event)
			await get_tree().process_frame
		await get_tree().create_timer(0.95).timeout
	await get_tree().create_timer(1.0).timeout
	_check(g.reading and g.lesson_id == "06_absorb", "首次击败slime_1播放转食材说明")
	await _shot("defeat_lesson")
	await _finish_lesson(g)
	_check(g._seen("06_absorb") and not g.reading, "转食材说明已读")
	await _close_maze()

func _finish_lesson(g: Node) -> void:
	for i in 6:
		if not g.reading: break
		await _key(KEY_E)
		await get_tree().create_timer(0.15).timeout
