extends "res://tools/tests/audio_interactions.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures:
		get_tree().quit(1)
		return
	GameAudio.cue_played.connect(_heard)
	_check(GameAudio.STREAMS[&"serve_correct"].resource_path=="res://assets/audio/sfx/serve_correct.wav","正确交付使用附件1")
	await _first_order()
	_check(cues.count(&"serve_correct")==1,"铁山首单正确交付只响一次")
	for kind in ["food","water","wrong","bad_water","unwanted","save_failed"]:
		await _service_audio(kind)
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.2).timeout
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
