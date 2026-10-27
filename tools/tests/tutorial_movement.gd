extends "res://tools/tests/ch2_entry_state.gd"
const Guide := preload("res://scripts/ch2_exploration_guide.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		await _arrival_overlap()
		await _all_dialogs()
		await _ending_dialogs()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("TUTORIAL_MOVEMENT ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _arrival_overlap() -> void:
	_completed()
	# 建立已有候客，固定由下一步触发首次来客教学，避免帧速影响触发时序。
	sm.ensure_restaurant_customer()
	await _open_scene()
	var player = scene.get_node("Player")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.customer_flow
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	_check(warehouse.visible, "来客前真实打开仓库")
	flow._start_first_arrival_tutorial()
	await get_tree().create_timer(0.9).timeout
	await _shot("arrival_with_warehouse")
	await _send_key(KEY_ESCAPE)
	for i in range(16):
		await get_tree().create_timer(0.15).timeout
		if flow._dialog.visible: await _send_key(KEY_E)
	await _probe(player, "仓库与首次来客教学结束")
	await _shot("arrival_closed")
	await _close_scene()

func _all_dialogs() -> void:
	_completed()
	sm.ensure_restaurant_customer()
	await _open_scene()
	await get_tree().create_timer(0.3).timeout
	var player = scene.get_node("Player")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	# 所有第一章对白逐项走正式管理器和E关闭，接一个可行动步骤检验锁释放。
	var index := 0
	for original in tm.chapter_1_lesson():
		if original.get("type", "") != "dialog": continue
		index += 1
		var step: Dictionary = original.duplicate(true)
		step.erase("wrapup_id")
		tm.start([step, {"type":"interact", "target":"仓库"}])
		for press in range(12):
			if tm.idx > 0: break
			await _send_key(KEY_E)
		await _probe(player, "第一章对白%d关闭" % index)
		tm._cancel_current_run()
	_check(index > 15, "覆盖第一章开场与同行对白清单")
	# 连续对白结束前保持锁定，不能把合法下一段对白误解为卡死。
	tm.start([{"type":"dialog","speaker":"芽芽","lines":["第一句"]},{"type":"dialog","speaker":"芽芽","lines":["第二句"]},{"type":"interact","target":"仓库"}])
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _probe(player, "连续对白第二句仍在显示", false)
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _probe(player, "连续对白全部关闭")
	tm._cancel_current_run()
	var g = hud.exploration_guide
	# 全部第二章说明使用正式explain/按E存标记/clear路径；同时检查上层业务锁。
	sm.data[Guide.KEY] = {"revision":2,"step":"entrance","seen":{},"banked":{}}
	for id in Guide.LINES:
		g.explain(id, Guide.LINES[id], [])
		await get_tree().create_timer(0.08).timeout
		await _probe(player, "第二章说明中："+id, false)
		await _send_key(KEY_E)
		await _send_key(KEY_E)
		await get_tree().create_timer(0.08).timeout
		_check(not g.reading, "E关闭第二章说明："+id)
		await _probe(player, "第二章说明关闭："+id)
	hud._lock_player()
	g.explain("nested_modal", "弹窗内说明", [])
	await get_tree().create_timer(0.08).timeout
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _probe(player, "说明关闭后底层弹窗仍持锁", false)
	hud._unlock_player()
	await _probe(player, "底层弹窗关闭恢复")
	# 餐厅新教学等待仓库先关闭，不能保存仓库的锁定状态再反向恢复。
	sm.data[Guide.KEY] = {"revision":2,"step":"recipe","seen":{},"banked":{}}
	hud._lock_player()
	await get_tree().create_timer(0.2).timeout
	_check(not g.reading, "餐厅食谱说明等待其他业务释放锁")
	hud._unlock_player()
	await get_tree().create_timer(0.15).timeout
	_check(g.reading, "空闲后食谱说明正常开始")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _probe(player, "食谱说明完成恢复")
	await _shot("all_dialogs_movement")
	await _close_scene()

func _probe(player: Node, label_text: String, movable := true) -> void:
	_check(player.input_locked == not movable and player.is_physics_processing() == movable, label_text+"：输入锁与物理帧", {"locked":player.input_locked,"physics":player.is_physics_processing()})
	# 每个方向从同一合法开阔点起步，避免把道路边缘当成输入锁。
	var origin: Vector2 = player.walk_zone.get_spawn_point(player.collision_radius_world())
	for pair in [[KEY_W,"ui_up"],[KEY_A,"ui_left"],[KEY_S,"ui_down"],[KEY_D,"ui_right"]]:
		player.global_position = origin
		player.last_valid = origin
		var event := InputEventKey.new()
		event.keycode = pair[0]
		event.physical_keycode = pair[0]
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().create_timer(0.08).timeout
		event = InputEventKey.new()
		event.keycode = pair[0]
		event.physical_keycode = pair[0]
		event.pressed = false
		Input.parse_input_event(event)
		await get_tree().process_frame
		_check(player.global_position.distance_to(origin) > 1.0 if movable else player.global_position.distance_to(origin) < 0.1, label_text+"："+OS.get_keycode_string(pair[0])+"实际位移")

func _ending_dialogs() -> void:
	_seed()
	sm.advance_chapter_1_outro("party")
	await _open_scene()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase == "home" and not tm._chapter_outro._busy, 240), "章末之家说明就绪")
	var player = scene.get_node("Player")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return tm._chapter_outro.phase == "maze" and not tm._chapter_outro._busy, 240), "E关闭之家说明进入迷宫说明")
	await _probe(player, "章末下一段说明仍在进行", false)
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return tm._chapter_outro.phase == "title", 240), "E关闭迷宫说明进入章节画面")
	# 镜头回收0.8秒后才开始章末渐显；帧数不能替代实际动画时长。
	await get_tree().create_timer(4.5).timeout
	_check(await _wait_until(func(): return tm._chapter_outro._ending._ready_for_input, 600), "章末继续提示准备完成")
	var release := InputEventKey.new()
	release.keycode = KEY_E
	get_viewport().push_input(release)
	await get_tree().process_frame
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return not tm.active, 240), "E关闭章末画面")
	# 来客说明可能接续章末，结束后才检查自由行走。
	var flow = get_tree().get_first_node_in_group("restaurant_hud").customer_flow
	await get_tree().create_timer(0.7).timeout
	for i in range(5):
		if not flow._arrival_tutorial_busy: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.12).timeout
	await _probe(player, "章末及接续来客说明全部结束")
	await _close_scene()
