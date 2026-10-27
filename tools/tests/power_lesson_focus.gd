extends "res://tools/tests/elder_01_flow.gd"
func _walkthrough() -> void:
	_seed(0)
	sm.data[sm.MAZE_STATE_KEY] = sm._empty_maze_state()
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.3).timeout
	var lesson = maze.exploration_guide
	_check(not lesson.reading and not maze.player.input_locked, "进场不播战力对白且可移动")
	var before: Vector2 = maze.player.position
	Input.action_press("ui_left")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_left")
	_check(maze.player.position.distance_to(before) > 0, "进场实际方向输入可移动")
	var monster = maze.capture_flow.monsters.slime_1
	maze.player.position = monster.position + Vector2(40, 0)
	await get_tree().create_timer(0.7).timeout
	_check(lesson.reading and lesson.lesson_id == "05_power", "靠近史莱姆触发战力教学")
	_check(not maze.capture_flow.dialog.visible and monster.visible, "教学先于击败弹窗且魔物仍在场")
	await _key(KEY_E)
	await get_tree().process_frame
	_check(lesson.guide.external_circles and lesson.guide.external_cutouts.size() == 2, "两个战力数字圆形挖空")
	_check(lesson.guide.dialog.dialog_text.get_global_rect().end.x < lesson.guide.dialog.next_icon.get_global_rect().position.x, "正文右缘避让E")
	await _shot("power_focus")
	await _key(KEY_E)
	await get_tree().create_timer(0.1).timeout
	_check(maze.capture_flow.dialog.visible, "结束战力教学后显示战斗弹窗")
	await _close_maze()
