extends "res://tools/tests/ch1_qte_01_input.gd"
## 复用等价键鼠输入与自然指针；夹具仅负责进入明确事务状态。
var labels: Array = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	labels.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		push_error("QTE02 FAIL: " + label)

func _run() -> void:
	var isolated := OS.get_environment("MAZE_QTE02_PROFILE").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(isolated + "/"):
		push_error("必须由隔离 runner 启动；拒绝触碰默认存档")
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	var mode := _arg("--mode=")
	if mode == "resume":
		await _mount_saved()
		await _deliver(int(_arg("--quality=")))
	elif mode == "lifecycle":
		await _lifecycle()
	elif mode == "failure":
		await _save_failure()
	var report := {"ticket": "CH1-QTE-02", "mode": mode, "checks": checks, "failures": failures, "results": labels}
	FileAccess.open(_arg("--report="), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _mount_saved() -> void:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame

func _deliver(quality: int) -> void:
	var p := scene.get_node("Player")
	p.global_position = _stand(scene.get_node("InteractPoints/Register"))
	_check(await _wait_until(func(): return tm.idx == 15, 180), "重进到真实交单步骤")
	await _send_key(KEY_E)
	_check(sm.has_first_order_settlement() and sm.reputation() == {1: 10, 2: 12, 3: 15}[quality], "真实 E 交单品质奖励")
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 0, "成品扣除一次")
	var before: Dictionary = sm.data.duplicate(true)
	await _send_key(KEY_E)
	_check(sm.data.inventory == before.inventory and sm.data.first_order_settlement == before.first_order_settlement and sm.data.reputation == before.reputation and not sm.deliver_first_order().success, "重复 E/API 不重复结算（允许后续对白推进）")
	await _capture("qte02_" + _arg("--label=") + "_delivered")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _open() -> Node:
	var p := scene.get_node("Player")
	p.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	_check(await _wait_until(func(): return tm.idx == 13, 180), "进入真实料理交互步骤")
	await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible, "真实 E 打开料理弹窗")
	return modal

func _lifecycle() -> void:
	for phase in ["before", "active", "result"]:
		for action in ["skip", "scene"]:
			await _prepare_scene()
			var modal = await _open()
			if phase != "before":
				await _click(modal.get("_start_button"))
			if phase == "result":
				await _click(modal.get("_finish_button"))
			var old_token: int = tm._run_token
			var p := scene.get_node("Player")
			var guide := scene.get_node("UIOverlay/TutorialGuide")
			if action == "skip":
				tm.skip_all()
				_check(not p.input_locked and p.is_physics_processing() and not modal.visible, phase + "跳过释放输入/弹窗")
				_check(not guide.visible and not guide.dim.visible and not guide._modal_suppressed, phase + "跳过释放提示/遮罩")
				_check(not scene.get_node("Camera").paused, phase + "跳过恢复镜头")
			else:
				# 真正移出树，保留节点到清理断言完成。
				get_tree().root.remove_child(scene)
				_check(not tm.active and tm._run_token > old_token, phase + "场景退出立即取消旧流程")
				_check(not p.input_locked and p.is_physics_processing(), phase + "场景退出释放旧玩家锁")
				_check(not scene.get_node("Camera").paused and not guide.dim.visible, phase + "场景退出恢复镜头遮罩")
			_check(sm.inventory_quantity(sm.ROCKMAN_MEAT_ID) == (1 if phase == "before" else 0), phase + "中断不重复扣材料")
			if action == "skip":
				scene.queue_free()
			else:
				scene.free()
			await get_tree().process_frame
			await _mount_saved()
			var new_idx: int = tm.idx
			await get_tree().create_timer(1.2).timeout
			_check(tm.idx == new_idx, phase + action + "旧 await 不推进新教程")
			if phase != "before":
				_check(sm.cooking_state().status == "locked" and sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, phase + action + "同进程恢复一个成品")
				await _deliver(1)
			else:
				tm._cancel_current_run()
				scene.queue_free()
				await get_tree().process_frame
	# 正式 data/磁盘与重播工作副本分离，场景退出也结束重播。
	for action in ["skip", "scene"]:
		await _prepare_scene()
		var before: Dictionary = sm.data.duplicate(true)
		var disk := FileAccess.get_file_as_string(sm.SAVE_PATH)
		sm.begin_replay()
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		var modal = await _open()
		await _click(modal.get("_start_button"))
		await _click(modal.get("_finish_button"))
		if action == "skip":
			tm.skip_all()
		else:
			get_tree().root.remove_child(scene)
		_check(not sm._replaying and sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk, action + "退出重播不污染正式存档")
		if action == "skip":
			scene.queue_free()
		else:
			scene.free()
		await get_tree().process_frame
		await _mount_saved()
		var new_idx: int = tm.idx
		await get_tree().create_timer(1.2).timeout
		_check(tm.idx == new_idx and sm.data == before, "重播旧 await 不污染新流程")
		tm._cancel_current_run()
		scene.queue_free()
		await get_tree().process_frame

