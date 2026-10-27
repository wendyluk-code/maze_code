extends "res://tools/tests/elder_01_flow.gd"
const Run = preload("res://scripts/maze/capture_run.gd")
func _walkthrough() -> void:
	_seed(0)
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.2).timeout
	var lesson = maze.exploration_guide
	sm.data["ch2_guide_01"] = {"step":"explore","seen":{},"banked":{}}
	lesson.set_process(false)
	var flow = maze.capture_flow
	flow.set_process(false)
	flow.attempt.present(Run.monster_for(Run.snapshot(sm), "slime_1"), Run.snapshot(sm), true, 3)
	flow.attempt.tutorial_paused = true
	for id in lesson.LINES:
		lesson.explain(id, lesson.LINES[id], [])
		_check(lesson.guide.dim.visible and is_equal_approx(lesson.guide.dim.color.a, 0.72), id + "对白出现同帧蒙层72%")
		_check(lesson.layer > 65, id + "蒙层高于捕获弹窗")
		lesson.guide.dialog._advance()
		await get_tree().process_frame
		await _shot(id)
		lesson._clear()
		_check(not lesson.guide.dim.visible, id + "结束清除蒙层")
	lesson.operation("yes", "", [flow.attempt.yes_button])
	_check(lesson.guide.dim.visible and is_equal_approx(lesson.guide.dim.color.a, 0.72) and lesson.guide.external_cutouts.size() == 1, "只能选是蒙层同帧建立")
	lesson._clear()
	await _close_maze()

