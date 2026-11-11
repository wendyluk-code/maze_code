extends "res://tools/tests/restaurant_rest05b.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	for old_delay in [0.0,12.0]:
		_fresh()
		_open({A:3})
		var first := _order(false)
		sm.data[Day.KEY].arrival_left = old_delay
		var before: Dictionary = sm.data.duplicate(true)
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not sm.accept_restaurant_customer(first.id).success and sm.data==before,"失败接单订单与等待时间均回滚")
		sm._active_save_path = path
		_check(sm.accept_restaurant_customer(first.id).success,"接单成功")
		var delay: float = Day.snapshot(sm).arrival_left
		_check(delay>=2 and delay<=5,"旧倒计时无论已耗尽或未耗尽均重设2～5秒")
		_check(not Cycle.arrive(sm).get("created",false),"接单同帧不生成下一客")
		sm.save()
		sm.load_data()
		_check(is_equal_approx(float(Day.snapshot(sm).arrival_left),delay),"读档保持剩余等待不重新随机")
		Cycle.tick(sm,delay-0.1)
		_check(not Cycle.arrive(sm).get("created",false),"等待结束前不来客")
		Cycle.tick(sm,0.11)
		_check(Cycle.arrive(sm).get("created",false),"等待完成且有空位才来客")
	_fresh()
	_open({A:3})
	var first := _order(false)
	sm.data[Day.KEY].arrival_left = 0.0
	var hud = await _open_restaurant()
	hud._player.position = _stand(scene.get_node("InteractPoints/Register"))
	hud._player.last_valid = hud._player.position
	await _send_key(KEY_E)
	_check(sm.restaurant_customers().front.is_empty(),"实际E接单后前台留空")
	await get_tree().create_timer(1.5).timeout
	_check(sm.restaurant_customers().front.is_empty(),"实际游戏1.5秒内不立刻补第二客")
	await _wait_until(func(): return not sm.restaurant_customers().front.is_empty(),300)
	_check(not sm.restaurant_customers().front.is_empty(),"实际游戏等待后恢复来客")
	await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
