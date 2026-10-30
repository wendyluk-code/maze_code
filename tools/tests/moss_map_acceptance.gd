extends "res://tools/tests/moss_pool_flow.gd"
## 补齐青苔池独立进程恢复；复用真实入口、碰撞和双分辨率验收。
func _run() -> void:
	if OS.get_environment("MOSS_MAP_RESTORE") != "1":
		await super._run()
		return
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		_check(sm.resume_scene_path()=="res://scenes/maze_moss_pool.tscn","独立新进程恢复青苔池场景")
		var expected = JSON.parse_string(FileAccess.get_file_as_string("user://moss-map-expected.json"))
		_check(expected is Dictionary and _same_saved(_snapshot(),expected),"独立新进程保留位置队伍背包怪物饱腹生命体力")
		maze=load(sm.resume_scene_path()).instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene=maze
		await get_tree().create_timer(1.5).timeout
		maze.capture_flow.set_process(false)
		_check(maze._entry_ready and maze.player.position.distance_to(Vector2(1050,950))<0.1,"新进程实际进入原图道路站位")
		_check(not sm.record_maze_location("moss_pool",Vector2(770,800)).success,"恢复后仍拒绝水中站位")
		maze.camera.snap_to_target()
		await _capture_image("09_moss_restart")
		await _close_scene()
	var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _snapshot() -> Dictionary:
	var run: Dictionary=Run.snapshot(sm)
	return {"location":sm.maze_exploration_state(),"members":run.members,"bag":run.bag,"monsters":run.monsters,"satiety":run.satiety,"hp":run.combat.hp,"stamina":sm.stamina_snapshot().value}

func _combat_scene() -> void:
	await super._combat_scene()
	await _new_scene()
	_check(sm.set_yufeng_salia_state("done").success,"恢复样例剧情前置")
	maze.travel_region("moss_pool",Vector2(1050,950))
	await get_tree().create_timer(1.5).timeout
	maze=get_tree().current_scene
	maze.capture_flow.set_process(false)
	_check(maze.region_id=="moss_pool" and maze._save_position(),"保存独立进程恢复样例")
	var file=FileAccess.open("user://moss-map-expected.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(_snapshot()))
	file.close()
	await _close_scene()
