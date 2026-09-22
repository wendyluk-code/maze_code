extends "res://tools/tests/ch1_07_cooking_suite.gd"
## CH1-08：沿用真实餐厅站位与输入助手，独立进程验证交付前后状态。

func _run() -> void:
	var isolation := _arg("--isolation-root=").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if OS.get_environment("MAZE_CH1_08_ISOLATED") != "1" or isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("拒绝运行：存档目录未隔离")
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	mode = _arg("--mode=")
	_check(sm.has_method("deliver_first_order"), "存在真实交付事务入口")
	if failures == 0:
		await _serving_run()
	var report := {"ticket": "CH1-08", "mode": mode, "checks": checks, "failures": failures,
		"state": sm.data, "idx": tm.idx}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CH1_08 ", mode, " checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _serving_run() -> void:
	if mode == "prepare":
		_migration_checks()
		sm.data = sm._defaults()
		_check(sm.save(), "初始化隔离存档")
		_reject_delivery("no_canonical_order", "未接单")
		sm.data.chapter_1_done = true
		_reject_delivery("no_canonical_order", "章节完成标记不能代替交付")
		sm.data.chapter_1_done = false
		var defaults: Dictionary = sm.data.duplicate(true)
		sm.accept_first_order()
		_reject_delivery("not_ready_to_deliver", "未领取食材")
		sm.claim_first_order_ingredients()
		_reject_delivery("not_ready_to_deliver", "未制作料理")
		sm.data = defaults
		sm.save()
		await _start_scene()
		# 从真实开场、接单、仓库界面到料理制作，复用上游端到端输入。
		await _flow()
		await _resume_cook()
		_check(sm.reputation() == 0 and not sm.has_first_order_settlement(), "制作完仍未结算")
	elif mode == "deliver":
		await _start_scene()
		_check(tm.current_stage == 6 and sm.inventory_quantity("salt_grilled_rockmane") == 1,
			"独立进程恢复交付前检查点")
		await _walk_to("Register", 15)
		await get_tree().process_frame
		var ui := scene.get_node("UIOverlay")
		var register := scene.get_node("InteractPoints/Register") as Node2D
		var button: Control = ui.get("_buttons")[register]
		_check(button.visible and button.get_node("Content/ActionLabel").text == "交单上菜", "阶段6前台显示交单上菜按钮")
		await _capture("before")
		var before: Dictionary = sm.data.duplicate(true)
		var disk := _disk()
		player.interacted.emit(scene.get_node("InteractPoints/Store"))
		_check(sm.data == before and _disk() == disk and tm.idx == 15, "错目标不交付、不推进")
		var stand: Vector2 = player.global_position
		player.global_position = Vector2(-10000, -10000)
		_press_e()
		player.interacted.emit(register)
		_check(sm.data == before and _disk() == disk and tm.idx == 15, "超距输入及直接信号均无副作用")
		player.global_position = stand
		sm.data[sm.INVENTORY_KEY][sm.FIRST_ORDER_ITEM_ID] = 0
		var missing: Dictionary = sm.data.duplicate(true)
		_reject_delivery("missing_dish", "缺少成品")
		_press_e()
		_check(tm.idx == 15 and sm.data == missing and _disk() == disk, "缺菜 E 不推进且内存、磁盘不变")
		sm.data = before.duplicate(true)
		sm.data[sm.CURRENT_ORDER_KEY].item_id = "other"
		_reject_delivery("no_canonical_order", "菜品不匹配")
		sm.data = before.duplicate(true)
		var temporary := ProjectSettings.globalize_path("user://save.json.tmp")
		_check(DirAccess.make_dir_absolute(temporary) == OK, "建立写入失败夹具")
		_reject_delivery("save_failed", "交付写盘失败")
		_press_e()
		_check(sm.data == before and _disk() == disk and tm.idx == 15, "保存失败 E 不消耗、不结算、不推进")
		_check(DirAccess.remove_absolute(temporary) == OK, "移除写入失败夹具")
		# 相邻设施可能比前台更近；暂时移出选择器，单独验证距离上限。
		# 完成后恢复全部设施，成功交单仍在原场景真实站位执行。
		var other_targets: Array[Node] = []
		for target in get_tree().get_nodes_in_group("interactable"):
			if target != register:
				other_targets.append(target)
				target.remove_from_group("interactable")
		var boundary := _serving_stand(register)
		player.global_position = boundary
		player.last_valid = boundary
		await get_tree().process_frame
		_check(player.interaction_distance_to(register) > 95.0 and player.interaction_distance_to(register) <= 120.0
			and player.nearest_interactable() == register and button.visible, "95至120px按钮与E选择器一致")
		for target in other_targets:
			target.add_to_group("interactable")
		player.global_position = stand
		player.last_valid = stand
		_press_e()
		_check(tm.current_stage == 7 and tm.idx == 16, "真实 E 提交成功后推进阶段7")
		_check(guide.toast.text == "顾客吃得很满足！ 餐厅声望 +20", "成功反馈文案")
		_check(sm.inventory_quantity("salt_grilled_rockmane") == 0 and sm.inventory_quantity("rockmane_meat") == 0
			and sm.inventory_quantity("rock_salt") == 0, "正常首单全部材料和成品归零")
		_assert_completed()
		await _capture("after")
		_repeat_checks()
		# 释放旧场景后重新打开，验证同进程恢复与单例旧信号清理。
		scene.queue_free()
		await get_tree().process_frame
		await _start_scene()
		_assert_completed()
		_repeat_checks()
	elif mode in ["resume", "resume_again"]:
		await _start_scene()
		_assert_completed()
		_repeat_checks()
		await _capture(mode)
	else:
		_check(false, "未知验收模式")

