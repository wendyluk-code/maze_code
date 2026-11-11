extends "res://tools/tests/yufeng_sitting_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	if failures == 0:
		_prepare_trip()
		await _open_map()
		for stage in ["unseen","investigate","report","joined"]:
			sm.data[Story.KEY] = Story.fresh(stage)
			var before: Dictionary = sm.data.duplicate(true)
			for destination in ["枯水渠","下一区域","青苔池","水轮工坊"]:
				maze._open_confirmation(destination)
				_check(not maze.confirmation.visible and sm.data == before,"未完成禁止路标："+stage+destination)
			await maze.travel_region("maze_entry",Roads.SPAWN)
			_check(sm.data == before and not maze._busy,"禁止直接返回上一区域："+stage)
			await maze.return_to_restaurant(true)
			await maze.return_to_restaurant(false)
			_check(sm.data == before and not maze.player.input_locked,"禁止结束及放弃探索，保持输入："+stage)
		await _capture_image("exit_locked")
		sm.data[Story.KEY] = Story.fresh("done")
		_check(not maze._block_unfinished_fenshui(),"完成后解除分水庭出口限制")
		maze.region_id = "maze_entry"
		sm.data[Story.KEY] = Story.fresh()
		_check(not maze._block_unfinished_fenshui(),"不影响其他区域原规则")
		await _close_map()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
