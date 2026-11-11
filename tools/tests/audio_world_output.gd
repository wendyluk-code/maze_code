extends "res://tools/tests/audio_interactions.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	GameAudio.cue_played.connect(_heard)
	_check(GameAudio.STREAMS[&"interact"].resource_path == "res://assets/audio/sfx/interaction_click.wav", "统一点击使用用户附件转换资源")
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		cues.clear()
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = true
		Input.parse_input_event(click)
		await get_tree().process_frame
		GameAudio.interaction()
		_check(cues.count(&"interact") == 1, "全局鼠标按下播放一次且按下回调去重："+str(button))
		click = InputEventMouseButton.new()
		click.button_index = button
		Input.parse_input_event(click)
		GameAudio.interaction()
		_check(cues.count(&"interact") == 1, "鼠标松开业务回调不重复："+str(button))
		await get_tree().process_frame
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 5.0
	AudioServer.add_bus_effect(0, capture)
	var effect_index := AudioServer.get_bus_effect_count(0)-1
	for cue in GameAudio.STREAMS:
		for player in GameAudio._players.values(): player.stop()
		await get_tree().create_timer(0.1).timeout
		capture.clear_buffer()
		GameAudio.play_cue(cue)
		await get_tree().create_timer(0.8).timeout
		var buffer := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in buffer: peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		_check(peak>0.00001 and peak<1.0,"混音总线实际有非削波音频："+str(cue),{"frames":buffer.size(),"peak":peak})
	AudioServer.remove_bus_effect(0,effect_index)
	_completed()
	sm.data["capture_first_visit_started"] = true
	sm.data["first_exploration_gate_v1"] = "done"
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	tm.active = false
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.6).timeout
	maze.player.position = Roads.ENTRANCE
	await get_tree().create_timer(0.2).timeout
	cues.clear()
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and cues.count(&"interact")==1,"迷宫路标真实E开窗一次S06")
	maze._close_confirmation()
	await get_tree().create_timer(0.2).timeout
	cues.clear()
	await _world_click(maze.entrance_prompt.button)
	_check(maze.confirmation.visible and cues.count(&"interact")==1,"迷宫路标鼠标点击一次S06")
	await _shot("audio_maze_prompt")
	maze._close_confirmation()
	maze.player.input_locked = true
	cues.clear()
	await _send_key(KEY_E)
	_check(cues.is_empty(),"迷宫输入锁禁止E音")
	maze.queue_free()
	await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