func _migration_checks() -> void:
	# CH1-07 格式缺少新字段：读取补默认值，不凭教程完成标记补发声望。
	sm.data = sm._defaults()
	sm.accept_first_order()
	sm.claim_first_order_ingredients()
	sm.cook_first_order()
	sm.data.erase(sm.FIRST_ORDER_SETTLEMENT_KEY)
	sm.data.erase(sm.REPUTATION_KEY)
	sm.data["custom_legacy_field"] = "保留"
	sm.save()
	var legacy_disk := _disk()
	sm.load_data()
	_check(sm.migration_diagnostics.size() == 2 and sm.reputation() == 0 and not sm.has_first_order_settlement(), "旧档默认值有诊断且不补发奖励")
	_check(sm.first_order_progress().next_step == "deliver" and sm.inventory_quantity("salt_grilled_rockmane") == 1
		and sm.data.custom_legacy_field == "保留" and _disk() == legacy_disk, "迁移保留CH1-07进度、未知字段且读取不写盘")
	# 声望为累计值：从已有声望加20，重复调用不再加。
	sm.data[sm.REPUTATION_KEY] = 45
	var result: Dictionary = sm.deliver_first_order()
	_check(result.success and sm.reputation() == 65, "交付在已有声望上累加20")
	_reject_delivery("already_completed", "非零起点重复API")

func _assert_completed() -> void:
	_check(sm.current_order().status == "completed" and not sm.has_active_order(), "订单完成状态持久化")
	_check(sm.has_first_order_settlement() and sm.reputation() == 20, "凭证存在且声望恰好20")
	_check(sm.first_order_progress().next_step == "chapter_wrap_up" and sm.inventory_quantity("salt_grilled_rockmane") == 0,
		"已交付进度与成品零库存一致")
	_check(tm.current_stage == 7 and tm.idx == 16 and not sm.is_chapter_1_done(), "阶段7可继续且章节尚未完成")
	_check(tracker.visible and tracker.get("_order_status").text == "1/1" and tracker.get("_cook_status").text == "0/1"
		and tracker.get("_order_prefix").text == "订单完成：" and tracker.get("_cook_title").text == "烹饪 · 餐厅声望 20", "订单卡同步完成、零成品、声望20")
	_check(get_tree().get_nodes_in_group("guest").size() == 1, "恢复只有一个客人")

func _repeat_checks() -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	for i in 5:
		_press_e()
		player.interacted.emit(scene.get_node("InteractPoints/Register"))
	_check(sm.data == before and _disk() == disk and tm.idx == 16, "重复E和重复信号不改状态或推进")
	_reject_delivery("already_completed", "重复交单API")
	var accept: Dictionary = sm.accept_first_order()
	var claim: Dictionary = sm.claim_first_order_ingredients()
	var cook: Dictionary = sm.cook_first_order()
	_check(not accept.success and not claim.success and not cook.success and sm.data == before and _disk() == disk,
		"已完成首单不能重新接单、取料或制作")
	# 订单已完成但缺凭证的非完整旧数据同样不能再结算。
	sm.data[sm.FIRST_ORDER_SETTLEMENT_KEY] = {}
	_reject_delivery("already_completed", "已完成订单缺凭证仍拒绝重复结算")
	sm.data = before

func _reject_delivery(reason: String, label: String) -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	var result: Dictionary = sm.deliver_first_order()
	_check(not result.success and result.reason == reason and sm.data == before and _disk() == disk,
		label + "：内存和正式存档完全不变", result)

func _serving_stand(target: Node2D) -> Vector2:
	for y in range(-240, 601, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if not player.is_walkable_footprint(candidate):
				continue
			player.global_position = candidate
			var distance: float = player.interaction_distance_to(target)
			if distance > 95.0 and distance <= 120.0 and player.nearest_interactable() == target:
				return candidate
	_check(false, "找到95至120px可走站位")
	return target.global_position

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if guide.toast.visible:
		_check(not guide.toast.get_global_rect().intersects(tracker.get("_panel").get_global_rect()), "反馈不覆盖订单卡")
	var path := _arg("--output-dir=").path_join("CH1-08-" + mode + "-" + label + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "保存实际画面 " + label, {"path": path})
