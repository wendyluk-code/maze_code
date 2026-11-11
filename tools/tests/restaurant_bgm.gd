extends "res://tools/tests/audio_interactions.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	_completed()
	tm.active = false
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	var effect_index := AudioServer.get_bus_effect_count(0)-1
	for visit in range(2):
		scene = RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		GameAudio._sync_maze_music()
		await get_tree().create_timer(0.5).timeout
		var music: AudioStreamPlayer = GameAudio.restaurant_music
		_check(music.playing, "进入餐厅自动播放："+str(visit))
		_check(absf(music.stream.get_length()-180.0)<0.1, "完整三分钟曲长")
		_check(music.stream.loop, "餐厅音乐启用循环")
		capture.clear_buffer()
		await get_tree().create_timer(0.5).timeout
		_check(_peak(capture)>0.0001, "背景音乐实际混音输出")
		var position := music.get_playback_position()
		GameAudio.interaction()
		_check(music.playing and music.get_playback_position()>=position, "点击音不重启音乐")
		get_tree().paused = true
		await get_tree().create_timer(0.15, true).timeout
		_check(music.playing, "暂停界面期间音乐继续")
		get_tree().paused = false
		music.seek(179.7)
		await get_tree().create_timer(0.8).timeout
		_check(music.playing and music.get_playback_position()<2.0, "曲尾后自动从头播放")
		await _shot("restaurant_bgm_"+str(visit))
		for player in GameAudio._players.values(): player.stop()
		scene.queue_free()
		GameAudio.set_world_music(&"")
		await get_tree().create_timer(0.2).timeout
		_check(not music.playing, "离开餐厅停止全局餐厅播放器")
		capture.clear_buffer()
		await get_tree().create_timer(0.2).timeout
		_check(_peak(capture)<0.00001, "离场后混音静音，无残留叠播")
	AudioServer.remove_bus_effect(0,effect_index)
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	return peak
