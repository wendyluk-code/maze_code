extends "res://tools/tests/maze_capture.gd"
const STAGES := ["intro","eat","question","battle","post","gift_pending"]
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"跨进程隔离正式存档")
	var mode := OS.get_environment("YF02_RESTART")
	if failures==0:
		if mode=="seed":
			_completed()
			sm.cancel_maze_entry()
			sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
			_check(Run.begin(sm,Roads.SPAWN).success,"建立真实出征")
			sm.record_maze_location("fenshui",Vector2(1300,325))
			for phase in STAGES:
				sm._active_save_path="user://yf02_"+phase+".json"
				var record: Dictionary={"version":2,"phase":phase,"line":1 if phase in ["intro","post"] else 0}
				if phase=="battle":
					record.start_run=Run.snapshot(sm)
					record.start_position=[1300,325]
				_check(sm.set_yufeng_salia_record(record).success,"写盘并结束进程："+phase)
		else:
			for phase in STAGES:
				sm._active_save_path="user://yf02_"+phase+".json"
				sm.load_data()
				_check(sm.yufeng_salia_state()==phase,"新进程读取阶段："+phase)
				maze=load("res://scenes/maze_fenshui.tscn").instantiate()
				get_tree().root.add_child(maze)
				get_tree().current_scene=maze
				await get_tree().process_frame
				_check(maze.yf_encounter.phase==phase,"新进程真实场景恢复："+phase)
				if phase in ["intro","post"]: _check(maze.yf_encounter.record.line==1,"恢复准确对白句")
				if phase=="battle": _check(maze.yf_encounter.run.combat.hp==Run.snapshot(sm).combat.hp,"重新挑战恢复开战血量")
				maze.queue_free()
				await get_tree().process_frame
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
