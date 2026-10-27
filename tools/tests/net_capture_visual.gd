extends "res://tools/tests/elder_01_flow.gd"
const Run = preload("res://scripts/maze/capture_run.gd")
func _walkthrough() -> void:
	_seed(0)
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.2).timeout
	maze.exploration_guide.set_process(false)
	maze.capture_flow.set_process(false)
	var ui = maze.capture_flow.attempt
	for id in ["slime_1","snail_1","beetle_1","lizard_1"]:
		ui.present(Run.monster_for(Run.snapshot(sm),id),Run.snapshot(sm),true,3)
		ui.set_process(false)
		ui.intro_time = 2
		ui._process(0)
		_check(ui.rope.t == 0, id+"重开恢复左下角网团")
		ui.start()
		ui._process(0.55)
		_check(ui.mode == "throw" and ui.rope.t > 0.65 and ui.rope.t < 2.25, id+"空中展开")
		await _shot(id+"_throw")
		ui._process(0.56)
		_check(ui.mode == "restrain",id+"按原时序进入牵制")
		await _shot(id+"_restrain")
		for u in [0.0,0.5,1.0]:
			for v in [0.0,0.5,1.0]:
				var point: Vector2 = ui.rope.point(u,v)
				_check(Rect2(0,70,400,350).has_point(point),id+"网罩不铺满画面或遮住名称/J")
		ui._process(1.5)
		_check(ui.mode == "suppress",id+"进入镇压")
		ui.tutorial_paused = true
		var previous: float = ui.rope.t
		ui._process(1)
		_check(ui.rope.t == previous,id+"教学暂停冻结网动画")
		ui.tutorial_paused = false
		ui.pulse = 1
		ui._process(0.05)
		await _shot(id+"_suppress")
		ui.result_passed = true
		ui.mode = "complete"
		ui.phase_time = 0
		ui._process(0.1)
		_check(ui.rope.t >= 6.6,id+"成功收网光效")
		await _shot(id+"_complete")
		ui.close()
		_check(not ui.visible,id+"关闭清理")
	await _close_maze()
