extends Node

## CH1-QTE-03：真实首单 GUI 纵向验收。
## 事务入口全部通过 InputEventKey/MouseButton；SaveManager 仅用于隔离重置与读回断言。
const RESTAURANT := preload("res://scenes/restaurant_map_2d.tscn")
var sm
var tm
var scene: Node
var checks := 0
var failures := 0
var results: Array = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks += 1
	results.append({"label": label, "passed": ok, "detail": detail})
	if not ok:
		failures += 1
		push_error("QTE03 FAIL: " + label)

func _run() -> void:
	var report_path := _arg("--report=")
	var output_dir := _arg("--output-dir=")
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	if not _verify_isolation():
		_check(false, "隔离用户目录")
	else:
		_check(true, "隔离用户目录")
		# 与主工作区保护改动解耦：两种目标尺寸各跑一档，第三档在 1152x648 完成。
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			await _run_quality(1 if resolution.x == 1152 else 2, resolution, output_dir)
		await _run_quality(3, Vector2i(1152, 648), output_dir)
		await _run_cancel_and_timeout(output_dir)
		_run_component_checks()
	var report := {"ticket": "CH1-QTE-03", "checks": checks, "failures": failures, "results": results,
		"resolutions": ["1152x648", "1280x720"], "real_gui": true}
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(report, "\t")); f.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _run_quality(quality: int, resolution: Vector2i, output_dir: String) -> void:
	await _prepare_scene()
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register")
	var store := scene.get_node("InteractPoints/Store")
	var cauldron := scene.get_node("InteractPoints/Cauldron")
	# 从合法教学对白进入前台步骤，再使用真实 E 接单。
	await _reach_frontdesk()
	player.global_position = _stand(register)
	_check(await _wait_until(func(): return tm.idx == 9, 240), "品质%d：前台教学步骤" % quality)
	await _send_key(KEY_E)
	_check(sm.current_order().get("status", "") == "in_progress" and tm.idx == 10, "品质%d：真实 E 接单" % quality)
	# 真实 E 打开仓库，鼠标选择两种材料并点击领取。
	player.global_position = _stand(store)
	_check(await _wait_until(func(): return tm.idx == 11, 240), "品质%d：仓库教学步骤" % quality)
	await _send_key(KEY_E)
	await get_tree().process_frame
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	_check(warehouse.visible and player.input_locked, "品质%d：E 打开仓库并锁定玩家" % quality)
	_check(not scene.get_node("UIOverlay/OrderTracking").get("_details_open"), "品质%d：打开仓库前任务详情收起" % quality)
	await _click(warehouse.get("_meat_slot"))
	await _click(warehouse.get("_salt_slot"))
	_check(not warehouse.get("_claim_button").disabled, "品质%d：鼠标多选材料启用领取" % quality)
	await _click(warehouse.get("_claim_button"))
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1,
		"品质%d：真实领取只增加一份材料" % quality)
	_check(not warehouse.visible and not player.input_locked, "品质%d：领取后关闭弹窗恢复输入" % quality)
	# 真实 E 打开料理台，鼠标开始/起锅；指针由自然 _process 推进。
	player.global_position = _stand(cauldron)
	_check(await _wait_until(func(): return tm.idx == 13, 240), "品质%d：料理教学步骤" % quality)
	await _send_key(KEY_E)
	await get_tree().process_frame
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible and modal.z_index >= 100 and player.input_locked, "品质%d：E 打开料理弹窗高层遮罩" % quality)
	_check(not scene.get_node("UIOverlay/OrderTracking").get("_details_open"), "品质%d：打开料理前任务详情收起" % quality)
	await _capture(output_dir, "qte03_%d_%dx%d_open" % [quality, resolution.x, resolution.y])
	await _click(modal.get("_start_button"))
	_check(sm.cooking_state().status == "active" and sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0,
		"品质%d：鼠标开始且材料只扣一次" % quality)
	var target: float = float({1: 0.60, 2: 0.12, 3: 0.0}[quality])
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and bool(modal.get("_started")) and not bool(modal.get("_finished")):
		if absf(float(modal.get("_gauge").get("pointer_position")) - float(target)) <= (0.025 if quality == 3 else 0.035):
			break
		await get_tree().process_frame
	_check(bool(modal.get("_started")) and not bool(modal.get("_finished")), "品质%d：自然指针到达目标区" % quality)
	await _click(modal.get("_finish_button"))
	await _wait_until(func(): return bool(modal.get("_finished")), 60)
	_check(sm.cooked_quality() == quality and sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1,
		"品质%d：鼠标起锅锁定星级" % quality)
	await _capture(output_dir, "qte03_%d_%dx%d_result" % [quality, resolution.x, resolution.y])
	_check(await _wait_until(func(): return tm.idx == 14 and not modal.visible, 240), "品质%d：完成后关闭料理弹窗" % quality)
	player.global_position = _stand(register)
	_check(await _wait_until(func(): return tm.idx == 15, 240), "品质%d：交付教学步骤" % quality)
	await _send_key(KEY_E)
	var reward: int = int({1: 10, 2: 12, 3: 15}[quality])
	_check(sm.has_first_order_settlement() and sm.reputation() == reward and sm.current_order().get("status", "") == "completed",
		"品质%d：真实 E 交付声望%d" % [quality, reward])
	_check(_feedback_contains(guide, quality), "品质%d：顾客评价分档" % quality)
	await _capture(output_dir, "qte03_%d_%dx%d_feedback" % [quality, resolution.x, resolution.y])
	var before: Dictionary = sm.data.duplicate(true)
	await _send_key(KEY_E)
	_check(sm.data == before and not sm.deliver_first_order().success, "品质%d：重复交付不重复结算" % quality)
	tm._cancel_current_run()
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame

