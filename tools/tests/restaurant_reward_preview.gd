extends "res://tools/tests/restaurant_rest05b.gd"
## 仅预览数值反馈，不接业务事件。
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"预览隔离正式存档")
	get_window().size = Vector2i(1152,648)
	_fresh()
	var hud = await _open_restaurant()
	await get_tree().create_timer(0.3).timeout
	hud.customer_flow.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 120
	scene.add_child(layer)
	for negative in [false,true]:
		var labels: Array[Label] = []
		var index := 0
		for counter in [hud.reputation_counter,hud.gold_counter]:
			var label := Label.new()
			label.theme = SproutTheme.make_theme()
			label.text = ("-1" if index==0 else "-2") if negative else ("+60" if index==0 else "+12")
			label.add_theme_font_size_override("font_size",16)
			label.add_theme_color_override("font_color",Color("f4a49a") if negative else Color("e9f5b2"))
			label.add_theme_color_override("font_outline_color",SproutTheme.INK)
			label.add_theme_constant_override("outline_size",2)
			layer.add_child(label)
			var rect: Rect2 = counter.value_label.get_global_rect()
			label.position = Vector2(rect.end.x-7,rect.position.y-14)
			labels.append(label)
			index += 1
		await get_tree().process_frame
		await _shot("penalty_visible" if negative else "reward_visible")
		for label in labels:
			label.position.y -= 7
			label.modulate.a = 0.45
		await _shot("penalty_fading" if negative else "reward_fading")
		for label in labels: label.queue_free()
		await get_tree().process_frame
	await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)


