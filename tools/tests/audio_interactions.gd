extends "res://tools/tests/tieshan_bubble_interaction.gd"
const ThreeAudio := preload("res://scripts/restaurant/three_seat_layout.gd")
var cues: Array[StringName] = []

func _heard(cue: StringName) -> void:
	cues.append(cue)
	_check(GameAudio._players[cue].playing, "实际播放器启动：" + str(cue))

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	GameAudio.cue_played.connect(_heard)
	for cue in GameAudio.STREAMS:
		_check(GameAudio.STREAMS[cue].get_length() > 0, "已导入音频：" + str(cue))
	if failures == 0:
		cues.clear()
		await _first_order()
		_check(cues.count(&"serve_correct") == 1, "铁山首单成功仅一次S08")
		for kind in ["food", "water", "wrong", "bad_water", "unwanted", "save_failed"]:
			await _service_audio(kind)
		await _world_buttons()
		await _capture_audio(true)
		await _capture_audio(false)
	# 结果音仍在播放时直接退出会遗留混音线程的资源引用。
	for player in GameAudio._players.values(): player.stop()
	await get_tree().create_timer(0.15).timeout
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _arrive_audio() -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var order: Dictionary = sm.ensure_restaurant_customer().order
	_check(sm.advance_restaurant_customer(order.id,"arriving","front").success, "候客就绪")
	_check(sm.accept_restaurant_customer(order.id).success, "接单")
	_check(sm.advance_restaurant_customer(order.id,"seating","waiting").success, "入座")
	return sm.restaurant_customer_order(order.id)

func _service_audio(kind: String, verify_enjoy := false) -> void:
	_seed_cycle()
	var order := _arrive_audio()
	_stage(order.id, "drink" if kind in ["water", "bad_water"] else "food", 100)
	sm.data.restaurant_customers.seated[0].drink_ice = 0
	if kind in ["water", "bad_water", "unwanted"]:
		_make_cup(0.76 if kind == "bad_water" else 0.65)
	elif kind == "wrong": _food()
	else:
		_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).success, "取料")
		_check(sm.start_cooking("salt_grilled_rockmane").success, "烹饪")
		_check(sm.finish_first_order_cooking(3).success, "成品")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	var player = scene.get_node("Player")
	player.position = ThreeAudio.service_point(0)
	player.last_valid = player.position
	await get_tree().create_timer(0.2).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.customer_flow.selected_id == order.id, "近距选中顾客：" + kind)
	var path: String = sm._active_save_path
	if kind == "save_failed": sm._active_save_path = ""
	cues.clear()
	await _send_key(KEY_E)
	_check(cues.count(&"interact") == 1, "真实E交付仅一次S06：" + kind)
	_check(cues.count(&"serve_correct") == (1 if kind in ["food","water"] else 0), "按交付结果播放S08：" + kind)
	_check(cues.count(&"failure") == (1 if kind in ["wrong","bad_water","unwanted"] else 0), "经营失败提示与结果一致：" + kind)
	if verify_enjoy:
		_check(cues.count(&"food_enjoy") == 0 and cues.count(&"water_enjoy") == 0, "交付提示期间不提前播放赞叹")
		await get_tree().create_timer(2.8).timeout
		_check(cues.count(&"food_enjoy") == 0, "正确料理不追加wow")
		_check(cues.count(&"water_enjoy") == 0, "正确甘露水不追加啊声")
	sm._active_save_path = path
	if kind == "save_failed":
		await _send_key(KEY_E)
		_check(cues.count(&"serve_correct") == 1, "保存恢复重试只在成功后响")
		if verify_enjoy:
			await get_tree().create_timer(2.8).timeout
			_check(cues.count(&"food_enjoy") == 0, "保存成功重试也不追加料理赞叹")
	await _shot("audio_" + kind)
	cues.clear()
	await get_tree().create_timer(0.1).timeout
	hud.customer_flow._deliver(order.id) if kind in ["food","save_failed"] else hud.ganlu.serve(order.id)
	_check(cues.count(&"serve_correct") == 0, "重复交付不重放S08：" + kind)
	scene.queue_free()
	await get_tree().process_frame

func _world_buttons() -> void:
	_seed_cycle()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	var player = scene.get_node("Player")
	var pot = scene.get_node("InteractPoints/Cauldron")
	player.position = _stand(pot)
	player.last_valid = player.position
	await get_tree().create_timer(0.2).timeout
	cues.clear()
	await _world_click(scene.get_node("UIOverlay")._buttons[pot])
	_check(cues.count(&"interact") == 1, "鼠标点击E烹饪按钮响一次")
	await _send_key(KEY_ESCAPE)
	player.input_locked = true
	cues.clear()
	await _send_key(KEY_E)
	_check(cues.is_empty(), "输入锁下E不响")
	player.input_locked = false
	var echo := InputEventKey.new()
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	await get_tree().process_frame
	_check(cues.is_empty(), "按键重复事件不响")
	scene.queue_free()
	await get_tree().process_frame

func _capture_audio(caught: bool) -> void:
	_completed()
	sm.data["first_exploration_gate_v1"] = "done"
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	tm.active = false
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.7).timeout
	var flow = maze.capture_flow
	sm.data["first_exploration_gate_v1"] = "done"
	maze.player.position = Catalog.find("slime_1").position + Vector2(0,-35)
	sm.data[Run.KEY].combat.actors.slime_1.hp = 0
	cues.clear()
	flow._encounter("slime_1")
	await get_tree().create_timer(0.3).timeout
	_check(flow.dialog.visible, "真实遭遇弹窗")
	_check(cues.count(&"capture_success") == 1, "战斗胜利弹窗提示音一次")
	await flow._choose(true)
	cues.clear()
	flow._start_attempt()
	_check(cues.count(&"capture_throw") == 1, "成功开始捕获时抛网音一次")
	flow._start_attempt()
	_check(cues.count(&"capture_throw") == 1, "重复开始不重播抛网音")
	flow.attempt.mode = "suppress"
	flow.attempt.j_down = false
	var press := InputEventKey.new()
	press.keycode = KEY_J
	press.pressed = true
	flow.attempt._input(press)
	flow.attempt._input(press)
	_check(flow.attempt.press_audio.playing and flow.attempt.press_index == 1, "J有效按下启动第一段，按住不重播")
	press.pressed = false
	flow.attempt._input(press)
	press.pressed = true
	flow.attempt._input(press)
	_check(flow.attempt.press_audio.playing and flow.attempt.press_audio_second.playing and flow.attempt.press_index == 2, "快速再按J叠接第二种ding")
	sm.data[Run.KEY].monsters.slime_1.guaranteed = caught
	sm.data[Run.KEY].monsters.slime_1.capture_roll = 0.0 if caught else 0.99
	# 已完成首探教学的存档，不受教学必捕获覆盖。
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	cues.clear()
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	flow._finish_attempt(caught)
	_check(cues.is_empty(), "捕获保存失败无结果音")
	sm._active_save_path = path
	flow._finish_attempt(caught)
	await get_tree().create_timer(0.1).timeout
	_check(cues.count(&"capture_success") == (1 if caught else 0), "捕获成功音与实际结果一致")
	_check(cues.count(&"capture_failure") == (0 if caught else 1), "捕获失败音与实际结果一致")
	_check(flow.reward.visible if caught else flow.dialog.visible, "结果弹窗实际可见")
	await _shot("audio_capture_" + str(caught))
	await get_tree().create_timer(0.8).timeout
	_check(cues.size() == 1, "弹窗停留不重播")
	maze.queue_free()
	await get_tree().process_frame
