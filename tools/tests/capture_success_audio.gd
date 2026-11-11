extends "res://tools/tests/audio_interactions.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "正式存档隔离")
	if failures:
		get_tree().quit(1)
		return
	GameAudio.cue_played.connect(_heard)
	_check(GameAudio._players[&"capture_success"].volume_db == -16.0 and GameAudio._players[&"cooking_complete"].volume_db == -16.0, "所有成功提示与烹饪音量一致")
	_check(GameAudio.STREAMS[&"capture_success"].resource_path == "res://assets/audio/sfx/capture_success.wav", "捕获成功使用用户新音效")
	_check(GameAudio.STREAMS[&"capture_failure"].resource_path == "res://assets/audio/sfx/failure_user.wav", "捕获失败使用统一失败音效")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0,capture)
	var index := AudioServer.get_bus_effect_count(0)-1
	await _capture_audio(true)
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	_check(peak > 0.00001 and peak < 1.0,"成功弹窗音效实际输出非静音且未削波",{"peak":peak})
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.1).timeout
	capture.clear_buffer()
	await _capture_audio(false)
	peak = 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	_check(peak > 0.00001 and peak < 1.0,"失败弹窗音效实际输出非静音且未削波",{"peak":peak})
	AudioServer.remove_bus_effect(0,index)
	await _loot_audio()
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.15).timeout
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _loot_audio() -> void:
	_completed()
	sm.data["first_exploration_gate_v1"] = "done"
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	tm.active = false
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.7).timeout
	for dig in [false, true]:
		maze.player.position = Vector2(933,269) if dig else Vector2(725,369)
		maze._update_chest_target()
		var source = maze.dig_target if dig else maze.chest_target
		_check(source != null, "实际近距选中挖掘点或宝箱")
		if source == null: continue
		cues.clear()
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		maze._open_loot(source, dig)
		_check(cues.count(&"capture_success") == 0, "奖励保存失败无成功提示")
		sm._active_save_path = path
		maze._open_loot(source, dig)
		_check(maze.loot_modal.visible and cues.count(&"capture_success") == 1, "领取弹窗出现提示音一次")
		await _shot("loot_audio_" + str(dig))
		await get_tree().create_timer(0.2).timeout
		_check(cues.count(&"capture_success") == 1, "奖励弹窗停留不重播")
		maze.loot_modal.hide()
		maze._close_loot()
	maze.queue_free()
	await get_tree().process_frame
