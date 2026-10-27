extends "res://tools/tests/chapter_ending_input.gd"
const Roads := preload("res://data/maze/entry_roads.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_geometry()
		_persistence()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("CH2_STATE ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _geometry() -> void:
	_check(Roads.is_walkable(Roads.SPAWN), "石门脚底圆可站立")
	_check(not Roads.is_walkable(Roads.SPAWN, 100.0), "大于道路半宽的脚底不能站立")
	for road in Roads.roads():
		var points: PackedVector2Array = road.points
		for i in range(points.size() - 1):
			var from: Vector2 = points[i]
			var to: Vector2 = points[i + 1]
			if to.x == 0:
				to = Roads.EXIT
			var actual := Roads.move_on_road(from, to - from)
			_check(actual.distance_to(to) < 0.1, "脚底半径连续路段：%s → %s" % [from, to], {"actual": str(actual)})
	for obstacle in [Vector2(460,320), Vector2(674,529), Vector2(960,817), Vector2(727,791), Vector2(450,902), Vector2(654,1110), Vector2(622,1100), Vector2(682,1103)]:
		_check(not Roads.is_walkable(obstacle), "树林/沟壑/栅栏不可站立：" + str(obstacle))
	for probe in [[Vector2(527,544),Vector2(1086,755)], [Vector2(633,851),Vector2(1134,869)], [Vector2(653,1064),Vector2(650,1160)]]:
		var actual := Roads.move_on_road(probe[0], probe[1] - probe[0])
		_check(actual.distance_to(probe[1]) > 30 and Roads.is_walkable(actual), "大步长/斜向不能穿过障碍："+str(probe), {"actual": str(actual)})
	_check(not Roads.is_walkable(Vector2(0,695)) and Roads.is_walkable(Roads.EXIT), "脚底不能跨图边缘但出口提示可达")

func _completed() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]:
		_check(sm.advance_chapter_1_outro(checkpoint).success, "完整第一章前置：" + checkpoint)

func _persistence() -> void:
	sm.data = sm._defaults()
	_check(not sm.record_maze_location("maze_entry", Roads.SPAWN).success, "未完成第一章不能开始第二章")
	_completed()
	var original: Dictionary = sm.data.duplicate(true)
	_check(sm.resume_scene_path() == sm.RESTAURANT_SCENE, "旧进度继续餐厅")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not sm.record_maze_location("maze_entry", Roads.SPAWN).success and sm.data == original, "首次进入保存失败全量回滚")
	sm._active_save_path = path
	var result: Dictionary = sm.record_maze_location("maze_entry", Roads.SPAWN)
	_check(result.success and result.created, "首次实际进入记录开始")
	_check(not sm.record_maze_location("maze_entry", Roads.SPAWN).created, "重复进入不重复开始")
	_check(not sm.record_maze_location("maze_entry", Vector2(650,530)).success, "无效站位拒绝写盘")
	var point := Vector2(1134,869)
	_check(sm.record_maze_location("maze_entry",point).success, "合法远端站位保存")
	sm.load_data()
	_check(sm.maze_exploration_state().position == [point.x,point.y] and sm.resume_scene_path() == sm.MAZE_SCENE, "重载恢复区域和站位")
	_check(sm.reputation() == original.reputation and sm.inventory_snapshot() == original.inventory and not sm.data.get("chapter_2_done",false), "探索不奖励不完章")
	_check(sm.quest_snapshot().active.any(func(q): return q.id == "chapter_1_salt_pool"), "盐池探索仍进行中")
	_check(sm.record_maze_location("restaurant",point).success, "返回餐厅保存")
	sm.load_data()
	_check(sm.resume_scene_path() == sm.RESTAURANT_SCENE and sm.maze_exploration_state().chapter_2_started, "返回不清除第二章开始记录")
	sm.data.erase("maze_exploration")
	_check(sm.save(), "写入无新字段旧档")
	var old_bytes := FileAccess.get_file_as_bytes(path)
	sm.load_data()
	_check(sm.resume_scene_path() == sm.RESTAURANT_SCENE and FileAccess.get_file_as_bytes(path) == old_bytes, "旧档只读迁移不写盘")
	for malformed in [null, {"version":2}, {"version":1,"region":"unknown","chapter_2_started":true}, {"version":1,"region":"maze_entry","chapter_2_started":false,"position":[1104,153]}]:
		sm.data.maze_exploration = malformed
		_check(sm.resume_scene_path() == sm.RESTAURANT_SCENE, "损坏结构或未知区域回餐厅")
	for position in [null, ["x",153], [650,530], [INF, NAN], []]:
		sm.data.maze_exploration = {"version":1,"region":"maze_entry","chapter_2_started":true,"position":position}
		var state: Dictionary = sm.maze_exploration_state()
		_check(state.region == "maze_entry" and state.position == [Roads.SPAWN.x,Roads.SPAWN.y], "损坏站位安全回石门")
	_check(not sm.migration_diagnostics.is_empty(), "回退具有诊断")
