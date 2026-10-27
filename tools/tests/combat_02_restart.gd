extends "res://tools/tests/maze_capture.gd"
const Combat = preload("res://scripts/maze/combat_simulation.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		if _arg("--phase=")=="seed":
			_completed()
			sm.cancel_maze_entry()
			sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
			_check(Run.begin(sm,Roads.SPAWN).success,"新趟建立")
			var c: Dictionary=sm.data[Run.KEY].combat
			c.hp=17
			c.actors.slime_1.hp=0
			c.actors.slime_2.hp=0
			c.actors.snail_1.mode="windup"
			c.actors.snail_1.windup=0.25
			c.actors.snail_2.mode="return"
			c.actors.snail_2.hp=5
			c.shots=[{"origin":[995,225],"target":[933,269],"position":[970,242],"time":0.14}]
			_check(Run.defeat(sm,"slime_1",Roads.SPAWN).success,"首只待捕获与第二只待结算同时保存")
			var file := FileAccess.open("user://combat_expected.json",FileAccess.WRITE)
			file.store_string(JSON.stringify(Run.snapshot(sm)))
		else:
			sm._active_save_path="user://chapter-ending-test.json"
			sm.load_data()
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://combat_expected.json"))
			_check(_same_saved(Run.snapshot(sm),expected),"新进程加载生命前摇返航飞行与待捕获完全一致")
			maze=load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze)
			get_tree().current_scene=maze
			await get_tree().create_timer(0.7).timeout
			_check(maze.capture_flow.dialog.visible and Run.snapshot(sm).pending=="slime_1","重开实际迷宫恢复待捕获窗")
			_check(Run.snapshot(sm).combat.hp==17 and Run.snapshot(sm).combat.actors.snail_2.hp==5,"重开不刷主角或返航怪血量")
			await _capture_image("restart_pending")
			await _click(maze.capture_flow.dialog._cancel_button)
			await get_tree().create_timer(0.7).timeout
			_check(Run.snapshot(sm).pending=="slime_2" and maze.capture_flow.dialog.visible,"同时死亡第二只逐个处理")
			await _click(maze.capture_flow.dialog._cancel_button)
			await get_tree().create_timer(0.5).timeout
			_check(Run.snapshot(sm).monsters.slime_1.status=="skipped" and Run.snapshot(sm).monsters.slime_2.status=="skipped","两个结算仅执行一次")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