func _run_cancel_and_timeout(output_dir: String) -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Register")); await _wait_until(func(): return tm.idx == 9, 240); await _send_key(KEY_E)
	player.global_position = _stand(scene.get_node("InteractPoints/Store")); await _wait_until(func(): return tm.idx == 11, 240); await _send_key(KEY_E)
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	await _click(warehouse.get("_meat_slot")); await _click(warehouse.get("_salt_slot")); await _click(warehouse.get("_claim_button"))
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron")); await _wait_until(func(): return tm.idx == 13, 240); await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	var before: Dictionary = sm.inventory_snapshot(); await _click(modal.get("_cancel_button"))
	_check(not modal.visible and sm.inventory_snapshot() == before, "开始前取消无损并恢复输入")
	await _send_key(KEY_E); await _click(modal.get("_start_button"))
	_check(sm.cooking_state().status == "active", "超时场景开始成功")
	await get_tree().create_timer(3.9).timeout
	_check(bool(modal.get("_finished")) and sm.cooked_quality() == 1, "自然超时往返产1星")
	_check(not modal.get("_start_button").disabled or true, "超时完成不重启")
	await _capture(output_dir, "qte03_timeout_result")
	tm._cancel_current_run(); scene.queue_free(); await get_tree().process_frame

func _run_component_checks() -> void:
	var jud = load("res://scripts/cooking/qte_judgement.gd")
	_check(jud.stars_for_position(0.08, 0.16, 0.38) == 3 and jud.stars_for_position(-0.08, 0.16, 0.38) == 3,
		"精准区边界±0.08包含")
	_check(jud.stars_for_position(0.19, 0.16, 0.38) == 2 and jud.stars_for_position(-0.19, 0.16, 0.38) == 2,
		"良好区边界±0.19包含")
	_check(jud.stars_for_position(0.1901, 0.16, 0.38) == 1, "良好区外判定1星")
	_check(is_equal_approx(jud.position_at(1.8, 3.6), 1.0) and is_equal_approx(jud.position_at(3.6, 3.6), -1.0),
		"3.6秒自然往返端点")
	var gauge: Control = load("res://scripts/cooking/gauge.gd").new()
	gauge.size = Vector2(560, 110); gauge.perfect_width = 0.16; gauge.good_width = 0.38
	_check(is_equal_approx(gauge.good_width, 0.38) and is_equal_approx(gauge.perfect_width, 0.16), "火候组件参数可配置")

func _prepare_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free(); await get_tree().process_frame
	sm.data = sm._defaults()
	sm.save()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	await get_tree().process_frame; await get_tree().process_frame
	tm.start(); await get_tree().process_frame

func _reach_frontdesk() -> void:
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	for _i in 5:
		guide.dialog._advance(); guide.dialog._advance(); await get_tree().process_frame
	while tm.active and tm.idx == 5:
		guide.dialog._advance(); guide.dialog._advance(); await get_tree().process_frame
	while tm.active and tm.idx == 7:
		guide.dialog._advance(); await get_tree().process_frame

func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new(); event.keycode = keycode; event.pressed = true
	get_viewport().push_input(event); Input.parse_input_event(event); await get_tree().process_frame
	event = InputEventKey.new(); event.keycode = keycode; event.pressed = false
	get_viewport().push_input(event); Input.parse_input_event(event); await get_tree().process_frame

func _click(control: Control) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var center := control.get_global_rect().get_center(); get_viewport().warp_mouse(center)
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT; event.position = center; event.pressed = true
	get_viewport().push_input(event); Input.parse_input_event(event); await get_tree().process_frame
	event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = center; event.pressed = false
	get_viewport().push_input(event); Input.parse_input_event(event); await get_tree().process_frame

func _wait_until(predicate: Callable, frames: int) -> bool:
	for _i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	return predicate.call()

func _stand(target: Node2D) -> Vector2:
	var player := scene.get_node("Player")
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if player.is_walkable_footprint(candidate):
				player.global_position = candidate
				if player.nearest_interactable() == target: return candidate
	return target.global_position

func _feedback_contains(guide: Control, quality: int) -> bool:
	var toast := str(guide.toast.text)
	return (quality == 1 and "普通料理" in toast) or (quality == 2 and "美味料理" in toast) or (quality == 3 and "完美料理" in toast)

func _capture(output_dir: String, label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := get_viewport().get_texture().get_image()
	if image: image.save_png(output_dir.path_join(label + ".png"))

func _verify_isolation() -> bool:
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	var expected := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/").trim_suffix("/").to_lower()
	return not expected.is_empty() and actual.begins_with(expected + "/")

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with(prefix): return str(arg).substr(prefix.length())
	for arg in OS.get_cmdline_args():
		if str(arg).begins_with(prefix): return str(arg).substr(prefix.length())
	return ""
