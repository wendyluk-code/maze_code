extends "res://tools/tests/maze_capture.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		if OS.get_environment("COMBAT03_PHASE")=="seed":
			_completed(); sm.cancel_maze_entry()
			sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
			_check(Run.begin(sm,Roads.SPAWN).success,"新趟随机布局")
			var run:=Run.snapshot(sm)
			run.combat.hp=17
			run.combat.actors.slime_1.hp=0
			run.combat.actors.snail_1.hp=7
			run.combat.actors.snail_1.mode="return"
			run.maze_elapsed=31.25
			run.bag={"slime_gel":2}
			sm.data[Run.KEY]=run
			_check(Run.defeat(sm,"slime_1",Roads.SPAWN).success,"持久化待捕获和死亡截止")
			_check(Run.start_capture(sm,"slime_1").success,"持久化已付费捕获")
			var file:=FileAccess.open("user://combat_03_expected.json",FileAccess.WRITE)
			file.store_string(JSON.stringify(Run.snapshot(sm)))
		else:
			sm._active_save_path="user://chapter-ending-test.json"
			sm.load_data()
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://combat_03_expected.json"))
			_check(_same_saved(Run.snapshot(sm),expected),"跨进程布局HP随机源时钟pending已付费完整恢复")
			_check(Run.begin(sm,Roads.SPAWN).success and _same_saved(Run.snapshot(sm),expected),"重进不重抽不刷血不计离线时间")
			var food: float=Run.snapshot(sm).satiety
			_check(Run.start_capture(sm,"slime_1").get("resumed",false) and Run.snapshot(sm).satiety==food,"跨进程已付费不重扣")
			maze=load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze); get_tree().current_scene=maze
			await get_tree().create_timer(0.5).timeout
			_check(maze.capture_flow.attempt.visible or maze.capture_flow.dialog.visible,"真实迷宫恢复进行中捕获")
			_check(Run.snapshot(sm).maze_elapsed==31.25 and Run.snapshot(sm).combat.hp==17 and Run.snapshot(sm).combat.actors.snail_1.hp==7,"捕获暂停保留运行时钟与双方残血")
			await _capture_image("restart_paid_pending")
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
