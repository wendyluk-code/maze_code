extends "res://tools/tests/audio_interactions.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "实际 user:// 隔离")
	if failures: get_tree().quit(1); return
	GameAudio.cue_played.connect(_heard)
	_check(is_equal_approx(GameAudio._players[&"sprint_start"].volume_db, -10.0), "加速播放器为-10 dB")
	_completed()
	tm.active = false
	sm.data["capture_first_visit_started"] = true
	sm.data["first_exploration_gate_v1"] = "done"
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.cancel_maze_entry()
	for path in ["restaurant_map_2d", "maze_entry", "maze_moss_pool", "maze_salt_pool", "maze_fenshui"]:
		var world = load("res://scenes/" + path + ".tscn").instantiate()
		get_tree().root.add_child(world)
		get_tree().current_scene = world
		await get_tree().create_timer(1.0).timeout
		var is_maze: bool = path.begins_with("maze")
		var player = world.player if is_maze else world.get_node("Player")
		player.input_locked = false
		player.set_physics_process(true)
		if is_maze:
			world.capture_flow.window_focused = true
			world.capture_flow.busy = false
		var origin: Vector2 = player.position
		if is_maze:
			await _attack_audio(world)
		var moved := false
		for action in ["ui_right", "ui_up", "ui_left", "ui_down"]:
			cues.clear()
			Input.action_press(action)
			await get_tree().create_timer(0.55).timeout
			Input.action_release(action)
			if player.position.distance_to(origin) > 5.0:
				moved = true
				_check(_steps() >= 1 and _steps() < 8, path + "真实位移脚步有节奏")
				break
		_check(moved, path + "实际场景移动成功")
		await get_tree().physics_frame
		cues.clear()
		await get_tree().create_timer(0.2).timeout
		_check(_steps() == 0, path + "停步无新脚步")
		player.input_locked = true
		Input.action_press("ui_right")
		cues.clear()
		await get_tree().create_timer(0.2).timeout
		_check(cues.is_empty(), path + "锁输入无动作音")
		Input.action_release("ui_right")
		player.input_locked = false
		# 停用物理帧也是现有对白的锁定方式。
		player.set_physics_process(false)
		cues.clear()
		Input.action_press("ui_right")
		await get_tree().create_timer(0.15).timeout
		Input.action_release("ui_right")
		_check(cues.is_empty(), path + "对白停用物理帧无动作音")
		player.set_physics_process(true)
		var wall: StaticBody2D
		if is_maze:
			player.position = player._move_with_portals(origin, Vector2.RIGHT * 4000.0)
		else:
			player.position = origin
			player.last_valid = origin
			wall = StaticBody2D.new()
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(8, 200)
			shape.shape = rectangle
			wall.add_child(shape)
			world.add_child(wall)
			wall.global_position = player.global_position + Vector2(30,0)
		Input.action_press("ui_right")
		await get_tree().create_timer(0.3).timeout
		var blocked_position: Vector2 = player.position
		cues.clear()
		await get_tree().create_timer(0.2).timeout
		_check(player.position.distance_to(blocked_position) < 0.01 and cues.is_empty(), path + "撞墙持续输入无动作音")
		Input.action_release("ui_right")
		if is_instance_valid(wall): wall.queue_free()
		player.position = origin
		if not is_maze: player.last_valid = origin
		await get_tree().physics_frame
		if not is_maze:
			cues.clear()
			_shift(true)
			await get_tree().create_timer(0.1).timeout
			_check(cues.is_empty(), "餐厅原地Shift无声")
			Input.action_press("ui_right")
			await get_tree().create_timer(0.4).timeout
			_check(cues.count(&"sprint_start") == 1, "餐厅实际加速仅一次起跑音")
			Input.action_release("ui_right")
			_shift(false)
		if is_maze:
			# 使用正式场景和正式体力状态，在已确认可行走位置测试冲刺。
			player.position = origin
			player.clear_combat_input()
			player.sprint_held = true
			cues.clear()
			await get_tree().create_timer(0.15).timeout
			_check(cues.is_empty(), path + "原地冲刺无声")
			Input.action_press("ui_right")
			await get_tree().create_timer(0.4).timeout
			_check(cues.count(&"sprint_start") == 1, path + "实际冲刺开始一次且持续按住不重播")
			Input.action_release("ui_right")
			player.clear_combat_input()
			sm.data[Run.KEY].combat.sprint = 0.0
			player.sprint_held = true
			player.sprint_exhausted = true
			cues.clear()
			Input.action_press("ui_left")
			await get_tree().create_timer(0.15).timeout
			Input.action_release("ui_left")
			_check(cues.count(&"sprint_start") == 0, path + "体力不足不播放起跑音")
		await _shot("character_audio_" + path)
		world.queue_free()
		await get_tree().process_frame
		cues.clear()
		await get_tree().create_timer(0.15).timeout
		_check(cues.is_empty(), path + "离场无新动作音")
	# 固定两秒的等价位移，检查交替顺序与速度比例，不依赖地图可走直线长度。
	var walk_steps := 0
	for speed in [130.0, 195.0]:
		var motion := preload("res://scripts/audio/character_motion_audio.gd").new()
		cues.clear()
		for frame in 120: motion.update(GameAudio, speed / 60.0, 130.0, speed > 130.0)
		var steps: Array[StringName] = []
		for cue in cues:
			if str(cue).begins_with("footstep_"): steps.append(cue)
		for i in steps.size():
			_check(steps[i] == StringName("footstep_%02d" % (i % 4 + 1)), "四种脚步顺序交替：" + str(i))
		if speed == 130.0: walk_steps = steps.size()
		else: _check(steps.size() > walk_steps and cues.count(&"sprint_start") == 1, "奔跑步频更快且持续冲刺仅响一次")
	var guest = load("res://scenes/guest_placeholder.tscn").instantiate()
	get_tree().root.add_child(guest)
	cues.clear()
	guest.play_collapse()
	guest.play_collapse()
	_check(cues.count(&"tieshan_groan") == 1, "倒地动作开始只呻吟一次")
	guest.queue_free()
	await get_tree().process_frame
	guest = load("res://scenes/guest_placeholder.tscn").instantiate()
	get_tree().root.add_child(guest)
	cues.clear()
	guest.settle_prone()
	_check(cues.is_empty(), "恢复倒地状态不重播")
	guest.queue_free()
	await get_tree().process_frame
	sm.data = sm._defaults()
	sm._active_save_path = "user://character-audio-resume.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.save(), "倒地阶段实际写入隔离存档")
	sm.load_data()
	cues.clear()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.3).timeout
	tm.start()
	await get_tree().create_timer(0.5).timeout
	_check(is_instance_valid(tm._parked_guest) and tm._parked_guest.collapse_completed, "实际读档恢复已倒地铁山")
	_check(cues.count(&"tieshan_groan") == 0, "真实读档路径不重播呻吟")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	var index := AudioServer.get_bus_effect_count(0) - 1
	for cue in GameAudio.STREAMS:
		for player in GameAudio._players.values(): player.stop()
		await get_tree().create_timer(0.1).timeout
		capture.clear_buffer()
		GameAudio.play_cue(cue)
		await get_tree().create_timer(0.8).timeout
		var buffer := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in buffer: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		_check(peak > 0.00001 and peak < 1.0, "实际混音非静音且不削波：" + str(cue), {"peak":peak,"frames":buffer.size()})
	AudioServer.remove_bus_effect(0,index)
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.15).timeout
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _attack_audio(world: Node) -> void:
	var flow = world.capture_flow
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var before: Dictionary = sm.data.duplicate(true)
	var start: int = GameAudio._attack_index
	for i in 5:
		_check(GameAudio._players[StringName("attack_%02d" % (i+1))].volume_db == -20.0, "攻击音量-20dB")
	for i in 6:
		sm.data[Run.KEY].combat.cooldown = 0.0
		sm.data[Run.KEY].combat.action_left = 0.0
		cues.clear()
		event.position = Vector2(600,300)
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame
		var expected := StringName("attack_%02d" % ((start + i) % 5 + 1))
		_check(cues.count(expected) == 1, world.name + "有效攻击顺序" + str(i + 1))
		_check(cues.count(&"interact") == 0, "真实左键攻击不叠加E点击音")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = event.position
		Input.parse_input_event(release)
		cues.clear()
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(cues.size() == 1 and cues.count(&"interact") == 1, "未出招的点击保留通用音且不播攻击音")
		Input.parse_input_event(release)
	world.player.input_locked = true
	cues.clear()
	flow._unhandled_input(event)
	_check(cues.is_empty(), "锁输入不播放攻击音")
	world.player.input_locked = false
	var path: String = sm._active_save_path
	sm.data[Run.KEY].combat.cooldown = 0.0
	sm.data[Run.KEY].combat.action_left = 0.0
	sm._active_save_path = ""
	var index: int = GameAudio._attack_index
	flow._unhandled_input(event)
	_check(cues.is_empty() and GameAudio._attack_index == index, "保存失败不播放攻击音或推进序号")
	sm._active_save_path = path
	sm.data = before
	flow.save_retry_delay = 0.0
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	var old_slot: int = int(flow.display_run().combat.get("selected",0))
	cues.clear()
	flow._unhandled_input(tab)
	_check(int(flow.display_run().combat.get("selected",0)) != old_slot and cues.count(&"interact") == 1, "Tab成功切换响一次E音")
	tab.echo = true
	flow._unhandled_input(tab)
	_check(cues.count(&"interact") == 1, "Tab按住重复不重播")
	tab.echo = false
	cues.clear()
	sm._active_save_path = ""
	flow._unhandled_input(tab)
	_check(cues.is_empty(), "Tab保存失败不响切换音")
	sm._active_save_path = path
	sm.data = before
	flow.save_retry_delay = 0.0
	await get_tree().process_frame

func _steps() -> int:
	var count := 0
	for cue in cues:
		if str(cue).begins_with("footstep_"): count += 1
	return count

func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)

