extends "res://tools/tests/chapter_ending_input.gd"

const Run = preload("res://scripts/maze/capture_run.gd")
const Roads = preload("res://data/maze/entry_roads.gd")

func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离用户存档")
	var source := "res://scripts/debug/map_debug.gd"
	_check(ResourceLoader.exists(source), "提供独立地图调试状态入口")
	if failures == 0:
		var maps = load(source).new()
		_check(maps.regions().map(func(row): return row.id) == ["maze_entry","fenshui","salt_pool","moss_pool","waterkeeper_cottage"], "地图列表覆盖已确认五图")
		for row in maps.regions():
			for point in maps.points(row.id):
				_check(sm.maze_terrain(row.id).is_walkable(point.position), "测试落点可走："+row.name+"/"+point.name)
		_seed()
		for step in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(step)
		_check(Run.begin(sm, Roads.SPAWN).success, "建立真实探索")
		sm.data[Run.KEY].combat.hp = 1
		sm.data[Run.KEY].bag = {"cool_whisker_herb":2}
		sm.save()
		var original: Dictionary = sm.data.duplicate(true)
		var original_path: String = sm._active_save_path
		var original_bytes := FileAccess.get_file_as_bytes(original_path)
		var first_exploration=preload("res://scripts/maze/first_exploration.gd")
		_check(first_exploration.pending(sm), "回归夹具保留未完成首次探索")
		var blocked:=Run.finish(sm,false,Roads.SPAWN)
		_check(not blocked.success and blocked.get("reason","")=="first_exploration" and sm.data==original and FileAccess.get_file_as_bytes(original_path)==original_bytes, "普通探索仍禁止首次探索主动退出且不写档")
		var finish: Callable=Run.finish
		var forced: Dictionary=finish.call(sm,false,Roads.SPAWN,true)
		_check(not forced.success and forced.get("reason","")=="first_exploration" and sm.data==original and FileAccess.get_file_as_bytes(original_path)==original_bytes, "正式存档路径即使申请调试重开也不能绕过首次探索限制")
		_check(not maps.prepare(sm,"unknown").success and sm.data == original and sm._active_save_path == original_path, "未知地图不改变当前档")
		_check(maps.prepare(sm,"fenshui").success, "任意指定地图进入试玩副本")
		_check(sm._active_save_path != original_path and maps.is_trial(), "地图跳转使用独立试玩文件")
		var trial_before: Dictionary=sm.data.duplicate(true)
		forced=finish.call(sm,true,Roads.SPAWN,true)
		_check(not forced.success and forced.get("reason","")=="first_exploration" and sm.data==trial_before, "试玩例外不能用于结算返程")
		var run: Dictionary = Run.snapshot(sm)
		_check(run.combat.hp == 1 and run.bag == {"cool_whisker_herb":2} and run.members == original[Run.KEY].members, "普通切图保持生命携物与队伍")
		_check(sm.maze_exploration_state().region == "fenshui" and Run.valid(run), "目标区域与探索状态一致")
		_check(FileAccess.get_file_as_bytes(original_path) == original_bytes, "跳图不写原存档")
		for region in ["salt_pool","moss_pool","waterkeeper_cottage","maze_entry"]:
			_check(maps.prepare(sm,region).success and sm.maze_exploration_state().region == region, "连续跳转："+region)
		var position: Array = sm.maze_exploration_state().position.duplicate()
		_check(maps.prepare(sm,"maze_entry","current").success and sm.maze_exploration_state().position == position and Run.snapshot(sm).combat.hp == 1, "重载保持落点和本趟生命")
		_check(maps.prepare(sm,"fenshui","entrance",true).success, "显式重新开始本趟")
		run = Run.snapshot(sm)
		_check(run.bag.is_empty() and run.combat.hp == run.combat.max_hp and Run.valid(run), "重开清空本趟携物并恢复新一趟生命")
		_check(first_exploration.pending(sm), "试玩重开不把首次探索教学标为完成")
		_check(FileAccess.get_file_as_bytes(original_path) == original_bytes, "重开不清除原档探索进度")
		_check(maps.leave(sm).success and not maps.is_trial(), "退出试玩恢复原档")
		_check(sm.data == original and sm._active_save_path == original_path, "恢复原档的完整状态和路径")
		var failed = load(source).new()
		failed.trial_save_path = ""
		_check(not failed.prepare(sm,"fenshui").success and sm.data == original and sm._active_save_path == original_path and not failed.is_trial(), "试玩保存失败回滚且不进入试玩")
		sm.begin_replay()
		_check(not maps.prepare(sm,"fenshui").success, "重播预览不跳转或修改档")
		sm.end_replay()
	FileAccess.open(_arg("--report="), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
