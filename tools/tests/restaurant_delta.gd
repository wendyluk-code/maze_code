extends "res://tools/tests/restaurant_rest05b.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_fresh()
	var hud = await _open_restaurant()
	await get_tree().create_timer(0.2).timeout
	var counter = hud.gold_counter
	counter.show_delta(0)
	_check(not counter.delta_active,"零变化不显示")
	counter.show_delta(12)
	counter.show_delta(-2)
	await get_tree().create_timer(0.3).timeout
	var label = counter.value_label.get_node("BalanceDelta")
	_check(label.text=="+12" and label.get_theme_font_size("font_size")==14,"小号正数飘字")
	_check(counter.delta_queue==[-2],"连续变化排队不覆盖")
	_check(label.position.y< -14 and label.modulate.a>0.9,"渐入上升")
	await _shot("positive_delta")
	await get_tree().create_timer(1.25).timeout
	label = counter.value_label.get_node("BalanceDelta")
	_check(label.text=="-2","负数依次显示")
	await _shot("negative_delta")
	await get_tree().create_timer(1.2).timeout
	_check(not counter.delta_active and counter.value_label.get_child_count()==0,"淡出释放节点")
	await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
