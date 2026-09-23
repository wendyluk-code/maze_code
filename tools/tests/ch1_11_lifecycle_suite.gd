extends Node
## CH1-11 第一章最终生命周期契约验收。
## 直接调用生产 SaveManager 原子接口，覆盖完成、重进、重复、保存失败和重播隔离。

var checks: Array[Dictionary] = []
var failures := 0
var sm: Node

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	sm = get_node("/root/SaveManager")
	var tm = get_node("/root/TutorialManager")
	var ready := _ready_snapshot()
	sm.data = ready.duplicate(true)
	_check(sm.is_ready_to_depart() and sm.lifecycle_stage() == "ready_to_depart", "合法 ready_to_depart 前置态")
	var before: Dictionary = sm.data.duplicate(true)
	var first: Dictionary = tm.confirm_chapter_1()
	_check(first.success and first.created and first.reason == "completed", "最终确认原子提交成功")
	_check(sm.is_chapter_1_done() and sm.is_tutorial_done() and sm.lifecycle_stage() == "done", "done 阶段与两个完成标记一致")
	_check(_preserved_departure(sm.departure_state(), before.chapter_1_departure), "完成不改地图、队伍、入口和卡组")
	var disk_after := _disk()
	var memory_after: Dictionary = sm.data.duplicate(true)
	var second: Dictionary = sm.complete_chapter_1()
	_check(second.success and not second.created and second.reason == "already_done", "重复完成幂等且不重复写盘")
	_check(sm.data == memory_after and _disk() == disk_after, "重复完成不改变内存或正式存档")

	# 退出重进：重新解析同一份正式存档，完成态和准备快照保持一致。
	sm.load_data()
	_check(sm.is_chapter_1_complete() and sm.lifecycle_stage() == "done", "重进恢复 done")
	_check(_preserved_departure(sm.departure_state(), before.chapter_1_departure), "重进恢复出发快照")

	# 保存失败时必须回滚两个标记，不把临时文件错误当成完成。
	sm.data = _ready_snapshot()
	var failed_before: Dictionary = sm.data.duplicate(true)
	var tmp_path := ProjectSettings.globalize_path("user://save.json.tmp")
	_check(DirAccess.make_dir_absolute(tmp_path) == OK, "建立保存失败夹具")
	var failed: Dictionary = sm.complete_chapter_1()
	_check(not failed.success and failed.reason == "save_failed", "保存失败返回可诊断原因")
	_check(sm.data == failed_before and not sm.is_chapter_1_done() and not sm.is_tutorial_done(), "保存失败完整回滚")
	_check(DirAccess.remove_absolute(tmp_path) == OK, "移除保存失败夹具")

	# 开发重播使用独立工作副本；完成重播不得污染正式完成标记或磁盘。
	sm.data = _ready_snapshot()
	_check(sm.save(), "建立重播基线")
	var replay_memory: Dictionary = sm.data.duplicate(true)
	var replay_disk := _disk()
	sm.begin_replay()
	# begin_replay() 由正式教程从默认状态重放；此处直接注入已验证准备态，
	# 将验收焦点限定在最终提交是否路由到副本。
	sm._replay_data = _ready_snapshot()
	var replay_result: Dictionary = sm.complete_chapter_1()
	_check(replay_result.success and replay_result.created and sm.is_chapter_1_done(), "重播副本可完成")
	_check(sm.data == replay_memory and _disk() == replay_disk, "重播完成不污染正式存档")
	sm.end_replay()
	_check(not sm.is_chapter_1_done() and not sm.is_tutorial_done() and sm.lifecycle_stage() == "ready_to_depart", "退出重播恢复原准备态")

	var report := {"ticket": "CH1-11", "checks": checks, "failures": failures,
		"stage": sm.lifecycle_stage(), "state": sm.data}
	var report_path := OS.get_environment("CH1_11_REPORT")
	if report_path.is_empty():
		report_path = "user://ch1_11_lifecycle_contract.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("CH1_11_LIFECYCLE %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)

func _ready_snapshot() -> Dictionary:
	var seeded: Dictionary = sm._defaults()
	seeded.chapter_1_departure.step = "ready_to_depart"
	seeded.chapter_1_departure.empty_warehouse_checked = true
	seeded.chapter_1_departure.tieshan_name_revealed = true
	seeded.chapter_1_departure.map = {"unlocked_floors": [1], "visible_regions": ["old_salt_pool"], "other_regions": "fog"}
	seeded.chapter_1_departure.party = ["yaya", "tieshan"]
	seeded.chapter_1_departure.objective = "与芽芽、铁山一同进入迷宫浅层"
	seeded.chapter_1_departure.entrance_lit = true
	seeded.chapter_1_departure.cards = sm._unlocked_cards()
	seeded.first_order_progress = {"ingredients_claimed": true, "next_step": "chapter_wrap_up"}
	seeded.current_order = {"id": "chapter_1_first_order", "item_id": "salt_grilled_rockmane", "item_name": "盐烤岩鬃肉", "quantity": 1, "status": "completed"}
	seeded.first_order_settlement = {"order_id": "chapter_1_first_order", "item_id": "salt_grilled_rockmane", "quantity": 1, "reputation_awarded": 20}
	seeded.reputation = 20
	seeded.inventory = {"rockmane_meat": 0, "rock_salt": 0, "salt_grilled_rockmane": 0}
	return seeded

func _preserved_departure(actual: Dictionary, expected: Dictionary) -> bool:
	return actual.get("step") == expected.get("step") \
		and actual.get("empty_warehouse_checked") == expected.get("empty_warehouse_checked") \
		and actual.get("tieshan_name_revealed") == expected.get("tieshan_name_revealed") \
		and actual.get("map", {}).get("unlocked_floors", []) == [1] \
		and actual.get("map", {}).get("visible_regions", []) == ["old_salt_pool"] \
		and actual.get("map", {}).get("other_regions", "") == "fog" \
		and actual.get("party") == ["yaya", "tieshan"] \
		and actual.get("objective") == "与芽芽、铁山一同进入迷宫浅层" \
		and actual.get("entrance_lit") == true \
		and actual.get("cards", {}).get("card_ids", []).size() == 16

func _disk() -> String:
	var path := ProjectSettings.globalize_path("user://save.json")
	if not FileAccess.file_exists(path):
		return "absent"
	return FileAccess.get_file_as_string(path).sha256_text()

func _check(condition: bool, name: String) -> void:
	checks.append({"name": name, "ok": condition})
	if not condition:
		failures += 1
