extends "res://tools/tests/maze_capture.gd"
const FS = preload("res://data/maze/fenshui_roads.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	var expected_path := "user://fenshui_expected.json"
	if not FileAccess.file_exists(expected_path):
		_completed()
		sm.cancel_maze_entry()
		sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		_check(Run.begin(sm,Roads.SPAWN).success,"建立同次探索")
		sm.data[Run.KEY].combat.hp = 17
		sm.data[Run.KEY].bag = {"slime_gel":2}
		_check(Run.change_region(sm,"fenshui",Vector2(920,440)).success,"保存分水庭水中站位")
		var expected := {"run":Run.snapshot(sm),"stamina":sm.stamina_snapshot().value,"position":sm.maze_exploration_state().position}
		FileAccess.open(expected_path,FileAccess.WRITE).store_string(JSON.stringify(expected))
	else:
		sm._active_save_path = "user://chapter-ending-test.json"
		sm.load_data()
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		_check(_same_saved(Run.snapshot(sm),expected.run),"独立进程保留整趟探索")
		_check(sm.resume_scene_path()=="res://scenes/maze_fenshui.tscn","新进程恢复场景路径")
		maze = load(sm.resume_scene_path()).instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.3).timeout
		maze.capture_flow.window_focused = true
		_check(maze._entry_ready and maze.region_id=="fenshui" and maze.player.position.distance_to(Vector2(920,440))<0.1,"新进程真实场景恢复水中位置")
		_check(Run.snapshot(sm).combat.hp==17 and Run.snapshot(sm).bag==expected.run.bag and sm.stamina_snapshot().value==expected.stamina,"重启不刷新生命携物或重复扣体力")
		await _capture_image("restart_water")
		maze.capture_flow.set_process(false)
		var start := Vector2(725,440)
		var phases: Array[float] = []
		maze.player.position = start
		Input.action_press("ui_right")
		for i in 32:
			var multiplier := FS.terrain_multiplier(maze.player.position)
			if phases.is_empty() or phases.back()!=multiplier: phases.append(multiplier)
			var before: Vector2 = maze.player.position
			maze.player._physics_process(0.05)
			_check(absf(maze.player.position.distance_to(before)-130*0.05*multiplier)<0.02,"连续水岸移动速度"+str(i))
		Input.action_release("ui_right")
		_check(phases==[0.65,1.0,0.65],"连续移动从水到路再到水，无倍率累积",{"phases":phases})
		maze.player.position = Vector2(920,440)
		var previous: Dictionary = sm.data.duplicate(true)
		sm.data.maze_exploration.position = [-100,-100]
		_check(sm.maze_exploration_state().region=="fenshui" and sm.maze_exploration_state().position==[FS.SPAWN.x,FS.SPAWN.y],"坏坐标回本区域入口")
		sm.data = previous
		maze.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
