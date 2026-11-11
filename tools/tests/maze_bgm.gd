extends "res://tools/tests/restaurant_bgm.gd"
const Fade := preload("res://scripts/ui/components/scene_transition.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures:
		get_tree().quit(1)
		return
	_completed()
	tm.active = false
	sm.data["capture_first_visit_started"] = true
	sm.data["first_exploration_gate_v1"] = "done"
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.cancel_maze_entry()
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	var music := GameAudio.maze_music
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0,capture)
	var effect_index := AudioServer.get_bus_effect_count(0)-1
	var first := true
	for path in ["maze_entry","maze_moss_pool","maze_salt_pool","maze_fenshui","maze_entry"]:
		var before := music.get_playback_position()
		capture.clear_buffer()
		var err := await Fade.change_scene(get_tree(),load("res://scenes/"+path+".tscn"))
		_check(err == OK,"真实渐隐切图成功："+path)
		_check(music == GameAudio.maze_music and music.playing,"所有迷宫共用持续播放的播放器："+path)
		if first:
			music.seek(20.0)
			first = false
		else:
			_check(music.get_playback_position()>before,"切图播放位置前进而非归零："+path)
		_check(_peak(capture)>0.00001,"转场期间实际有音乐输出："+path)
		await get_tree().create_timer(0.1).timeout
	_check(music.stream.loop and absf(music.stream.get_length()-180.0)<0.1,"三分钟循环音乐")
	music.seek(179.7)
	await get_tree().create_timer(0.8).timeout
	_check(music.playing and music.get_playback_position()<2.0,"播放至末尾自动循环")
	var position := music.get_playback_position()
	GameAudio.interaction()
	_check(music.playing and music.get_playback_position()>=position,"交互音不重启探索音乐")
	await _shot("maze_bgm_continuous")
	await Fade.change_scene(get_tree(),load("res://scenes/restaurant_map_2d.tscn"))
	await get_tree().process_frame
	_check(not music.playing,"回餐厅停止迷宫音乐")
	_check(GameAudio.restaurant_music.playing,"餐厅原音乐正常接管")
	await Fade.change_scene(get_tree(),load("res://scenes/start_screen.tscn"))
	await get_tree().process_frame
	_check(not music.playing and get_tree().current_scene.get_node("StartScreenBGM").playing,"开始界面无迷宫音乐叠播")
	await Fade.change_scene(get_tree(),load("res://scenes/maze_entry.tscn"))
	await get_tree().process_frame
	_check(music.playing and music.get_playback_position()<2.0,"重新进入迷宫从头播放")
	get_tree().current_scene.queue_free()
	music.stop()
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.2).timeout
	AudioServer.remove_bus_effect(0,effect_index)
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
