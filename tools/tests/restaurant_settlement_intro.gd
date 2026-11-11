extends "res://tools/tests/restaurant_rest05b.gd"
var heard: Array[StringName] = []

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离存档")
	get_node("/root/GameAudio").cue_played.connect(func(cue: StringName): heard.append(cue))
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_fresh()
		_open({"slime_candy":1})
		Cycle.settle(sm,"time")
		var hud = await _open_restaurant()
		await _wait_until(func(): return is_instance_valid(hud.day_settlement),90)
		var modal = hud.day_settlement
		for closed_day in [false,true]:
			var stats: Dictionary = modal.current_stats.duplicate(true)
			stats.closed_day = closed_day
			heard.clear()
			modal.open_with_intro(stats)
			var expected: StringName = &"restaurant_closed" if closed_day else &"cooking_complete"
			_check(heard.count(expected)==1,"标题出现播放对应音效一次")
			_check(get_node("/root/GameAudio")._players[expected].playing,"对应音频播放器已启动")
			var before: Dictionary = sm.data.duplicate(true)
			_check(modal.introducing and not modal._panel.visible,"标题先于结算出现")
			modal.close_modal()
			_check(modal.visible and sm.data==before,"展开期间不能跳过或提前进入明日")
			await get_tree().create_timer(0.65).timeout
			_check(modal.chart.progress==0 and modal._confirm_button.disabled,"标题期间图表停在零且按钮禁用")
			await _shot("closed_title" if closed_day else "complete_title")
			await get_tree().create_timer(0.95).timeout
			_check(modal._panel.visible and modal.introducing,"翻转显示结算")
			await _shot("closed_flip" if closed_day else "complete_flip")
			await get_tree().create_timer(1.2).timeout
			_check(not modal.introducing and modal.chart.progress==1,"展开翻转完成后图表到达实际值")
			_check(sm.data==before,"动画不改变账目")
			_check(heard.count(expected)==1,"停留与翻转不重复播放标题音效")
			_check(not modal._confirm_button.disabled,"结束恢复按钮")
			await _shot("settlement_final")
		modal.close_modal()
		_check(not modal.visible and not scene.get_node("Player").input_locked,"确认明日准备恢复输入")
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
