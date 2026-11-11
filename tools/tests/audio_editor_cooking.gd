extends "res://tools/tests/cooking_countdown_input.gd"
const AudioMix = preload("res://scripts/audio/audio_mix.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures: get_tree().quit(1); return
	sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
	sm.audio_guard_root = OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/").simplify_path().to_lower()
	GameAudio.mix.save_path = evidence+"/mix.json"
	GameAudio.mix.preview_path = evidence+"/preview.json"
	await _prepare_collected()
	sm.acknowledge_cooking_guide()
	var modal := await _open_cooking()
	_check(not modal._stove_audio.playing, "尚未开火无炉声")
	await _click(modal._start_button)
	_check(modal._stove_audio.playing, "真实点击开火启动循环声")
	await get_tree().create_timer(0.3).timeout
	var position: float = modal._stove_audio.get_playback_position()
	AudioMix.write_json(GameAudio.mix.save_path, {"version":1, "cues":{"cooking_loop":-18}, "groups":{}})
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(modal._stove_audio.volume_db, -18), "开火过程中实时降低音量")
	_check(modal._stove_audio.playing and modal._stove_audio.get_playback_position() > position, "调音不打断烹饪循环")
	await _capture(evidence, "cooking_live_volume")
	await _click(modal._finish_button)
	await get_tree().create_timer(0.7).timeout
	_check(not modal._stove_audio.playing and modal._result_popup.visible, "真实完成后停炉并显示结果")
	await _capture(evidence, "cooking_finished")
	await _click(modal._result_popup._confirm_button)
	_check(await _wait_until(func(): return not modal.visible and not scene.get_node("Player").input_locked, 240), "确认烹饪结果恢复玩家输入")
	await _cleanup()
	_check(sm.audio_guard_blocked == 0, "存档写入未越过隔离目录")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
