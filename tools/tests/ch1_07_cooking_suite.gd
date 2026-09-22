extends Node
## 在隔离目录运行真实餐厅；flow、resume_cook、resume_deliver 分别由独立进程执行。

const RESTAURANT := preload("res://scenes/restaurant_map_2d.tscn")
var sm
var tm
var scene: Node2D
var player
var guide
var tracker
var checks: Array = []
var failures := 0
var mode := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var isolation := _arg("--isolation-root=").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if OS.get_environment("MAZE_CH1_07_ISOLATED") != "1" or isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("拒绝运行：存档目录未隔离")
		get_tree().quit(2)
		return
	_check(true, "隔离 user://", {"actual": actual})
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	mode = _arg("--mode=")
	if mode == "flow":
		sm.data = sm._defaults()
		sm.save()
	await _start_scene()
	if mode == "flow":
		await _flow()
	elif mode == "resume_cook":
		await _resume_cook()
	elif mode == "resume_deliver":
		await _resume_deliver()
	else:
		_check(false, "未知验收模式")
	var report := {"ticket": "CH1-07", "mode": mode, "checks": checks, "failures": failures,
		"inventory": sm.inventory_snapshot(), "progress": sm.first_order_progress(), "idx": tm.idx}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CH1_07 ", mode, " checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _start_scene() -> void:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	player = scene.get_node("Player")
	guide = scene.get_node("UIOverlay/TutorialGuide")
	tracker = scene.get_node("UIOverlay/OrderTracking")
	tm.start()
	await get_tree().process_frame

func _flow() -> void:
	# API 拒绝未接单和冲突订单，内存与磁盘均不变化。
	_reject_transaction("no_canonical_order", "未接单")
	var original: Dictionary = sm.data.duplicate(true)
	sm.data[sm.CURRENT_ORDER_KEY] = {"id": "other", "status": "in_progress"}
	_reject_transaction("no_canonical_order", "冲突订单")
	sm.data = original
	# 通过原有对白与过场到达前台；没有直接推进教程步骤。
	var deadline := Time.get_ticks_msec() + 12000
	while tm.idx < 8 and Time.get_ticks_msec() < deadline:
		if guide.dialog.visible:
			guide.dialog._advance()
		await get_tree().process_frame
	_check(tm.idx == 8, "开场真实对白到前台移动")
	await _walk_to("Register", 9)
	_press_e()
	_check(sm.is_canonical_first_order(sm.current_order()) and tm.idx == 10, "前台 E 接单")
	_reject_transaction("ingredients_not_claimed", "尚未取料")
	await _walk_to("Store", 11)
	_press_e()
	await get_tree().process_frame
	var modal := scene.get_node("UIOverlay/WarehouseModal")
	_check(modal.visible, "仓库 E 打开取料界面")
	modal._on_slot_selected("rockmane_meat")
	modal._on_slot_selected("rock_salt")
	modal._on_claim_pressed()
	_check(tm.idx == 12 and sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "实际领取肉盐各一份")
	await _walk_to("Cauldron", 13)
	_check(tracker.get("_cook_status").text == "0/1", "制作前 HUD 为 0/1")
	await _capture("before")
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	player.interacted.emit(scene.get_node("InteractPoints/Fridge"))
	_check(sm.data == before and _disk() == disk and tm.idx == 13, "错目标不改状态")
	var stand: Vector2 = player.global_position
	player.global_position = Vector2(-10000, -10000)
	_press_e()
	player.interacted.emit(scene.get_node("InteractPoints/Cauldron"))
	_check(sm.data == before and _disk() == disk and tm.idx == 13, "超距 E 及伪造信号不改状态")
	player.global_position = stand
	for missing in ["rockmane_meat", "rock_salt"]:
		sm.data[sm.INVENTORY_KEY][missing] = 0
		var insufficient: Dictionary = sm.data.duplicate(true)
		_press_e()
		_check(tm.idx == 13 and sm.data == insufficient and _disk() == disk and tracker.get("_cook_status").text == "0/1", "缺少" + missing + "不扣其他材料、不推进")
		sm.data = before.duplicate(true)
	# 临时文件位置被目录占用，保留正式存档，验证写入失败原子回滚。
	var temporary := ProjectSettings.globalize_path("user://save.json.tmp")
	DirAccess.make_dir_absolute(temporary)
	_press_e()
	_check(sm.data == before and _disk() == disk and tm.idx == 13, "保存失败内存和正式存档均不变")
	DirAccess.remove_absolute(temporary)
	# 暂存制作前状态供下个独立进程启动。
	_check(sm.save(), "保存制作前检查点")

