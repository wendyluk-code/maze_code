extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures == 0:
		if OS.get_cmdline_user_args().has("--prepare-attempt"):
			_fresh()
			Run.defeat(sm,"slime_1",Catalog.find("slime_1").position)
			Run.start_capture(sm,"slime_1")
			sm.data[Run.KEY].monsters.slime_1.attempt.started_at = Time.get_unix_time_from_system()-30
			_check(sm.save(),"保存跨进程恢复检查点")
		elif OS.get_cmdline_user_args().has("--resume-attempt"):
			sm._active_save_path = "user://chapter-ending-test.json"
			sm.load_data()
			var before: float = Run.snapshot(sm).satiety
			_check(Run.snapshot(sm).monsters.slime_1.has("attempt"),"新进程恢复付费标记")
			maze = load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze)
			get_tree().current_scene = maze
			await get_tree().create_timer(1.5).timeout
			_check(Run.snapshot(sm).monsters.slime_1.status=="failed","离线超过期限恢复后失败")
			_check(absf(Run.snapshot(sm).satiety-before)<0.01,"新进程恢复不二次扣费")
			_check(maze.capture_flow.dialog.visible,"恢复显示失败结果")
		else:
			_transactions()
		if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--resume-attempt"):
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _gameplay()
			await _extra_scenes()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("CAPTURE_ATTEMPT ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _transactions() -> void:
	_fresh()
	var id := "slime_1"
	_check(Run.defeat(sm,id,Catalog.find(id).position).success,"击败首只史莱姆")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Run.start_capture(sm,id).success and sm.data==before,"扣费保存失败回滚所有状态")
	sm._active_save_path = path
	_check(Run.start_capture(sm,id).success,"开始捕获扣费保存")
	var paid: Dictionary = sm.data.duplicate(true)
	_check(Run.start_capture(sm,id).success and sm.data==paid,"重复开始不二次扣费")
	_check(not Run.resolve(sm,id,true).success and not Run.resolve(sm,id,false).success,"未完成挑战不能发奖或放弃")
	sm.load_data()
	_check(Run.snapshot(sm).monsters[id].has("attempt"),"重载保留付费标记")
	_check(Run.start_capture(sm,id).success and _same_saved(sm.data,paid),"重载后开始不二次扣费")
	sm._active_save_path = ""
	_check(not Run.finish_capture(sm,id,true).success and _same_saved(sm.data,paid),"操作结论保存失败回滚")
	sm._active_save_path = path
	_check(Run.finish_capture(sm,id,true).success,"连续达标结论保存")
	var finished_state: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.resolve(sm,id,true).success and sm.data==finished_state,"结算保存失败不发奖")
	sm._active_save_path = path
	sm.load_data()
	_check(Run.snapshot(sm).monsters[id].attempt.finished,"重载保留已完成结论")
	_check(Run.resolve(sm,id,true).caught,"恢复结算首只保底成功")
	_check(not Run.resolve(sm,id,true).success,"重复结算无效")
	_fresh()
	Run.defeat(sm,id,Catalog.find(id).position)
	Run.start_capture(sm,id)
	Run.finish_capture(sm,id,false)
	var failed := Run.resolve(sm,id,true)
	_check(failed.success and not failed.caught and Run.snapshot(sm).bag.is_empty(),"操作超时即使首只保底也失败，无奖励")
	_fresh()
	Run.defeat(sm,id,Catalog.find(id).position)
	sm.data[Run.KEY].monsters[id].guaranteed = false
	sm.data[Run.KEY].monsters[id].capture_roll = 0.99
	Run.start_capture(sm,id)
	Run.finish_capture(sm,id,true)
	_check(not Run.resolve(sm,id,true).caught,"操作达标仍按原概率失败")
	_fresh()
	Run.defeat(sm,id,Catalog.find(id).position)
	sm.data[Run.Progression.FOOD_KEY].values = {"yaya":0.0,"tieshan":0.0}
	sm.data[Run.KEY].satiety = 0.0
	before = sm.data.duplicate(true)
	_check(Run.start_capture(sm,id).get("reason")=="hungry" and sm.data==before,"无足额付款人拒绝且不改状态")

func _open_game() -> void:
	_completed()
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.6).timeout
	_check(maze._entry_ready,"真实迷宫就绪")
	# 使用真实靠近检测触发，保持场景业务与输入链路。
	maze.player.position = Catalog.find("slime_1").position+Vector2(0,-35)
	await get_tree().create_timer(0.6).timeout
	_check(maze.capture_flow.dialog.visible,"靠近触发胜利窗")

