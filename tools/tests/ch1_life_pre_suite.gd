extends "res://tools/tests/ch1_09_wrapup_suite.gd"
## 生命周期验收复用既有真实场景辅助器；不直接设置教程步骤，不伪造事务成功。

const STAGES := ["not_started", "awakened", "guest_arrived", "order_accepted",
	"ingredients_collected", "dish_ready", "order_served", "ready_to_depart"]
var seen: Array = []
var protected_memory := ""
var protected_disk := ""
var watch_replay := false
var replay_clean := true

func _run() -> void:
	var isolation := _arg("--isolation-root=").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if OS.get_environment("MAZE_CH1_LIFE_PRE_ISOLATED") != "1" or isolation.is_empty() or not actual.begins_with(isolation + "/"):
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	mode = _arg("--mode=")
	if mode == "seed":
		sm.data = sm._defaults()
		_check(sm.save(), "建立隔离默认存档")
		await _start_scene()
		await _drive(true)
		_check(seen == STAGES, "真实阶段序列覆盖全部八阶段", {"seen": seen})
		_assert_ready()
	elif mode.begins_with("restore-"):
		await _restore_case(mode.trim_prefix("restore-"))
	elif mode == "corrupt":
		await _corrupt_cases()
	elif mode == "replay":
		await _replay_cases()
	elif mode == "intro-save-failure":
		await _intro_failure()
	else:
		_check(false, "未知模式")
	var report := {"ticket": "CH1-LIFE-PRE", "mode": mode, "checks": checks, "failures": failures,
		"seen": seen, "state": sm.data, "user_dir": actual}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CH1_LIFE_PRE ", mode, " checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _process(_delta: float) -> void:
	if watch_replay and (JSON.stringify(sm.data).sha256_text() != protected_memory or _disk().sha256_text() != protected_disk):
		replay_clean = false

func _drive(record := false, stop_at := "") -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var stage: String = sm.lifecycle_stage()
		if not seen.has(stage):
			seen.append(stage)
			if record:
				var snapshot := FileAccess.open("user://life-" + stage + ".json", FileAccess.WRITE)
				snapshot.store_string(_disk())
				snapshot.close()
		if stage == stop_at or not tm.active:
			return
		var step: Dictionary = tm.steps[tm.idx]
		var modal := scene.get_node("UIOverlay/WarehouseModal")
		var panel := scene.get_node("UIOverlay/DeparturePanel")
		if modal._open:
			if modal._empty_stock:
				modal._on_cancel_pressed()
			else:
				modal._on_slot_selected("rockmane_meat")
				modal._on_slot_selected("rock_salt")
				modal._on_claim_pressed()
		elif panel._open:
			panel.close_map()
		elif guide.dialog.visible:
			guide.dialog._advance()
		elif step.type in ["move_to", "interact"] and not tm._camera_cutscene_active and not tm._camera_parked:
			var target: Node2D = tm.resolve_target(step.target)
			player.global_position = _stand(target)
			if step.type == "interact":
				_press_e()
		await get_tree().process_frame
	_check(false, "真实流程超时", {"idx": tm.idx, "stage": sm.lifecycle_stage()})

func _load_snapshot(stage: String) -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("user://life-" + stage + ".json"))
	file.close()
	sm.load_data()

func _restore_case(stage: String) -> void:
	_load_snapshot(stage)
	_check(sm.lifecycle_stage() == stage, "独立进程读取阶段 " + stage)
	var memory: String = JSON.stringify(sm.data).sha256_text()
	var disk: String = _disk().sha256_text()
	await _start_scene()
	var expected: int = {"not_started": 1, "awakened": 2, "guest_arrived": 2, "order_accepted": 4,
		"ingredients_collected": 5, "dish_ready": 6, "order_served": 7, "ready_to_depart": 0}[stage]
	_check(tm.current_stage == expected and tm.active == (expected != 0), "入口恢复正确步骤 " + stage,
		{"stage": tm.current_stage, "idx": tm.idx})
	_check(JSON.stringify(sm.data).sha256_text() == memory and _disk().sha256_text() == disk, "恢复本身零副作用 " + stage)
	if stage == "guest_arrived":
		_check(tm.idx == 6, "客人已登场不重播入场镜头")
	if stage == "order_accepted":
		await _walk_to("Store", 11)
		_press_e()
		_check(scene.get_node("UIOverlay/WarehouseModal")._open, "待取料真实弹窗打开")
	await _capture("restored-" + stage)
	tm.skip_all()
	await get_tree().process_frame
	_assert_clean(stage)
	_check(JSON.stringify(sm.data).sha256_text() == memory and _disk().sha256_text() == disk, "skip 内存磁盘指纹不变 " + stage)
	if stage == "awakened":
		await get_tree().create_timer(2.0).timeout
		_assert_clean("旧过场等待结束")
		_check(JSON.stringify(sm.data).sha256_text() == memory and _disk().sha256_text() == disk, "旧异步链不能落盘或创建客人")
	await _capture("skipped-" + stage)
	await _reenter()
	_check(tm.current_stage == expected and tm.active == (expected != 0), "skip 后退出重进仍恢复 " + stage)
	tm.skip_all()

