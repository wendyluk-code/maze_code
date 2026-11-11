extends "res://tools/tests/cooking_countdown_input.gd"
var heard: Array[StringName] = []

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"实际存档隔离")
	if failures:
		get_tree().quit(1)
		return
	GameAudio.cue_played.connect(func(cue: StringName): heard.append(cue))
	_check(GameAudio._players[&"cooking_complete"].volume_db == -16.0 and GameAudio._players[&"capture_success"].volume_db == -6.0,"烹饪完成独立降低10dB，捕获成功音量不变")
	for quality in [1,2,3]:
		await _prepare_collected()
		sm.acknowledge_cooking_guide()
		var modal = await _open_cooking()
		_check(not modal._stove_audio.playing,"尚未开火无炉声")
		_check(modal._stove_audio.volume_db == 0.0 and modal._stove_audio.stream.resource_path == "res://assets/audio/sfx/cooking_user.ogg","烹饪使用附件2且保持原始音量")
		modal._start_button.pressed.emit()
		_check(modal._stove_audio.playing and modal._stove_audio.stream.loop,"成功开火循环炉声")
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 2.0
		AudioServer.add_bus_effect(0,capture)
		var effect_index := AudioServer.get_bus_effect_count(0)-1
		# 暂停场景BGM，避免把背景音乐误判为炉声。
		scene.get_node("RestaurantBGM").stop()
		for player in GameAudio._players.values(): player.stop()
		capture.clear_buffer()
		await get_tree().create_timer(0.4).timeout
		var peak := 0.0
		for sample in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		_check(peak>0.00001 and peak<1.0,"实际炉声非静音且未削波",{"peak":peak})
		AudioServer.remove_bus_effect(0,effect_index)
		heard.clear()
		if quality == 2:
			var path: String = sm._active_save_path
			sm._active_save_path = ""
			modal._finish_result(quality,0.0,true)
			_check(not modal._stove_audio.playing and not heard.has(&"cooking_complete"),"保存失败停炉且无完成音")
			sm._active_save_path = path
		modal._finish_result(quality,0.0,true)
		_check(not modal._stove_audio.playing and not heard.has(&"cooking_complete"),"结束后停炉，等待结果才响完成音")
		await get_tree().create_timer(0.7).timeout
		_check(modal._result_popup.visible and heard.count(&"cooking_complete")==1,"各品质结果弹窗完成音一次："+str(quality))
		modal._show_pending_result()
		_check(heard.count(&"cooking_complete")==1,"重复显示结果不重复响")
		await _capture(evidence,"cooking_audio_quality_"+str(quality))
		modal.close_modal()
		_check(not modal._stove_audio.playing,"关闭结果后无炉声")
	await _prepare_collected()
	sm.acknowledge_cooking_guide()
	var modal = await _open_cooking()
	heard.clear()
	modal._on_cancel_pressed()
	_check(not modal._stove_audio.playing and not heard.has(&"cooking_complete"),"取消未完成烹饪不响")
	modal.open_for_order()
	modal._on_start_pressed()
	modal.close_modal()
	_check(not modal._stove_audio.playing and not heard.has(&"cooking_complete"),"烹饪中关闭停炉且无完成音")
	await _cleanup()
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.2).timeout
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