func _gameplay() -> void:
	await _open_game()
	var flow = maze.capture_flow
	var ui = flow.attempt
	var food: float = Run.snapshot(sm).satiety
	_check(flow.dialog._confirm_button.text=="是" and not flow.dialog.cost_row.visible,"前置胜利无扣费提示")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	_check(ui.visible and ui.mode=="ready" and Run.snapshot(sm).satiety==food,"前置是仅跳转不扣费")
	await get_tree().create_timer(1.3).timeout
	await _capture_image("ready")
	_check(ui.name_label.text=="史莱姆" and ui.probability.text=="100%","读取真实名称与首只概率")
	_check(ui.panel.get_global_rect().position.x>=0,"小屏面板不超左边界")
	await _click(ui.yes_button)
	flow._start_attempt()
	_check(ui.mode=="throw" and absf(Run.snapshot(sm).satiety-(food-1))<0.01,"捕获确认扣一次且重复点击无效")
	await get_tree().create_timer(2.7).timeout
	_check(ui.mode=="suppress","四阶段进入镇压")
	# 暂停实际操作计时，逐个检查节点完成边框，再恢复真实输入验收。
	ui.set_process(false)
	var saved_progress: float = ui.track.progress
	for step in range(4):
		ui.track.progress = float(step) / 3.0
		for node in range(4):
			_check(ui.track.is_node_complete(node) == (node <= step), "节点完成边框_%d_%d" % [step,node])
		ui.track.queue_redraw()
		await _capture_image("track_step_%d" % step)
	ui.track.progress = saved_progress
	ui.set_process(true)
	# 按住与重复事件不能当作连续点按。
	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.pressed = true
	get_viewport().push_input(press)
	await get_tree().process_frame

	var first_pressure: float = ui.pressure
	press.echo = true
	get_viewport().push_input(press)
	await get_tree().process_frame
	_check(ui.pressure<=first_pressure,"长按自动重复不提升")
	press.pressed = false
	press.echo = false
	get_viewport().push_input(press)
	# 先维持一小段，再松开验证连续计时清零。
	var stop := Time.get_ticks_msec()+1200
	while Time.get_ticks_msec()<stop and ui.mode=="suppress":
		if ui.pressure<0.93: await _send_key(KEY_J)
		await get_tree().process_frame
	_check(ui.hold_time>0.3,"J实际点按积累连续保持")
	await get_tree().create_timer(0.8).timeout
	_check(ui.hold_time==0,"离开目标区重新计时")
	stop = Time.get_ticks_msec()+6500
	var shot := false
	while ui.mode=="suppress" and Time.get_ticks_msec()<stop:
		if ui.pressure<0.93: await _send_key(KEY_J)
		if ui.hold_time>1 and not shot:
			await _capture_image("suppression")
			shot = true
		await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	_check(flow.reward.visible and not ui.visible,"真实J达标后保底成功弹窗")
	_check(Run.snapshot(sm).monsters.slime_1.status=="captured","成功状态落盘")
	await _capture_image("success")
	await _click(flow.reward._confirm_button)
	_check(not flow.busy and not maze.player.input_locked,"收下后恢复输入")
	maze.queue_free()
	await get_tree().process_frame
	await _open_game()
	flow = maze.capture_flow
	ui = flow.attempt
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	food = Run.snapshot(sm).satiety
	await _click(ui.no_button)
	_check(not flow.busy and Run.snapshot(sm).satiety==food,"捕获页否不扣费并恢复输入")
	maze.queue_free()
	await get_tree().process_frame
	await _open_game()
	flow = maze.capture_flow
	ui = flow.attempt
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	await _click(ui.yes_button)
	await get_tree().create_timer(13.6).timeout
	_check(not ui.visible and flow.dialog.visible and flow.dialog._title_label.text=="魔物溜走了","10秒不操作超时失败")
	_check(Run.snapshot(sm).monsters.slime_1.status=="failed","超时失败落盘")
	await _capture_image("timeout")
	await _click(flow.dialog._confirm_button)
	_check(not flow.busy and not maze.player.input_locked,"失败关闭恢复输入")
	maze.queue_free()
	await get_tree().process_frame


func _extra_scenes() -> void:
	await _open_game()
	var flow = maze.capture_flow
	var ui = flow.attempt
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	# 全魔物及五字名称复用同一布局，无战力或评级。
	for id in ["slime_1","snail_1","beetle_1","lizard_1"]:
		ui.present(Catalog.find(id),Run.snapshot(sm),true,3)
		await get_tree().create_timer(0.2).timeout
		_check(ui.name_label.text==Catalog.find(id).name and ui.frames.size()==4,"四帧与名称正确："+id)
		await _capture_image("monster_"+id)
	flow._open_attempt()
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _click(ui.yes_button)
	_check(ui.mode=="ready" and not Run.snapshot(sm).monsters.slime_1.has("attempt"),"实际按钮扣费保存失败留在确认页")
	sm._active_save_path = path
	await _click(ui.yes_button)
	var food: float = Run.snapshot(sm).satiety
	await get_tree().create_timer(2.9).timeout
	# 重建真实场景并加载保存，不重置总时限或再次收费。
	maze.queue_free()
	await get_tree().process_frame
	sm.load_data()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.7).timeout
	flow = maze.capture_flow
	ui = flow.attempt
	_check(ui.visible and ui.mode=="suppress" and ui.phase_time>0.3,"读档自动恢复捕获且不重置时限")
	_check(absf(Run.snapshot(sm).satiety-food)<0.01,"场景重建不重复扣费")
	await _capture_image("resumed")
	var stop := Time.get_ticks_msec()+7000
	while ui.mode=="suppress" and Time.get_ticks_msec()<stop:
		if ui.pressure<0.93: await _send_key(KEY_J)
		await get_tree().process_frame
	sm._active_save_path = ""
	await get_tree().create_timer(0.7).timeout
	_check(ui.mode=="retry" and Run.snapshot(sm).bag.is_empty(),"真实完成保存失败停留重试且不发奖")
	sm._active_save_path = path
	await _click(ui.yes_button)
	_check(flow.reward.visible,"保存重试完成原结论结算")
	await _click(flow.reward._confirm_button)
	maze.queue_free()
	await get_tree().process_frame
	await _open_game()
	flow = maze.capture_flow
	ui = flow.attempt
	sm.data[Run.Progression.FOOD_KEY].values = {"yaya":0.0,"tieshan":0.0}
	sm.data[Run.KEY].satiety = 0.0
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	_check(ui.visible,"零饱腹仍能从胜利页进入捕获详情")
	await _click(ui.yes_button)
	_check(ui.mode=="ready" and maze.last_message.contains("饱腹度不足"),"零饱腹捕获页拒绝并显示提示")
	await _send_key(KEY_ESCAPE)
	_check(not flow.busy and not maze.player.input_locked,"Esc取消恢复输入")
	maze.queue_free()
	await get_tree().process_frame


