extends "res://tools/tests/combat_skill_01.gd"

func _combat_scene() -> void:
	await _new_scene()
	_fixture()
	var flow: Node = maze.capture_flow
	var run: Dictionary = sm.data[Run.KEY]
	run.monsters.slime_1.status = "alive"
	run.monsters.slime_1.guaranteed = true
	run.combat.actors.slime_1.position = Combat.pack(CENTER+ALONG*50)
	run.combat.actors.slime_1.hp = 1
	run.combat.actors.slime_1.mode = "windup"
	run.combat.actors.slime_1.windup = 1.0
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*100))
	_tick(0.2)
	flow.set_process(true)
	await get_tree().process_frame
	_check(flow.dialog.visible and Run.snapshot(sm).combat.actors.slime_1.hp==0,"左键真实击败后打开捕获入口")
	if not flow.dialog.visible:
		await _close_scene()
		return
	await get_tree().create_timer(0.5).timeout
	await _mouse(MOUSE_BUTTON_LEFT,flow.dialog._confirm_button.get_global_rect().get_center())
	await get_tree().create_timer(0.5).timeout
	var ui: Control = flow.attempt
	_check(ui.visible and ui.mode=="ready","确认进入捕获页面")
	var food: float = Run.snapshot(sm).satiety
	# 捕获页默认焦点在“否”，通过实际Tab/Enter选择“是”。
	await _send_key(KEY_TAB)
	await _send_key(KEY_ENTER)
	_check(ui.mode=="throw" and Run.snapshot(sm).satiety==food-1,"捕获确认扣一次饱腹")
	await get_tree().create_timer(2.8).timeout
	_check(ui.mode=="suppress","捕获进入J镇压")
	_check(not flow.skill_bar.visible and not flow.controls_hint.visible,"捕获弹窗隐藏战斗操作栏")
	var deadline := Time.get_ticks_msec()+12000
	var observed := false
	while ui.mode=="suppress" and Time.get_ticks_msec()<deadline:
		if ui.pressure<0.93: await _send_key(KEY_J)
		if ui.hold_time>0.5 and not observed:
			observed = true
			await _capture_image("j_suppression")
		await get_tree().process_frame
	_check(observed,"真实J点按积累镇压时间")
	await get_tree().create_timer(0.7).timeout
	_check(flow.reward.visible and Run.snapshot(sm).monsters.slime_1.status=="captured","J达标后捕获成功落盘")
	if flow.reward.visible:
		await _capture_image("capture_reward")
		await _mouse(MOUSE_BUTTON_LEFT,flow.reward._confirm_button.get_global_rect().get_center())
	_check(not flow.busy and not maze.player.input_locked,"领取奖励后恢复输入")
	_check(sm.save(),"捕获结果保存")
	sm.load_data()
	_check(sm.last_load_error.is_empty() and Run.snapshot(sm).monsters.slime_1.status=="captured","捕获结果读档保留")
	await _close_scene()