func _assert_clean(label: String) -> void:
	_check(not tm.active and not player.input_locked and player.is_physics_processing() and not scene.get_node("Camera").paused
		and not guide.visible and not guide.dim.visible and not guide._modal_suppressed
		and not scene.get_node("UIOverlay/WarehouseModal")._open and not scene.get_node("UIOverlay/DeparturePanel")._open
		and tm.steps.is_empty() and tm.guide == null and tm.player == null
		and get_tree().get_nodes_in_group("guest").is_empty(), "运行时清理完整 " + label,
		{"active": tm.active, "locked": player.input_locked, "physics": player.is_physics_processing(),
		"camera_paused": scene.get_node("Camera").paused, "guide_visible": guide.visible, "dim_visible": guide.dim.visible,
		"suppressed": guide._modal_suppressed, "steps": tm.steps.size(), "guests": get_tree().get_nodes_in_group("guest").size()})

func _corrupt_cases() -> void:
	_load_snapshot("ready_to_depart")
	var ready: Dictionary = sm.data.duplicate(true)
	var corruptions: Array = []
	for key in ready.chapter_1_departure:
		var candidate: Dictionary = ready.duplicate(true)
		candidate.chapter_1_departure.erase(key)
		corruptions.append(["缺少 " + key, candidate])
	for key in ["map", "party", "objective", "cards", "step", "entrance_lit", "empty_warehouse_checked", "tieshan_name_revealed"]:
		for value in [null, 42, true, [], {}]:
			var candidate: Dictionary = ready.duplicate(true)
			candidate.chapter_1_departure[key] = value
			if JSON.stringify(candidate) != JSON.stringify(ready):
				corruptions.append([key + " 类型/内容 " + str(value), candidate])
	for key in ["unlocked_floors", "visible_regions", "other_regions"]:
		for value in [null, {}, ["invalid"], "invalid", []]:
			var candidate: Dictionary = ready.duplicate(true)
			candidate.chapter_1_departure.map[key] = value
			corruptions.append(["map." + key, candidate])
	for key in ["status", "unlocked", "card_ids"]:
		var candidate: Dictionary = ready.duplicate(true)
		candidate.chapter_1_departure.cards[key] = "invalid"
		corruptions.append(["cards." + key, candidate])
	for value in [null, [], "ready_to_depart", 5]:
		var candidate: Dictionary = ready.duplicate(true)
		candidate.chapter_1_departure = value
		corruptions.append(["departure 非字典", candidate])
	var forged: Dictionary = sm._defaults()
	forged.chapter_1_departure.step = "ready_to_depart"
	corruptions.append(["仅伪造 ready 字符串", forged])
	for field in ["first_order_settlement", "current_order"]:
		var candidate: Dictionary = ready.duplicate(true)
		candidate[field] = {}
		corruptions.append(["缺少真实事务 " + field, candidate])
	var extra: Dictionary = ready.duplicate(true)
	extra.inventory.rock_salt = 1
	corruptions.append(["准备态库存未清空", extra])
	for field in ["reputation", "first_order_progress", "inventory"]:
		var candidate: Dictionary = ready.duplicate(true)
		candidate[field] = {} if field != "reputation" else 0
		corruptions.append(["准备态事务结构矛盾 " + field, candidate])
	for item in corruptions:
		var file := FileAccess.open("user://save.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(item[1]))
		file.close()
		var disk: String = _disk()
		sm.load_data()
		_check(not sm.is_ready_to_depart() and not sm.migration_diagnostics.is_empty()
			and sm.departure_state().step == "relief" and _disk() == disk, "损坏有诊断并安全回退：" + str(item[0]))
		_check(not sm.is_chapter_1_done() and not sm.is_tutorial_done(), "损坏不能变成最终完成")
		for field in ["current_order", "inventory", "first_order_settlement", "reputation"]:
			_check(sm.data[field] == item[1][field] or field == "current_order" or (field == "inventory" and item[1][field].is_empty()), "准备态回退保留有效经营 " + field)
	for raw in ["{ broken", "[]", "null", "42", '{"tutorial_done":true}', '{"chapter_1_done":"true","tutorial_done":1}']:
		var file := FileAccess.open("user://save.json", FileAccess.WRITE)
		file.store_string(raw)
		file.close()
		sm.load_data()
		_check(not sm.migration_diagnostics.is_empty() and not sm.is_ready_to_depart() and not sm.is_chapter_1_done()
			and sm.reputation() == 0 and _disk() == raw, "旧档或损坏顶层诊断且不补奖励：" + raw)
	# 损坏嵌套数据经过真实入口不会使界面属性访问崩溃，也不会隐藏教程。
	sm.data = ready.duplicate(true)
	sm.data.chapter_1_departure.map = []
	sm.save()
	sm.load_data()
	await _start_scene()
	_check(tm.active and tm.current_stage == 7 and guide.visible, "损坏准备态真实入口回到收束第一句")
	tm.skip_all()

func _replay_cases() -> void:
	_load_snapshot("ready_to_depart")
	protected_memory = JSON.stringify(sm.data).sha256_text()
	protected_disk = _disk().sha256_text()
	tm._replay_requested = true
	watch_replay = true
	await _start_scene()
	_check(tm.active and tm.idx == 0, "准备态允许显式重播")
	_check(not sm.cook_first_order().success and not sm.deliver_first_order().success
		and not sm.advance_departure("agreement").success, "重播仍拒绝乱序事务")
	await _drive(false, "order_accepted")
	await _walk_to("Store", 11)
	_press_e()
	_check(scene.get_node("UIOverlay/WarehouseModal")._open, "重播使用真实仓库界面")
	tm.skip_all()
	await get_tree().process_frame
	_assert_clean("重播仓库取消")
	_check(replay_clean and not sm._replaying, "重播中途 skip 全程指纹不变且释放副本")
	await _reenter()
	seen.clear()
	await _drive()
	_check(not tm.active and seen.has("order_accepted") and seen.has("ingredients_collected")
		and seen.has("dish_ready") and seen.has("order_served"), "重播真实事务走完整经营及收束序列", {"seen": seen})
	_check(replay_clean and JSON.stringify(sm.data).sha256_text() == protected_memory and _disk().sha256_text() == protected_disk,
		"逐帧监测：完整重播内存及磁盘 SHA256 零副作用", {"memory": protected_memory, "disk": protected_disk})
	_check(not sm._replaying and sm.is_ready_to_depart() and not sm.is_chapter_1_done() and not sm.is_tutorial_done(), "重播完成恢复原准备态且未伪造最终完成")
	watch_replay = false
	_load_snapshot("ingredients_collected")
	protected_memory = JSON.stringify(sm.data).sha256_text()
	protected_disk = _disk().sha256_text()
	watch_replay = true
	await _reenter()
	seen.clear()
	await _drive()
	_check(replay_clean and JSON.stringify(sm.data).sha256_text() == protected_memory and _disk().sha256_text() == protected_disk
		and sm.lifecycle_stage() == "ingredients_collected", "完整重播保留原进行中订单及材料")
	_check(tracker.get("_meat_status").text == "1/1" and tracker.get("_cook_status").text == "0/1", "重播结束订单卡恢复原经营视图")
	watch_replay = false
	tm._replay_requested = false
	await _capture("replay-complete")

func _intro_failure() -> void:
	_load_snapshot("not_started")
	await _start_scene()
	var temporary := ProjectSettings.globalize_path("user://save.json.tmp")
	_check(DirAccess.make_dir_absolute(temporary) == OK, "建立开场检查点保存失败夹具")
	var memory: String = JSON.stringify(sm.data)
	var disk: String = _disk()
	for i in 5:
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	_check(tm.idx == 4 and sm.lifecycle_stage() == "not_started" and JSON.stringify(sm.data) == memory and _disk() == disk,
		"苏醒检查点写盘失败保持原状态且停留可重试对白")
	_check(DirAccess.remove_absolute(temporary) == OK, "移除苏醒检查点失败夹具")
	guide.dialog._advance()
	guide.dialog._advance()
	_check(sm.lifecycle_stage() == "awakened" and tm.idx == 5, "重试对白成功后才进入客人过场")
	tm.skip_all()
	await get_tree().process_frame
	await _reenter()
	_check(DirAccess.make_dir_absolute(temporary) == OK, "建立客人检查点保存失败夹具")
	memory = JSON.stringify(sm.data)
	disk = _disk()
	await get_tree().create_timer(2.2).timeout
	_check(tm.idx == 5 and sm.lifecycle_stage() == "awakened" and JSON.stringify(sm.data) == memory and _disk() == disk
		and get_tree().get_nodes_in_group("guest").size() <= 1, "客人检查点写盘失败不会重复客人或进入后续对白")
	_check(DirAccess.remove_absolute(temporary) == OK, "移除客人检查点失败夹具")
	var deadline := Time.get_ticks_msec() + 5000
	while tm.idx == 5 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(tm.idx == 6 and sm.lifecycle_stage() == "guest_arrived" and get_tree().get_nodes_in_group("guest").size() == 1,
		"保存恢复后唯一客人进入对白")
	tm.skip_all()
	await get_tree().process_frame
	_assert_clean("开场保存失败后取消")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := _arg("--output-dir=").path_join("CH1-LIFE-PRE-" + label + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "保存真实场景证据 " + label, {"path": path})