func _resume_cook() -> void:
	# 出生点若已在汤锅移动判定范围内，会自然进入按 E 步骤。
	_check(tm.current_stage == 5 and tm.idx in [12, 13] and not player.input_locked and not guide.dim.visible,
		"独立进程恢复料理制作阶段与输入")
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1 and sm.inventory_quantity("salt_grilled_rockmane") == 0, "制作前库存持久化")
	await _walk_to("Cauldron", 13)
	var order: Dictionary = sm.current_order()
	_press_e()
	_check(tm.idx == 14 and tm.current_stage == 6, "汤锅 E 成功后推进到前台交付")
	_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0 and sm.inventory_quantity("salt_grilled_rockmane") == 1, "原子扣肉盐各一、增加料理一")
	_check(sm.first_order_progress().next_step == "deliver" and sm.first_order_progress().ingredients_claimed, "首单状态为可交付")
	_check(sm.current_order() == order and not sm.is_chapter_1_done(), "未交单且未完成章节")
	_check(tracker.get("_cook_status").text == "1/1" and tracker.get("_meat_status").text == "0/1" and tracker.get("_salt_status").text == "0/1" and tracker.get("_order_status").text == "0/1", "HUD 反映消耗和成品，交付仍 0/1")
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	for i in 5:
		_press_e()
	_check(sm.data == before and _disk() == disk and tm.idx == 14, "重复 E 不重复扣料、产物或推进")
	_reject_transaction("already_cooked", "重复制作 API")
	var duplicate: Dictionary = sm.claim_first_order_ingredients()
	_check(not duplicate.created and sm.data == before and _disk() == disk, "制成后重复取料不补发、不重置进度")
	await _capture("after")

func _resume_deliver() -> void:
	_check(tm.idx == 14 and tm.current_stage == 6 and not player.input_locked and not guide.dim.visible,
		"独立进程恢复待交付教程与输入")
	_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0 and sm.inventory_quantity("salt_grilled_rockmane") == 1 and sm.first_order_progress().next_step == "deliver", "重进成品、消耗和进度一致")
	_check(tracker.visible and tracker.get("_cook_status").text == "1/1" and tracker.get("_order_status").text == "0/1", "重进 HUD 烹饪 1/1、交付 0/1")
	_check(get_tree().get_nodes_in_group("guest").size() == 1, "重进保留唯一等待交付的客人")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	_press_e()
	_check(sm.data == before and _disk() == disk and tm.idx == 14, "重进再按汤锅 E 无副作用")
	await _capture("restart")

func _reject_transaction(reason: String, label: String) -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	var result: Dictionary = sm.cook_first_order()
	_check(not result.success and result.reason == reason and sm.data == before and _disk() == disk, label + "拒绝且不改内存、磁盘", result)

func _walk_to(target_name: String, expected: int) -> void:
	var target := scene.get_node("InteractPoints/" + target_name) as Node2D
	player.global_position = _stand(target)
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if tm.idx == expected and not tm._camera_parked and not tm._camera_cutscene_active and guide.hint_panel.visible:
			break
		await get_tree().process_frame
	var stage_text := "阶段 %d/7 · %s" % [tm.current_stage, tm.CHAPTER_1_STAGE_NAMES[tm.current_stage]]
	_check(tm.idx == expected and player.nearest_interactable() == target and guide.chapter_stage.text == stage_text,
		"到达可走范围内的 " + target_name, {"idx": tm.idx, "stage": guide.chapter_stage.text})

func _stand(target: Node2D) -> Vector2:
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if not player.is_walkable_footprint(candidate):
				continue
			player.global_position = candidate
			if player.nearest_interactable() == target:
				player.last_valid = candidate
				return candidate
	_check(false, "找不到目标可走站位 " + str(target.name))
	return target.global_position

func _press_e() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	player._unhandled_input(event)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if guide.toast.visible:
		_check(not guide.toast.get_global_rect().intersects(tracker.get("_panel").get_global_rect()), "制作反馈不覆盖订单卡")
	var path := _arg("--output-dir=").path_join("CH1-07-" + label + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "保存画面 " + label, {"path": path})

func _disk() -> String:
	return FileAccess.get_file_as_string("user://save.json")

func _check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"name": label, "passed": ok, "details": details})
	if not ok:
		failures += 1
		push_error(label)

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
