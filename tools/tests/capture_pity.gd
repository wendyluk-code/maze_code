extends "res://tools/tests/maze_capture.gd"

func _prepare(kind: String, passed: bool, roll: float = 0.99) -> String:
	# 开新探索，保留玩家全局记录；不重置正式账户或真实存档。
	if Run.snapshot(sm).get("active",false):
		_check(Run.finish(sm,false,Roads.SPAWN).success,"结束探索保留全局计数")
	sm.data[Run.Progression.FOOD_KEY].values = {"yaya":2.0,"tieshan":1.0}
	sm.data[Run.SEEN] = true
	_check(Run.begin(sm,Roads.SPAWN).success,"新探索")
	var id := kind+"_1"
	var run: Dictionary = sm.data[Run.KEY]
	run.first_eligible = false
	run.monsters[id].capture_roll = roll
	run.combat.actors[id].hp = 0
	_check(Run.defeat(sm,id,Run.monster_for(run,id).position).success,"击败 "+id)
	_check(Run.start_capture(sm,id).success,"正常支付饱腹度")
	_check(Run.finish_capture(sm,id,passed).success,"保存操作结论")
	return id

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离真实存档")
	if failures == 0:
		_fresh()
		for kind in Catalog.TYPES:
			_check(Run.failure_streak(sm,kind)==0,"旧存档缺省零："+kind)
			for attempt in 3:
				var id := _prepare(kind,attempt % 2 == 0)
				_check(not Run.resolve(sm,id,true).caught,"前三次失败："+kind)
				sm.load_data()
				_check(Run.failure_streak(sm,kind)==attempt+1,"跨探索读档累计："+kind)
			var id := _prepare(kind,false)
			var before: Dictionary = sm.data.duplicate(true)
			var path: String = sm._active_save_path
			sm._active_save_path = ""
			_check(not Run.resolve(sm,id,true).success and sm.data==before,"保底保存失败完整回滚："+kind)
			sm._active_save_path = path
			var result := Run.resolve(sm,id,true)
			_check(result.caught and not result.items.is_empty() and Run.failure_streak(sm,kind)==0,"第四次操作失败且抽签失败仍成功并清零："+kind)
			_check(not Run.resolve(sm,id,true).success and Run.failure_streak(sm,kind)==0,"重复结算不重复领奖")
		# 同类正常成功清零，异类计数互不影响，放弃不消耗保底。
		sm.data[Run.PITY_KEY] = {"snail":3,"beetle":2}
		_check(Run.finish(sm,false,Roads.SPAWN).success,"返回餐厅保留计数")
		sm.data[Run.Progression.FOOD_KEY].values = {"yaya":2.0,"tieshan":1.0}
		Run.begin(sm,Roads.SPAWN)
		var run: Dictionary = sm.data[Run.KEY]
		run.combat.actors.snail_1.hp = 0
		Run.defeat(sm,"snail_1",Run.monster_for(run,"snail_1").position)
		_check(Run.resolve(sm,"snail_1",false).success and Run.failure_streak(sm,"snail")==3,"放弃不计次也不消耗保底")
		var id := _prepare("beetle",true,0.0)
		_check(Run.resolve(sm,id,true).caught and Run.failure_streak(sm,"beetle")==0 and Run.failure_streak(sm,"snail")==3,"普通成功清零且不同种类独立")
		await _live()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _live() -> void:
	Run.finish(sm,false,Roads.SPAWN)
	sm.data[Run.Progression.FOOD_KEY].values = {"yaya":2.0,"tieshan":1.0}
	Run.begin(sm,Roads.SPAWN)
	sm.data[preload("res://scripts/ch2_exploration_guide.gd").KEY] = {"revision":2,"step":"done","seen":{},"banked":{}}
	sm.save()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.6).timeout
	var run: Dictionary = sm.data[Run.KEY]
	run.monsters.snail_1.capture_roll = 0.99
	run.combat.actors.snail_1.hp = 0
	var flow = maze.capture_flow
	flow._encounter("snail_1")
	await get_tree().create_timer(0.6).timeout
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(1.4).timeout
	_check(flow.attempt.probability.text == "80%","保底隐藏且显示概率不变")
	await _capture_image("pity_hidden")
	var food: float = Run.snapshot(sm).satiety
	await _click(flow.attempt.yes_button)
	await get_tree().create_timer(13.5).timeout
	_check(flow.reward.visible and Run.snapshot(sm).monsters.snail_1.status=="captured","真实场景不按J且抽签失败仍保底成功")
	_check(absf(Run.snapshot(sm).satiety-(food-1))<0.01,"保底仍正常消耗一次饱腹度")
	_check(Run.failure_streak(sm,"snail")==0,"实景成功清零")
	await _capture_image("pity_success")
	await _click(flow.reward._confirm_button)
	_check(not flow.busy and not maze.player.input_locked,"奖励关闭恢复输入")
	sm.load_data()
	_check(Run.failure_streak(sm,"snail")==0,"成功清零持久化")
	maze.queue_free()
	await get_tree().process_frame
