extends "res://tools/tests/restaurant_bgm.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures:
		get_tree().quit(1)
		return
	_completed()
	var save_path := ProjectSettings.globalize_path(sm.active_save_path()).replace("\\", "/")
	var isolated_root := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/")
	_check(save_path.begins_with(isolated_root+"/"), "所有测试写入位于隔离目录", {"save_path":save_path})
	if failures:
		get_tree().quit(1)
		return
	tm.active = false
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0,capture)
	var effect_index := AudioServer.get_bus_effect_count(0)-1
	for visit in range(2):
		var start = load("res://scenes/start_screen.tscn").instantiate()
		get_tree().root.add_child(start)
		get_tree().current_scene = start
		await get_tree().create_timer(0.4).timeout
		var music: AudioStreamPlayer = start.get_node("StartScreenBGM")
		_check(music.playing and music.stream.loop,"开始界面自动循环播放："+str(visit))
		_check(music.stream.resource_path == "res://assets/audio/bgm/start_screen.mp3","使用用户指定音频")
		_check(music.stream.get_length()>1.0,"音频可解码且时长有效")
		music.seek(10.0)
		capture.clear_buffer()
		await get_tree().create_timer(0.5).timeout
		_check(_peak(capture)>0.0001,"主总线有实际音乐输出")
		start.continue_button.pressed.emit()
		await get_tree().process_frame
		_check(start.save_modal.visible and music.playing,"打开存档选择音乐继续")
		start.save_modal.close_modal()
		await get_tree().create_timer(0.2).timeout
		_check(music.get_playback_position()>10.0,"关闭存档选择不重启音乐")
		GameAudio.interaction()
		_check(music.playing,"点击音与音乐共存")
		music.seek(music.stream.get_length()-0.3)
		await get_tree().create_timer(0.8).timeout
		_check(music.playing and music.get_playback_position()<2.0,"曲尾自动循环")
		await _shot("start_screen_bgm_"+str(visit))
		if visit == 0:
			start.queue_free()
		else:
			start._enter_game()
		await get_tree().create_timer(1.0).timeout
		_check(not is_instance_valid(music),"离开开始界面释放播放器")
		if visit == 1:
			_check(is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path != "res://scenes/start_screen.tscn","实际进入游戏转场成功")
			get_tree().current_scene.queue_free()
		for player in GameAudio._players.values(): player.stop()
		await get_tree().create_timer(0.2).timeout
		capture.clear_buffer()
		await get_tree().create_timer(0.2).timeout
		_check(_peak(capture)<0.00001,"场景释放后无残留音乐")
	AudioServer.remove_bus_effect(0,effect_index)
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
