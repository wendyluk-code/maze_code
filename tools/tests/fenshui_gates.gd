extends "res://tools/tests/fenshui_flow.gd"

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.position = maze.SettlementExit.FRONT
	maze.camera.snap_to_target()
	maze._update_prompts()
	await _capture_image("01_kushui_sign")
	await _click(maze.settlement_prompt.button)
	_check(maze.confirmation.visible,"枯水渠路标打开确认")
	await _capture_image("02_confirm")
	var prior: Dictionary = sm.data.duplicate(true)
	var saved_path: String = sm._active_save_path
	sm._active_save_path = ""
	maze._confirm_destination()
	_check(maze.region_id == "maze_entry" and sm.data == prior and not maze.player.input_locked,"切区保存失败回滚并恢复输入")
	sm._active_save_path = saved_path
	await _click(maze.settlement_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == "fenshui" and maze._entry_ready,"确认后实际切入分水庭")
	if maze.region_id != "fenshui": return
	maze.capture_flow.window_focused = true
	_check(maze.player.position.distance_to(FS.SPAWN)<0.1,"右上路面出生")
	_check(maze.capture_flow.monsters.is_empty() and maze.chests.is_empty() and maze.dig_sites.is_empty() and not is_instance_valid(maze.elder),"不携带枯水渠怪物宝箱采集或NPC")
	var now := Run.snapshot(sm)
	for key in ["members","satiety","bag","monsters"]:
		_check(now[key] == prior[Run.KEY][key],"换区保留"+key)
	_check(now.combat.hp == prior[Run.KEY].combat.hp,"换区保留生命")
	_check(sm.stamina_snapshot().value == prior.stamina.value,"切区不重新扣体力")

	maze.capture_flow.set_process(false)
	maze.player.set_physics_process(false)
	for gate in maze.FenshuiGates.GATES:
		maze.player.position = gate.front
		maze.camera.snap_to_target()
		maze._update_prompts()
		var prompt = maze.fenshui_gate_prompts[gate.name]
		_check(FS.is_walkable(gate.front),gate.name+"交互站位可走")
		_check(prompt.visible,gate.name+"靠近显示")
		var center: Vector2 = maze.FenshuiGates.center(gate)
		_check(not FS.is_walkable(center),gate.name+"栅栏阻挡")
		await _capture_image("gate_"+gate.name)
		await _click(prompt.button)
		_check(maze.confirmation.visible and maze.player.input_locked,gate.name+"二次确认与锁定")
		_check(maze.confirmation.question.text == "是否前往%s？" % gate.name,gate.name+"确认文案")
		await _click(maze.confirmation.cancel_button)
		_check(not maze.confirmation.visible and not maze.player.input_locked,gate.name+"取消恢复")
		var before: Dictionary = sm.data.duplicate(true)
		await _click(prompt.button)
		await _capture_image("confirm_"+gate.name)
		await _click(maze.confirmation.confirm_button)
		_check(maze.region_id == "fenshui" and maze.last_message == "当前区域未开放，以后再来探索吧~",gate.name+"未开放提示留在本区")
		_check(sm.data == before and not maze.player.input_locked,gate.name+"确认不扣资源并恢复输入")
		await _capture_image("closed_"+gate.name)
		maze.player.position = Vector2(920,440)
		maze._update_prompts()
		_check(not prompt.visible,gate.name+"远离隐藏")
	maze.player.position = FS.SPAWN
	maze._update_prompts()
	_check(maze.entrance_prompt.visible and FS.is_walkable(FS.SPAWN),"右上入口保留")
	await _close_scene()
