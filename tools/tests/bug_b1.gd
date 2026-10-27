extends "res://tools/tests/capture_attempt.gd"

var emitted := 0

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		if OS.get_cmdline_user_args().has("--prepare-attempt"):
			_fresh()
			_prepare_monster()
			Run.defeat(sm,"slime_1",Catalog.find("slime_1").position)
			Run.start_capture(sm,"slime_1")
			sm.data[Run.KEY].monsters.slime_1.attempt.started_at = Time.get_unix_time_from_system()-30
			_check(sm.save(),"保存跨进程检查点")
		elif OS.get_cmdline_user_args().has("--resume-attempt"):
			sm._active_save_path = "user://chapter-ending-test.json"
			sm.load_data()
			var food: float = Run.snapshot(sm).satiety
			maze = load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze)
			await get_tree().create_timer(1.5).timeout
			_check(Run.snapshot(sm).monsters.slime_1.status == "captured", "跨进程到期恢复首次保底")
			_check(Run.snapshot(sm).satiety == food, "跨进程不重复扣费")
		else:
			await _timing()
			_probability()
			if DisplayServer.get_name() != "headless":
				for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
					get_window().size = resolution
					suffix = "_%dx%d" % [resolution.x,resolution.y]
					await _live()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("BUG_B1 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _timing() -> void:
	_fresh()
	var ui = load("res://scripts/ui/components/capture_attempt_modal.gd").new()
	add_child(ui)
	ui.set_process(false)
	ui.finished.connect(func(_passed): emitted += 1)
	for scenario in ["zero","tap","release","qualified_release"]:
		ui.present(Catalog.find("slime_1"),Run.snapshot(sm),true,3)
		ui.guaranteed = false
		ui.start(2.6)
		emitted = 0
		var previous := 2.0/3.0
		var monotonic := true
		var no_early := true
		var decay := false
		for step in range(1001):
			var tapping: bool = scenario == "tap" or (scenario == "release" and step < 150) or (scenario == "qualified_release" and step < 450)
			if tapping and ui.pressure < 0.98:
				var event := InputEventKey.new()
				event.keycode = KEY_J
				event.pressed = true
				ui._input(event)
				event.pressed = false
				ui._input(event)
			var old: float = ui.pressure
			ui._process(0.01)
			if not tapping and old > ui.pressure: decay = true
			if ui.track.progress + 0.00001 < previous: monotonic = false
			previous = ui.track.progress
			if step < 999 and ui.mode != "suppress": no_early = false
		_check(monotonic,scenario+"进度不倒退")
		_check(no_early,scenario+"镇压未满10秒不结束")
		_check(ui.mode == "complete" and ui.track.progress == 1,scenario+"到终点进入完成")
		_check(ui.result_passed == (scenario in ["tap","qualified_release"]),scenario+"保持资格结果正确")
		if scenario != "tap": _check(decay,scenario+"停止点按蓄力正常下降")
		ui._process(0.56)
		ui._process(1.0)
		_check(emitted == 1,scenario+"只发送一次结算")
	ui.start(7.6)
	ui._process(0.01)
	_check(ui.mode == "suppress" and absf(ui.track.progress-5.0/6)<0.001,"恢复按已耗时显示进度")
	_check(ui.hold_time == 0 and not ui.hold_qualified,"恢复保持资格按既有规则清零")
	ui._process(5.0)
	_check(ui.mode == "complete","恢复只走剩余时限")
	ui.queue_free()
	await get_tree().process_frame

func _probability() -> void:
	for roll in [0.0,0.99]:
		_fresh()
		_prepare_monster()
		Run.defeat(sm,"slime_1",Catalog.find("slime_1").position)
		sm.data[Run.KEY].monsters.slime_1.guaranteed = false
		sm.data[Run.KEY].monsters.slime_1.capture_roll = roll
		Run.start_capture(sm,"slime_1")
		Run.finish_capture(sm,"slime_1",true)
		_check(Run.resolve(sm,"slime_1",true).caught == (roll == 0.0),"普通达标仍按既有概率判定："+str(roll))

func _live() -> void:
	_fresh()
	_prepare_monster()
	_check(Run.defeat(sm,"slime_1",Catalog.find("slime_1").position).success,"准备实际击败待捕获状态")
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.8).timeout
	_check(maze.capture_flow.dialog.visible,"实景待捕获入口")
	var flow = maze.capture_flow
	var ui = flow.attempt
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	await _click(ui.yes_button)
	_check(ui.mode == "throw","真实确认启动捕获")
	await get_tree().create_timer(2.8).timeout
	var deadline := Time.get_ticks_msec()+11000
	var shot := false
	while ui.mode == "suppress" and Time.get_ticks_msec()<deadline:
		if ui.phase_time < 4.5 and ui.pressure < 0.98: await _send_key(KEY_J)
		if ui.phase_time > 6 and not shot:
			_check(ui.hold_time == 0 and ui.track.progress > 0.86,"实景松开保持清零进度仍前行")
			await _capture_image("bug_b1_release")
			shot = true
		await get_tree().process_frame
	_check(shot,"达标后仍显示镇压直到时限")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await get_tree().create_timer(0.7).timeout
	_check(ui.mode == "retry","保存失败保留重试")
	await _capture_image("bug_b1_retry")
	sm._active_save_path = path
	await _click(ui.yes_button)
	_check(flow.reward.visible,"重试原结论发奖")
	await _capture_image("bug_b1_success")
	await _click(flow.reward._confirm_button)
	_check(not flow.busy and not maze.player.input_locked,"收下恢复输入")
	maze.queue_free()
	await get_tree().process_frame

func _prepare_monster() -> void:
	sm.data[Run.KEY].combat.actors.slime_1.hp = 0
	sm.data[preload("res://scripts/ch2_exploration_guide.gd").KEY] = {"revision":2,"step":"done","seen":{},"banked":{}}

