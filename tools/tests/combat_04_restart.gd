extends "res://tools/tests/combat_04_flow.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		if OS.get_environment("COMBAT04_PHASE")=="seed":
			_setup()
			for id in sm.data[Run.KEY].monsters:
				if id!="slime_1":
					sm.data[Run.KEY].monsters[id].status="skipped"
					sm.data[Run.KEY].monsters[id].respawn_at=99999.0
			sm.save()
			maze=load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze); get_tree().current_scene=maze
			await get_tree().create_timer(0.3).timeout
			await _fight("restart_seed")
			_check(_exp("yaya")==20 and _exp("tieshan")==20,"跨进程前实际击杀经验已提交")
			var file:=FileAccess.open("user://combat04_expected.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"run":Run.snapshot(sm),"progression":sm.data[Progression.KEY]}))
		else:
			sm._active_save_path="user://chapter-ending-test.json"; sm.load_data()
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://combat04_expected.json"))
			_check(_same_saved(Run.snapshot(sm),expected.run) and _same_saved(sm.data[Progression.KEY],expected.progression),"新进程完整恢复经验与击杀同一事务")
			maze=load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze); get_tree().current_scene=maze
			await get_tree().create_timer(0.8).timeout
			_check(maze.capture_flow.dialog.visible and _exp("yaya")==20,"新进程待捕获不重发")
			await _click(maze.capture_flow.dialog._cancel_button)
			await get_tree().create_timer(0.4).timeout
			_check(_exp("yaya")==20 and not Run.defeat(sm,"slime_1",Roads.SPAWN).success,"新进程放弃与重复结算不重发")
			await _capture_image("restart_restored")
	_report()
