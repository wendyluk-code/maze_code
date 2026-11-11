extends "res://tools/tests/business_music_audio.gd"
const MixerPanelScript = preload("res://addons/audio_mixer/mixer_panel.gd")
const AudioCatalog = preload("res://scripts/audio/audio_catalog.gd")
const AudioMix = preload("res://scripts/audio/audio_mix.gd")
var mixer_panel: Control
var mix_root := ""

func _seed_cycle() -> void:
	super._seed_cycle()
	# 验收交付时使用教学已完成的存档，与 enjoy_audio 的现行夹具一致。
	sm.data["ganlu_lessons_v1"] = {"warm":true, "iced":true, "ready":true, "spoiled":true}

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "实际存档隔离")
	if failures: get_tree().quit(1); return
	sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
	sm.audio_guard_root = OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/").simplify_path().to_lower()
	mix_root = evidence + "/mix"
	GameAudio.mix.save_path = mix_root + "/saved.json"
	GameAudio.mix.preview_path = mix_root + "/preview.json"
	GameAudio.mix.load_saved()
	GameAudio.mix.refresh()
	GameAudio.cue_played.connect(_heard)
	get_tree().current_scene = null
	await _panel_flow()
	await _local_players()
	await _service_audio("food", true)
	await _service_audio("water", true)
	await _capture_audio(false)
	await _combat_feedback()
	_check(sm.audio_guard_blocked == 0, "实际存档写入未越过隔离目录")
	GameAudio.set_world_music(&"")
	for audio_player in GameAudio._players.values(): audio_player.stop()
	if is_instance_valid(scene): scene.queue_free()
	if is_instance_valid(maze): maze.queue_free()
	await get_tree().create_timer(0.2).timeout
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "results":results}, "\t"))
	print("AUDIO_EDITOR: ", checks, " checks; ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _select_audio(id: String) -> void:
	mixer_panel.selected_id = id
	mixer_panel.search.text = ""
	mixer_panel.category.select(0)
	mixer_panel.usage_filter.select(0)
	mixer_panel._rebuild_list()

func _panel_flow() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("242830")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	mixer_panel = MixerPanelScript.new()
	mixer_panel.mix.save_path = GameAudio.mix.save_path
	mixer_panel.mix.preview_path = GameAudio.mix.preview_path
	layer.add_child(mixer_panel)
	mixer_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mixer_panel.offset_left = 16
	mixer_panel.offset_top = 16
	mixer_panel.offset_right = -16
	mixer_panel.offset_bottom = -16
	await get_tree().process_frame
	_check(mixer_panel.rows.size() == 53, "完整用途目录含共用素材及备用素材", {"rows":mixer_panel.rows.size()})
	var paths := {}
	for entry in mixer_panel.rows:
		if entry.path.is_empty(): continue
		paths[entry.path] = true
		var stream: AudioStream = load(entry.path)
		_check(stream != null and stream.get_length() > 0, "素材可试听："+entry.id)
	_check(paths.size() == 49, "全部49个文件已收录", {"count":paths.size()})
	for cue in GameAudio.STREAMS:
		_check(mixer_panel.mix.entries.has(String(cue)), "全局用途已登记："+str(cue))
	_select_audio("order_accepted")
	await _click(mixer_panel.volume_slider)
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, mixer_panel.volume_slider.value) and mixer_panel.dirty, "实际鼠标点击滑条触发实时调音")
	mixer_panel.play_preview()
	_check(mixer_panel.player.playing, "面板实际试听启动")
	mixer_panel.volume_number.value = -20
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -20), "未保存修改通过文件同步到游戏播放器")
	_check(is_equal_approx(GameAudio._players[&"serve_correct"].volume_db, -6), "共用素材的交付音量保持独立")
	_check(is_equal_approx(mixer_panel.player.volume_db, -20), "面板试听同步音量")
	mixer_panel.group_controls["音效"].value = -3
	mixer_panel.group_controls["总音量"].value = -2
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -25), "单音、分类和总音量正确叠加")
	mixer_panel.live.button_pressed = false
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -6), "关闭实时预览立即恢复已保存设置")
	mixer_panel.live.button_pressed = true
	await get_tree().create_timer(0.35).timeout
	mixer_panel.save_changes()
	await get_tree().create_timer(0.35).timeout
	_check(not mixer_panel.dirty and is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -25), "保存后继续应用且清除未保存状态")
	var restarted := AudioMix.new()
	restarted.save_path = GameAudio.mix.save_path
	restarted.allow_preview = false
	restarted.load_saved()
	restarted.refresh()
	_check(is_equal_approx(restarted.effective_db("order_accepted"), -25), "新管理器从磁盘恢复保存音量")
	# 留存跨进程重启验收输入，不修改项目正式配置。
	AudioMix.write_json(mix_root+"/restart.json", restarted.settings)
	mixer_panel.volume_slider.value = -30
	mixer_panel.discard_changes()
	_check(is_equal_approx(mixer_panel.volume_number.value, -20), "撤销恢复已保存单音值")
	var corrupt := FileAccess.open(GameAudio.mix.save_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -25), "损坏配置保留上次有效音量")
	mixer_panel.save_changes()
	mixer_panel.group_controls["音效"].value = 0
	mixer_panel.group_controls["总音量"].value = 0
	mixer_panel.reset_selected()
	mixer_panel.save_changes()
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -6), "恢复此项默认并保存")
	_select_audio("music_restaurant")
	GameAudio.set_world_music(&"restaurant")
	await get_tree().create_timer(0.25).timeout
	var position: float = GameAudio.restaurant_music.get_playback_position()
	mixer_panel.volume_number.value = -24
	await get_tree().create_timer(0.35).timeout
	_check(GameAudio.restaurant_music.playing and GameAudio.restaurant_music.get_playback_position() > position, "实时调音乐不重启播放位置")
	_check(is_equal_approx(GameAudio.restaurant_music.volume_db, -24), "运行中音乐音量即时更新")
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot("mixer_panel_"+str(resolution.x))
		_check(mixer_panel.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x, "面板适配宽度 "+str(resolution.x))
	# 底部面板常用高度，确认所有操作区能显示或滚动访问。
	mixer_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mixer_panel.offset_left = 16
	mixer_panel.offset_right = -16
	mixer_panel.offset_top = 16
	mixer_panel.offset_bottom = 346
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("mixer_panel_compact")
	_check(mixer_panel.size.y <= 350, "底部面板330像素布局")
	mixer_panel.discard_changes()
	# 旧预览过期后自动回到项目音量。
	AudioMix.write_json(GameAudio.mix.preview_path, {"session":"expired", "expires":Time.get_unix_time_from_system()-1, "mix":{"version":1,"cues":{"music_restaurant":-40},"groups":{}}})
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(GameAudio.restaurant_music.volume_db, -12), "失效预览不污染后续游戏启动")
	mixer_panel.search.text = "不存在的声音"
	mixer_panel._rebuild_list()
	_check(mixer_panel.selected_id.is_empty(), "无匹配搜索可安全停止试听")
	mixer_panel.search.text = ""
	mixer_panel.usage_filter.select(3)
	mixer_panel._rebuild_list()
	_check(mixer_panel.tree.get_root().get_child_count() == 10, "备用素材筛选")
	GameAudio.set_world_music(&"")
	await _measure_output()
	layer.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