func _save_failure() -> void:
	await _prepare_scene()
	var modal = await _open()
	var before: Dictionary = sm.data.duplicate(true)
	var disk := FileAccess.get_file_as_string(sm.SAVE_PATH)
	DirAccess.make_dir_absolute(sm.SAVE_PATH + ".tmp")
	await _click(modal.get("_start_button"))
	_check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk and not modal._started, "开始保存失败内存磁盘一致")
	DirAccess.remove_absolute(sm.SAVE_PATH + ".tmp")
	await _click(modal.get("_start_button"))
	_check(sm.cooking_state().status == "active" and sm.inventory_quantity(sm.ROCKMAN_MEAT_ID) == 0, "开始重试只扣一次")
	before = sm.data.duplicate(true)
	disk = FileAccess.get_file_as_string(sm.SAVE_PATH)
	DirAccess.make_dir_absolute(sm.SAVE_PATH + ".tmp")
	# 用自然时间命中3星，保存失败后的等待覆盖其它星级区间。
	await _wait_until(func(): return absf(modal._gauge.pointer_position) < 0.04, 180)
	await _click(modal.get("_finish_button"))
	var pointer: float = modal._locked_pointer
	var stars: int = modal._locked_stars
	_check(stars == 3, "自然指针与真实鼠标锁定3星")
	_check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk, "起锅保存失败内存磁盘一致")
	await get_tree().create_timer(1.2).timeout
	_check(modal._locked_pointer == pointer and modal._locked_stars == stars and modal._gauge.pointer_position == pointer, "起锅失败自然时间不改变已锁品质/指针")
	await _capture("qte02_failure_frozen")
	DirAccess.remove_absolute(sm.SAVE_PATH + ".tmp")
	await _click(modal.get("_finish_button"))
	_check(sm.cooked_quality() == stars and is_equal_approx(sm.cooking_state().pointer, pointer) and sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, "起锅重试仅提交原品质一次")
	await _wait_until(func(): return tm.idx == 14, 180)
	scene.get_node("Player").global_position = _stand(scene.get_node("InteractPoints/Register"))
	await _wait_until(func(): return tm.idx == 15, 180)
	before = sm.data.duplicate(true)
	disk = FileAccess.get_file_as_string(sm.SAVE_PATH)
	DirAccess.make_dir_absolute(sm.SAVE_PATH + ".tmp")
	await _send_key(KEY_E)
	_check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk and tm.idx == 15, "真实 E 交单保存失败不扣成品不发奖不推进")
	DirAccess.remove_absolute(sm.SAVE_PATH + ".tmp")
	await _deliver(stars)
	# 退出场景的最低品质恢复也可能写盘失败：重进弹窗仅能重试1星。
	await _prepare_scene()
	modal = await _open()
	await _click(modal.get("_start_button"))
	before = sm.data.duplicate(true)
	disk = FileAccess.get_file_as_string(sm.SAVE_PATH)
	DirAccess.make_dir_absolute(sm.SAVE_PATH + ".tmp")
	tm.skip_all()
	_check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk, "中断恢复保存失败保留已扣料active内存磁盘")
	scene.queue_free()
	await get_tree().process_frame
	await _mount_saved()
	modal = await _open()
	_check(modal._locked_stars == 1 and modal._started and modal._start_button.disabled, "恢复失败后只能重试固定1星不能再次开始")
	await get_tree().create_timer(1.2).timeout
	_check(modal._locked_stars == 1 and modal._gauge.pointer_position == 0.0, "中断恢复重试指针保持固定")
	DirAccess.remove_absolute(sm.SAVE_PATH + ".tmp")
	await _click(modal.get("_finish_button"))
	_check(sm.cooked_quality() == 1 and sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, "中断恢复重试只产生一份1星成品")
	await _wait_until(func(): return tm.idx == 14, 180)
	await _deliver(1)
