extends "res://tools/tests/combat_02_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		await _new_scene()
		maze.capture_flow.set_process(false)
		var run: Dictionary = sm.data[Run.KEY]
		var ids: Array = run.monsters.keys()
		for actor in run.combat.actors.values(): actor.mode = "idle"
		run.combat.shots = []
		run.combat.enemy_shots = []
		run.combat.action_left = 0.0
		run.combat.axe_pending = false
		for index in 3:
			run.monsters[ids[index]].status = ["captured","failed","skipped"][index]
			run.combat.actors[ids[index]].hp = 0
		run.combat.actors[ids[3]].hp = 1
		var original: Dictionary = run.monsters.duplicate(true)
		var actors: Dictionary = run.combat.actors.duplicate(true)
		_check(sm.save(),"保存部分击败和受伤魔物夹具")
		for region in ["fenshui","salt_pool","moss_pool","salt_pool","fenshui","maze_entry"]:
			var spawn: Vector2 = Roads.SPAWN
			if region=="fenshui": spawn=preload("res://data/maze/fenshui_roads.gd").SPAWN
			elif region=="salt_pool": spawn=preload("res://data/maze/salt_pool_roads.gd").SPAWN
			elif region=="moss_pool": spawn=preload("res://data/maze/moss_pool_roads.gd").SPAWN
			var before: Dictionary = sm.data.duplicate(true)
			var save_path: String = sm._active_save_path
			sm._active_save_path = ""
			_check(not Run.change_region(sm,region,spawn).success and sm.data==before,"切区保存失败不改魔物："+region)
			sm._active_save_path = save_path
			_check(Run.change_region(sm,region,spawn).success,"切区保存："+region)
			for id in original:
				_check(sm.data[Run.KEY].monsters[id]==original[id] and sm.data[Run.KEY].combat.actors[id]==actors[id],"切区保留魔物状态和血量："+region+"/"+id)
			for id in sm.data[Run.KEY].monsters:
				if original.has(id): continue
				original[id] = sm.data[Run.KEY].monsters[id].duplicate(true)
				actors[id] = sm.data[Run.KEY].combat.actors[id].duplicate(true)
		_check(sm.save(),"返区保存")
		await _close_scene()
		sm.load_data()
		maze = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().process_frame
		maze.capture_flow.set_process(false)
		await get_tree().process_frame
		for id in original:
			_check(sm.data[Run.KEY].monsters[id].status==original[id].status,"读档保留："+id)
			if maze.capture_flow.monsters.has(id):
				_check(maze.capture_flow.monsters[id].visible==(original[id].status=="alive"),"实际场景仅显示剩余魔物："+id)
		await _capture_image("returned_remaining_monsters")
		await _close_scene()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
