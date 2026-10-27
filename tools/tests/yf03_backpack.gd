extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"背包与白虎回归隔离")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		suffix="_%dx%d"%[resolution.x,resolution.y]
		_completed()
		sm.cancel_maze_entry()
		sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		_check(Run.begin(sm,Roads.SPAWN).success,"当前流程真实出征")
		maze=load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene=maze
		await get_tree().create_timer(0.4).timeout
		maze.capture_flow.window_focused=true
		_check(maze.backpack_entry.visible and not maze.bento_entry.visible,"背包正常可用，未赠礼便当不可见")
		await _click(maze.backpack_entry)
		var bag=maze.backpack_warehouse
		_check(bag.visible and bag._heading.text=="背包" and bag._message.text=="完成探索后带回餐厅，\n中途放弃将失去所有食材","空背包当前标题及提示")
		await _capture_image("ordinary_empty_backpack")
		await _click(bag._cancel_button)
		_check(not maze.player.input_locked,"背包关闭恢复输入")
		maze.capture_flow.set_process(false)
		var row: Dictionary=Run.monster_for(Run.snapshot(sm),"slime_1")
		# 捕获事务必须从已被正式战斗判定击败的状态进入。
		sm.data[Run.KEY].combat.actors[row.id].hp=0
		_check(Run.defeat(sm,row.id,row.position).success,"已击败状态进入当前捕获事务")
		var result: Dictionary=Run.resolve(sm,row.id,true)
		_check(result.success and result.get("caught",false),"首次捕获产生真实临时物品")
		if not result.success: continue
		await _click(maze.backpack_entry)
		_check(bag._slot_by_id.slime_gel._quantity==int(result.items.slime_gel),"普通背包展示真实捕获数量")
		await _capture_image("ordinary_filled_backpack")
		await _click(bag._cancel_button)
		var stocked: int=sm.warehouse_snapshot().get("slime_gel",0)
		_check(Run.finish(sm,true,preload("res://data/maze/settlement_exit.gd").FRONT).success and sm.warehouse_snapshot().get("slime_gel",0)==stocked+int(result.items.slime_gel),"出口结算到真实仓库")
		maze.queue_free()
		await get_tree().process_frame
		_check(Run.begin(sm,Roads.SPAWN).success,"重新出征不带旧背包")
		maze=load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene=maze
		await get_tree().create_timer(0.3).timeout
		maze.capture_flow.window_focused=true
		_check(Run.snapshot(sm).bag.is_empty(),"新趟背包清空")
		maze.player.position=Vector2(839,503)
		_check(sm.accept_elder_firewood(maze.player.position).success,"实际位置接白虎原任务")
		sm.data[sm.INVENTORY_KEY]["wood"]=12
		sm.save()
		maze.elder.interact()
		await get_tree().create_timer(0.6).timeout
		await _send_key(KEY_E)
		await _send_key(KEY_E)
		_check(maze.elder.choice.visible,"白虎交付确认仍可用")
		await _click(maze.elder.choice.confirm_button)
		var deadline := Time.get_ticks_msec()+6000
		while maze.elder.phase=="reward" and Time.get_ticks_msec()<deadline:
			await _send_key(KEY_E)
			await _send_key(KEY_E)
		_check(maze.elder.phase=="ingredient_reward" and maze.elder.ingredient_reward.visible,"白虎真实奖励复用弹窗")
		for item in maze.elder.Config.REWARD_ITEMS: _check(sm.warehouse_snapshot().get(item.id,0)>=3,"白虎奖励真实入库："+str(item.id))
		await _capture_image("elder_ingredient_reward")
		await _click(maze.elder.ingredient_reward._confirm_button)
		await get_tree().create_timer(0.6).timeout
		_check(maze.elder.phase=="idle" and not maze.player.input_locked,"白虎收下后恢复输入")
		_check(not maze.elder.backpack_reward.visible and not maze.bento_entry.visible,"白虎不误触便当解锁")
		maze.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
