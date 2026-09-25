extends SceneTree
## 每次运行均为独立 Godot 进程；测试只能在 runner 的隔离 APPDATA 中执行。
var sm
var checks := 0
var failures := 0
var results: Array = []
var dish := "salt_grilled_rockmane"

func _initialize() -> void:
	call_deferred("_run")

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func check(ok: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		push_error("QTE02 STATE FAIL: " + label)

func _run() -> void:
	var isolated := OS.get_environment("MAZE_QTE02_PROFILE").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(isolated + "/"):
		push_error("必须由隔离 runner 启动；拒绝触碰默认存档")
		quit(2)
		return
	sm = root.get_node("SaveManager")
	var mode := _arg("--mode=")
	var sample := _arg("--sample=")
	match mode:
		"write":
			_write(sample)
		"read":
			_read(sample)
		"unit":
			_unit()
	var report := {"ticket": "CH1-QTE-02", "pid": OS.get_process_id(), "mode": mode, "sample": sample, "checks": checks, "failures": failures, "results": results}
	FileAccess.open(_arg("--report="), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures == 0 else 1)

func _fresh() -> void:
	sm.data = sm._defaults()
	check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "夹具接单取料")

func _write(sample: String) -> void:
	_fresh()
	if sample != "before":
		check(sm.start_first_order_cooking().success, "写入开始档")
	if sample.begins_with("locked") or sample.begins_with("delivered"):
		var stars := int(sample.right(1))
		check(sm.finish_first_order_cooking(stars, 0.37).success, "写入锁定档")
		if sample.begins_with("delivered"):
			check(sm.deliver_first_order().success, "写入已交付档")
	if sample == "legacy":
		sm.data.inventory[dish] = 1
		sm.data.first_order_progress.next_step = "deliver"
		sm.data.erase("prepared_dishes")
		sm.data.erase("first_order_cooking")
	if sample == "settled20":
		sm.finish_first_order_cooking(1)
		sm.deliver_first_order()
		sm.data.reputation = 20
		sm.data.first_order_settlement.reputation_awarded = 20
		sm.data.first_order_settlement.erase("quality")
	sm.data["future_extension"] = {"opaque": [17, "keep"]}
	sm.data.inventory["future_material"] = 7
	check(sm.save(), "夹具完整保存")

func _read(sample: String) -> void:
	var opaque = sm.data.get("future_extension", {}).get("opaque", [])
	check(opaque is Array and opaque.size() == 2 and opaque[0] == 17 and opaque[1] == "keep", "未知顶层字段保留（JSON 数字允许浮点表示）")
	check(sm.data.inventory.get("future_material") == 7, "未知库存字段保留")
	var expected_total := 0 if sample == "before" or sample == "settled20" or sample.begins_with("delivered") else 1
	check(sm.inventory_quantity(dish) == expected_total, "跨进程成品总量正确")
	check(_total() == expected_total, "跨进程分星数量与总量一致")
	check(sm.inventory_quantity(sm.ROCKMAN_MEAT_ID) == (1 if sample == "before" else 0), "跨进程材料不重复扣除")
	if sample == "before":
		check(sm.reputation() == 0 and sm.cooking_state().status == "idle", "开始前退出未产生料理或奖励")
	elif sample == "active" or sample == "legacy" or sample.begins_with("locked"):
		var stars := int(sample.right(1)) if sample.begins_with("locked") else 1
		check(sm.cooked_quality() == stars and sm.first_order_progress().next_step == "deliver", "跨进程品质与交付进度保留")
		check(not sm.start_first_order_cooking().success, "重进不能再次起锅刷星")
		if sample.begins_with("locked"):
			check(is_equal_approx(sm.cooking_state().pointer, 0.37), "锁定指针跨进程保持")
	elif sample == "settled20" or sample.begins_with("delivered"):
		var reward: int = 20 if sample == "settled20" else {1: 10, 2: 12, 3: 15}[int(sample.right(1))]
		var before: Dictionary = sm.data.duplicate(true)
		check(sm.has_first_order_settlement() and sm.reputation() == reward, "已结算合法凭证与奖励保留")
		check(not sm.deliver_first_order().success and not sm.start_first_order_cooking().success and sm.data == before, "已交付重复 API 不扣不增")

func _total() -> int:
	var prepared: Dictionary = sm.prepared_dishes_snapshot()[dish]
	return int(prepared["1"]) + int(prepared["2"]) + int(prepared["3"])

func _reload(value: Dictionary) -> void:
	FileAccess.open(sm.SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(value))
	sm.load_data()

