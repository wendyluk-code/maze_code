extends "res://tools/tests/restaurant_rest05b.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_fresh()
		sm.data.warehouse_stock = {}
		var hud = await _open_restaurant()
		hud._open_day_menu()
		await get_tree().create_timer(0.2).timeout
		var menu = hud.day_menu
		_check(menu.visible and menu.empty_panel.visible and not menu.scroll.visible,"空库存展示居中框")
		_check(menu.message.text.is_empty() and menu.confirm_button.disabled,"底部无重复文案且不可开始营业")
		await _shot("empty_menu")
		menu.close()
		_check(not scene.get_node("Player").input_locked,"关闭恢复输入")
		for item in Recipe.INGREDIENTS: sm.data.warehouse_stock[item] = 20
		hud._open_day_menu()
		await get_tree().create_timer(0.2).timeout
		_check(not menu.empty_panel.visible and menu.scroll.visible and menu.list.get_child_count()>0,"有料理时恢复原选择列表")
		await _shot("available_menu")
		menu.close()
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