func _measure_output() -> void:
	for audio_player in GameAudio._players.values(): audio_player.stop()
	_select_audio("salt_dull")
	mixer_panel.loop_button.button_pressed = true
	mixer_panel.play_preview()
	await get_tree().create_timer(0.37).timeout
	_check(mixer_panel.player.playing, "短音循环试听持续播放")
	mixer_panel.stop_preview()
	_check(not mixer_panel.player.playing, "停止循环试听")
	mixer_panel.loop_button.button_pressed = false
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0, capture)
	var index := AudioServer.get_bus_effect_count(0)-1
	var peaks: Array[float] = []
	for db in [0, -12]:
		mixer_panel.volume_number.value = db
		capture.clear_buffer()
		mixer_panel.play_preview()
		await get_tree().create_timer(0.35).timeout
		var peak := 0.0
		for sample in capture.get_buffer(capture.get_frames_available()): peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		peaks.append(peak)
	AudioServer.remove_bus_effect(0,index)
	_check(peaks[0] > 0.001 and peaks[0] < 1.0, "真实混音输出非静音且未削波", {"peaks":peaks})
	_check(peaks[0] > 0 and absf(peaks[1]/peaks[0]-db_to_linear(-12)) < 0.04, "实际输出衰减符合降低12分贝", {"peaks":peaks})
	mixer_panel.discard_changes()

func _local_players() -> void:
	_completed()
	tm.active = false
	sm.data["first_exploration_gate_v1"] = "done"
	sm.data.ch2_guide_01 = {"step":"done", "seen":{}, "banked":{}, "recipe":"", "revision":2}
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.3).timeout
	var cooking := scene.get_node("HUD/CookingModal")
	var dialogue: Control = load("res://scenes/ui/dialog_box.tscn").instantiate()
	add_child(dialogue)
	var pouring := preload("res://scripts/ui/components/ganlu_pour_modal.gd").new()
	add_child(pouring)
	var capture_modal := preload("res://scripts/ui/components/capture_attempt_modal.gd").new()
	add_child(capture_modal)
	var controlled: Dictionary = {"cooking_loop":cooking._stove_audio, "dialogue_typing":dialogue._typing_audio, "ganlu_pour":pouring.pour_audio, "capture_struggle":capture_modal.struggle_audio, "capture_press_continuous":capture_modal.press_audio, "capture_flash":capture_modal.flash_audio}
	var settings := {"version":1, "cues":{}, "groups":{}}
	for id in controlled: settings.cues[id] = -29.0
	AudioMix.write_json(GameAudio.mix.save_path, settings)
	await get_tree().create_timer(0.35).timeout
	for id in controlled: _check(is_equal_approx(controlled[id].volume_db, -29), "实际组件播放器接入实时音量："+id)
	dialogue.queue_free()
	pouring.queue_free()
	capture_modal.queue_free()
	scene.queue_free()
	await get_tree().process_frame
	var start: Control = load("res://scenes/start_screen.tscn").instantiate()
	get_tree().root.add_child(start)
	get_tree().current_scene = start
	settings.cues["music_start"] = -28.0
	AudioMix.write_json(GameAudio.mix.save_path, settings)
	await get_tree().create_timer(0.35).timeout
	_check(start.get_node("StartScreenBGM").playing and is_equal_approx(start.get_node("StartScreenBGM").volume_db, -28), "开始界面音乐实际播放且实时调音")
	start.queue_free()
	await get_tree().process_frame
	AudioMix.write_json(GameAudio.mix.save_path, {"version":1, "cues":{}, "groups":{}})
	await get_tree().create_timer(0.35).timeout