func _unit() -> void:
	_fresh()
	sm.data.first_order_cooking["future_token"] = "preserve"
	sm.start_first_order_cooking()
	check(sm.data.first_order_cooking.get("future_token") == "preserve", "开始事务保留烹饪未知字段")
	sm.data.first_order_cooking["future_token"] = "preserve"
	sm.save()
	sm.recover_interrupted_cooking()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sm.SAVE_PATH))
	check(sm.data.first_order_cooking.get("future_token") == "preserve" and saved.first_order_cooking.get("future_token") == "preserve", "同进程恢复在内存和磁盘保留烹饪未知字段")
	# 同名成品以真实分星库存为准，不能用已交付事务的品质影响后续库存。
	_fresh()
	sm.start_first_order_cooking()
	sm.finish_first_order_cooking(3)
	sm.deliver_first_order()
	sm.data.inventory[dish] = 1
	sm.data.prepared_dishes[dish] = {"1": 1, "2": 0, "3": 0}
	check(sm.cooked_quality() == 1, "已交付3星不会污染后续1星库存")
	# 模拟带陈旧 cooking 记录、仍待交付的兼容档。
	sm.data.first_order_settlement = {}
	sm.data.current_order.status = "in_progress"
	sm.data.first_order_progress.next_step = "deliver"
	var result: Dictionary = sm.deliver_first_order()
	check(result.success and result.reputation_awarded == 10 and _total() == 0, "缺失3星库存不会发3星奖或留下幽灵库存")
	for bad in [[], "bad", null, 12, true]:
		_fresh()
		sm.start_first_order_cooking()
		var raw: Dictionary = sm.data.duplicate(true)
		raw.first_order_progress = bad
		_reload(raw)
		check(sm.data.first_order_progress is Dictionary and not sm.migration_diagnostics.is_empty(), "损坏进度可诊断回退 " + str(bad))
		check(sm.inventory_quantity(dish) == 0, "损坏进度不补产物")
	for field in ["quality", "pointer", "status", "recipe_id"]:
		for bad in [[], {}, true, null, "invalid"]:
			var raw: Dictionary = sm._defaults()
			raw.first_order_cooking[field] = bad
			_reload(raw)
			check(sm.data.first_order_cooking is Dictionary and not sm.migration_diagnostics.is_empty(), "烹饪字段类型回退 " + field + ":" + str(bad))
	for bad in [[], {dish: []}, {dish: {"1": [], "2": -1, "3": 1.5}}]:
		var raw: Dictionary = sm._defaults()
		raw.inventory[dish] = 1
		raw.prepared_dishes = bad
		_reload(raw)
		check(_total() == 1 and not sm.migration_diagnostics.is_empty(), "损坏分星数量回退且与总量一致")
	for fault in ["order", "claimed", "recipe", "existing"]:
		_fresh()
		sm.start_first_order_cooking()
		var raw: Dictionary = sm.data.duplicate(true)
		match fault:
			"order": raw.current_order = {}
			"claimed": raw.first_order_progress.ingredients_claimed = false
			"recipe": raw.first_order_cooking.recipe_id = "other_recipe"
			"existing":
				raw.inventory[dish] = 1
				raw.prepared_dishes[dish]["1"] = 1
		_reload(raw)
		check(sm.inventory_quantity(dish) == (1 if fault == "existing" else 0) and _total() == sm.inventory_quantity(dish), "非法 active 不直接增加成品 " + fault)
		check(not sm.migration_diagnostics.is_empty(), "非法 active 有诊断 " + fault)
	# 合法历史无星20凭证例外；新凭证必须星级与整数奖励匹配。
	for pair in [[1, 10, true], [2, 12, true], [3, 15, true], [1, 10.9, false], [3, 10, false], [1, 20, false], [0, 20, false]]:
		sm.data = sm._defaults()
		sm.data.first_order_settlement = {"order_id": sm.FIRST_ORDER_ID, "item_id": dish, "quantity": 1, "quality": pair[0], "reputation_awarded": pair[1]}
		check(sm.has_first_order_settlement() == pair[2], "凭证星级奖励验证 " + str(pair))
	# 保存失败采用真实文件系统冲突；API 层三事务均必须原样回滚。
	for operation in ["start", "finish", "deliver"]:
		_fresh()
		if operation != "start": sm.start_first_order_cooking()
		if operation == "deliver": sm.finish_first_order_cooking(2, 0.12)
		var before: Dictionary = sm.data.duplicate(true)
		var disk := FileAccess.get_file_as_string(sm.SAVE_PATH)
		DirAccess.make_dir_absolute(sm.SAVE_PATH + ".tmp")
		var response: Dictionary = _transaction(operation)
		check(not response.success and response.reason == "save_failed" and sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk, "保存失败原子回滚 " + operation)
		DirAccess.remove_absolute(sm.SAVE_PATH + ".tmp")
		check(_transaction(operation).success and not _transaction(operation).success, "重试恰好一次 " + operation)
	# 重播夹具覆盖正式 active 与正式3星成品两个状态。
	for phase in ["active", "locked"]:
		_fresh()
		sm.start_first_order_cooking()
		if phase == "locked": sm.finish_first_order_cooking(3, 0.03)
		var before: Dictionary = sm.data.duplicate(true)
		var disk := FileAccess.get_file_as_string(sm.SAVE_PATH)
		sm.begin_replay()
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		sm.start_first_order_cooking()
		sm.finish_first_order_cooking(1)
		sm.deliver_first_order()
		sm.end_replay()
		check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk, "重播保持正式 " + phase + " 内存与磁盘")

func _transaction(operation: String) -> Dictionary:
	match operation:
		"start": return sm.start_first_order_cooking()
		"finish": return sm.finish_first_order_cooking(2, 0.12)
		_: return sm.deliver_first_order()
