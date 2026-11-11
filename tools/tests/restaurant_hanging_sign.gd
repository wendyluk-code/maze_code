extends "res://tools/tests/restaurant_day_r1.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_completed()
		scene = RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.6).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var sign = hud.find_child("RestaurantDaySign", true, false)
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			await get_tree().process_frame
			await get_tree().process_frame
			sign.set_display(1)
			var title = sign.get_node("Status")
			var details = sign.get_node("DayAndCountdown")
			_check(absf(title.get_global_rect().get_center().x - resolution.x / 2.0) < 1, "牌内文字水平居中")
			_check(absf(title.get_global_rect().get_center().y - hud.gold_counter.get_global_rect().get_center().y) <= 3, "文字与顶部资源行对齐")
			_check(absf(details.get_global_rect().get_center().x - title.get_global_rect().get_center().x) < 1 and details.position.y >= 56, "日期倒计时位于牌下居中")
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "sign_%d" % resolution.x)
			await _click(sign.get_node("OpenMenu"))
			_check(hud.day_menu.visible and hud._player.input_locked, "三角按钮打开菜单并锁定输入")
			hud.day_menu.close()
			await get_tree().process_frame
			_check(not hud.day_menu.visible and not hud._player.input_locked, "关闭菜单恢复输入")
	var report := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	get_tree().quit(1 if failures else 0)
