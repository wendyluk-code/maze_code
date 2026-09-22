extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const SAVE_PATH := "user://save.json"

var checks: Array = []
var failures := 0
var scene: Node2D = null
var guide: Control = null
var tm = null
var sm = null

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	if not _verify_isolation():
		_write_report()
		get_tree().quit(2)
		return
	tm = get_tree().root.get_node("TutorialManager")
	sm = get_tree().root.get_node("SaveManager")

	# 旧存档只含兼容教程字段时，不能凭空形成首单。
	sm.data = {"tutorial_done": true, "chapter_1_done": false}
	sm.save()
	sm.load_data()
	_check(not sm.has_active_order() and not sm.is_chapter_1_done(),
		"legacy_save_does_not_fake_order", {"order": sm.current_order()})

	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	await _start_scene()
	await _reach_stage_three_interact()

	var register := scene.get_node("InteractPoints/Register") as Node2D
	var store := scene.get_node("InteractPoints/Store") as Node2D
	var player := scene.get_node("Player")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var before_idx: int = int(tm.idx)
	var before_order: Dictionary = sm.current_order()

	# 错误目标：教程和订单均不变。
	player.interacted.emit(store)
	await get_tree().process_frame
	_check(tm.idx == before_idx and sm.current_order() == before_order,
		"wrong_target_keeps_tutorial_and_order", {"idx": tm.idx, "order": sm.current_order()})

	# 超出范围的直接输入：TutorialManager 的二次距离/选择器校验拒绝它。
	player.global_position = Vector2(-10000, -10000)
	player.interacted.emit(register)
	await get_tree().process_frame
	_check(tm.idx == before_idx and sm.current_order() == before_order,
		"out_of_range_keeps_tutorial_and_order", {"idx": tm.idx, "order": sm.current_order()})

	# 真实前台输入：先写订单，再推进教程，再显示回执与持续追踪。
	player.global_position = register.global_position
	player.interacted.emit(register)
	await get_tree().process_frame
	var order: Dictionary = sm.current_order()
	_check(tm.idx == before_idx + 1, "successful_transaction_advances_tutorial", {"idx": tm.idx})
	_check(order.get("id", "") == "chapter_1_first_order"
		and order.get("item_id", "") == "salt_grilled_rockmane"
		and order.get("item_name", "") == "盐烤岩鬃肉"
		and int(order.get("quantity", 0)) == 1
		and order.get("status", "") == "in_progress",
		"successful_transaction_writes_unique_order", {"order": order})
	_check(tracker.visible and tracker.get("_receipt") != null and tracker.get("_status") != null,
		"tracker_scene_is_present", {"visible": tracker.visible})
	# 订单回执由 tracker 内部生成；检查其可观察文本和持续状态。
	_check(str(tracker.get("_receipt").text).contains("已接单：盐烤岩鬃肉 ×1")
		and str(tracker.get("_status").text).contains("进行中"),
		"receipt_and_tracking_are_visible", {
			"receipt": tracker.get("_receipt").text,
			"status": tracker.get("_status").text,
		})

	# 重复输入/重复事务幂等：不生成第二个订单、不改变订单字段。
	var order_after_first: Dictionary = order.duplicate(true)
	var second_result: Dictionary = sm.accept_first_order()
	player.interacted.emit(register)
	await get_tree().process_frame
	_check(bool(second_result.get("success", false))
		and not bool(second_result.get("created", true))
		and sm.current_order() == order_after_first,
		"duplicate_accept_is_idempotent", {
			"second_result": second_result,
			"order": sm.current_order(),
		})

	# 退出/重进等价恢复：重新从隔离 save.json 加载并让新 HUD 查询到同一订单。
	sm.save()
	tm._cancel_current_run()
	await _dispose_scene()
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	sm.load_data()
	var restored: Dictionary = sm.current_order()
	_check(restored.get("id", "") == order_after_first.get("id", "")
		and restored.get("item_id", "") == order_after_first.get("item_id", "")
		and restored.get("item_name", "") == order_after_first.get("item_name", "")
		and int(restored.get("quantity", 0)) == int(order_after_first.get("quantity", 0))
		and restored.get("status", "") == order_after_first.get("status", ""),
		"reload_restores_order_state", {"order": restored})
	await _start_scene()
	var restored_tracker := scene.get_node("UIOverlay/OrderTracking")
	await get_tree().process_frame
	_check(restored_tracker.visible
		and str(restored_tracker.get("_status").text).contains("进行中"),
		"reentry_hud_queries_restored_order", {"visible": restored_tracker.visible})

	var report := {
		"ticket": "CH1-05",
		"checks": checks,
		"failures": failures,
		"isolation_root": _argument("--isolation-root="),
		"isolation_appdata": _argument("--isolation-appdata="),
		"user_data_dir": ProjectSettings.globalize_path("user://"),
		"isolated_save": _save_metadata(),
	}
	_write_report(report)
	print("CH1_05 frontdesk report=", JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _reach_stage_three_interact() -> void:
	tm.start()
	await get_tree().process_frame
	for i in 5:
		_check(tm.idx == i and guide.dialog.visible, "opening_dialog_%d_ready" % (i + 1), {"idx": tm.idx})
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 6000
	while tm.active and tm.idx == 5 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(tm.idx == 6 and guide.dialog.visible, "guest_dialog_ready", {"idx": tm.idx})
	guide.dialog._advance()
	guide.dialog._advance()
	await get_tree().process_frame
	_check(tm.idx == 7 and guide.dialog.visible, "stage_two_guide_dialog_ready", {"idx": tm.idx})
	var guide_dialog_deadline := Time.get_ticks_msec() + 2000
	while tm.active and tm.idx == 7 and Time.get_ticks_msec() < guide_dialog_deadline:
		guide.dialog._advance()
		await get_tree().process_frame
	var move_deadline := Time.get_ticks_msec() + 4000
	while tm.active and tm.idx != 8 and Time.get_ticks_msec() < move_deadline:
		await get_tree().process_frame
	_check(tm.idx == 8, "stage_three_move_step_ready", {"idx": tm.idx})
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register") as Node2D
	player.global_position = register.global_position
	while tm.active and tm.idx == 8 and Time.get_ticks_msec() < move_deadline:
		await get_tree().process_frame
	_check(tm.idx == 9 and sm.current_order().get("status", "none") == "none",
		"stage_three_interact_starts_without_order", {"idx": tm.idx, "order": sm.current_order()})

func _start_scene() -> void:
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	guide = scene.get_node("UIOverlay/TutorialGuide")
	scene.get_node("Player").spawn_ready = true

func _dispose_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	await get_tree().process_frame
	scene = null
	guide = null

func _verify_isolation() -> bool:
	var root := _normalize_path(_argument("--isolation-root="))
	var appdata := _normalize_path(_argument("--isolation-appdata="))
	var actual_user := _normalize_path(ProjectSettings.globalize_path("user://"))
	var actual_appdata := _normalize_path(OS.get_environment("APPDATA"))
	var ok := OS.get_environment("MAZE_CH1_05_ISOLATED") == "1" \
		and not root.is_empty() and actual_user.begins_with(root + "/") \
		and not appdata.is_empty() and actual_appdata == appdata \
		and actual_appdata.begins_with(root + "/")
	_check(ok, "isolated_user_data_directory", {
		"declared_root": root,
		"declared_appdata": appdata,
		"actual_user_dir": actual_user,
		"actual_appdata": actual_appdata,
	})
	return ok

func _save_metadata() -> Dictionary:
	var path := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(SAVE_PATH):
		return {"exists": false, "length": 0, "sha256": ""}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var length := file.get_length() if file else 0
	return {"exists": true, "length": length, "sha256": FileAccess.get_sha256(path)}

func _normalize_path(value: String) -> String:
	return value.replace("\\", "/").trim_suffix("/").to_lower()

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func _check(condition: bool, name: String, details: Dictionary = {}) -> void:
	checks.append({"name": name, "passed": condition, "details": details})
	if not condition:
		failures += 1

func _write_report(report: Dictionary = {}) -> void:
	var path := _argument("--report=")
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		if report.is_empty():
			report = {"ticket": "CH1-05", "checks": checks, "failures": failures}
		file.store_string(JSON.stringify(report, "\t"))
