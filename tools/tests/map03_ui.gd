extends "res://tools/tests/combat_02_flow.gd"
const S = preload("res://data/maze/salt_pool_encounters.gd")
const SR = preload("res://data/maze/salt_pool_roads.gd")
func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	_check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"进入真实盐池UI场景")
	await _close_scene()
	maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	var flow=maze.capture_flow
	flow.set_process(false)
	flow.window_focused=true
	var base: Dictionary=sm.data.duplicate(true)
	for row in [S.all()[0],S.all()[4]]:
		for outcome in ["cancel","success","failure"]:
			sm.data=base.duplicate(true)
			sm.data[Run.KEY].combat.actors[row.id].hp=0
			sm.data[Run.KEY].monsters[row.id].capture_roll=0.0
			sm.data[Run.KEY].monsters[row.id].copy_roll=0.99
			maze.player.position=row.position+Vector2(0,25)
			maze.camera.snap_to_target()
			flow._process(0)
			await get_tree().create_timer(0.8).timeout
			flow._process(0)
			_check(flow.dialog.visible,"倒地显示捕获入口"+row.kind+outcome)
			await get_tree().create_timer(0.5).timeout
			await _click(flow.dialog._confirm_button)
			await get_tree().create_timer(0.5).timeout
			flow._process(0)
			_check(flow.attempt.visible and flow.attempt.name_label.text==row.name,"名称正确且捕获窗打开")
			_check(flow.attempt.base_value.text.contains(str(row.chance)),"显示批准基础概率")
			await _capture_image(row.kind+"_"+outcome+"_ready")
			var food: float=sm.data[Run.KEY].satiety
			if outcome=="cancel":
				await _click(flow.attempt.no_button)
				_check(sm.data[Run.KEY].monsters[row.id].status=="skipped" and sm.data[Run.KEY].satiety==food,"真实取消不扣费且结束机会")
			else:
				await _click(flow.attempt.yes_button)
				_check(sm.data[Run.KEY].satiety==food-1,"真实确认扣费一次")
				await get_tree().create_timer(2.7).timeout
				if outcome=="success":
					for i in 180:
						await _send_key(KEY_J)
						await get_tree().create_timer(0.06).timeout
						if flow.reward.visible: break
				else: await get_tree().create_timer(10.8).timeout
				await get_tree().create_timer(0.5).timeout
				if outcome=="success":
					_check(flow.reward.visible and sm.data[Run.KEY].bag.get(row.drops[0],0)==1,"真实J输入捕获成功与材料奖励")
					await _capture_image(row.kind+"_reward")
					await _click(flow.reward._confirm_button)
				else:
					_check(flow.dialog.visible and sm.data[Run.KEY].monsters[row.id].status=="failed" and sm.data[Run.KEY].bag.is_empty(),"未镇压实际失败且不发肉")
					await _capture_image(row.kind+"_failure")
					await _click(flow.dialog._confirm_button)
			await get_tree().create_timer(0.3).timeout
			_check(not maze.player.input_locked and maze.player.is_physics_processing(),"确认取消失败关闭恢复输入")
			_check(not flow.attempt.visible and not flow.reward.visible and not flow.dialog.visible,"关闭后无遮罩残留")
	await _close_scene()
