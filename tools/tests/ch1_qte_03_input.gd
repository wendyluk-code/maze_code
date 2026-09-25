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
var observed_resolutions: Array = []

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
		"resolutions": observed_resolutions, "real_gui": true}
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(report, "\t")); f.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _run_quality(quality: int, resolution: Vector2i, output_dir: String) -> void:
	DisplayServer.window_set_size(resolution)
	await get_tree().process_frame
	await get_tree().process_frame
	var actual_viewport := get_viewport().get_visible_rect().size
	var actual_window := DisplayServer.window_get_size()
	observed_resolutions.append({"requested": str(resolution), "window": str(actual_window), "viewport": str(actual_viewport)})
	_check(absf(float(actual_window.x - resolution.x)) <= 4.0 and absf(float(actual_window.y - resolution.y)) <= 4.0, "品质%d：窗口尺寸实际生效" % quality, {"requested": str(resolution), "window": str(actual_window), "viewport": str(actual_viewport)})
	await _prepare_scene()
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register")
	var store := scene.get_node("InteractPoints/Store")
	var cauldron := scene.get_node("InteractPoints/Cauldron")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	# 从合法教学对白进入前台步骤，再使用真实 E 接单。
	await _reach_frontdesk()
	player.global_position = _stand(register)
	_check(await _wait_until(func(): return tm.idx == 9, 240), "品质%d：前台教学步骤" % quality)
	await _send_key(KEY_E)
	_check(sm.current_order().get("status", "") == "in_progress" and tm.idx >= 10 and tm.idx <= 11, "品质%d：真实 E 接单" % quality)
	await _click(tracker.get("_task_button"))
	_check(bool(tracker.get("_expanded")), "品质%d：真实点击展开任务" % quality)
	# 真实 E 打开仓库，鼠标选择两种材料并点击领取。
	player.global_position = _stand(store)
	_check(await _wait_until(func(): return tm.idx == 11, 240), "品质%d：仓库教学步骤" % quality)
	await _send_key(KEY_E)
	await get_tree().process_frame
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	_check(warehouse.visible and player.input_locked, "品质%d：E 打开仓库并锁定玩家" % quality)
	_check(not bool(tracker.get("_expanded")), "品质%d：打开仓库前任务详情收起" % quality)
	var slots_grid: Control = warehouse.get("_slots_grid")
	var scroll: ScrollContainer = warehouse.get("_scroll")
	_check(is_instance_valid(slots_grid) and int(slots_grid.columns) == 5 and slots_grid.get_child_count() == 30, "品质%d：仓库5列30格" % quality)
	_check(is_instance_valid(scroll) and is_equal_approx(float(scroll.custom_minimum_size.y), 3.5 * 56.0 + 3.0 * 4.0), "品质%d：仓库可视高度3.5行" % quality)
	for slot in slots_grid.get_children():
		_check(slot.size == Vector2(56, 56), "品质%d：仓库格子正方形" % quality)
	var stock_badge: Label = warehouse.get("_meat_slot").get("_stock_badge")
	_check(stock_badge.text == "1" and stock_badge.get_theme_stylebox("normal") is StyleBoxEmpty and stock_badge.get_theme_constant("outline_size") > 0, "品质%d：库存数字仅描边无底色" % quality)
	var hover_region: Control = warehouse.get("_grid_hover_region")
	_check(is_instance_valid(hover_region), "品质%d：仓库悬停区域存在" % quality)
	if not is_instance_valid(hover_region):
		return
	get_viewport().warp_mouse(hover_region.get_global_rect().get_center()); await get_tree().process_frame
	_check(float(scroll.get_v_scroll_bar().self_modulate.a) > 0.5, "品质%d：悬停显示滚动条" % quality)
	get_viewport().warp_mouse(Vector2(4, 4)); await get_tree().process_frame
	_check(float(scroll.get_v_scroll_bar().self_modulate.a) < 0.1, "品质%d：移出隐藏滚动条" % quality)
	_check(is_instance_valid(warehouse.get("_meat_slot").get("_icon_button")) and is_instance_valid(warehouse.get("_salt_slot").get("_icon_button")), "品质%d：仓库图标按钮存在" % quality)
	await _click(warehouse.get("_meat_slot").get("_icon_button"))
	_check(int(warehouse.get("_meat_slot").get_selected_quantity()) == 1, "品质%d：肉图标一次点击只加一份" % quality)
	await _click(warehouse.get("_salt_slot").get("_icon_button"))
	_check(int(warehouse.get("_salt_slot").get_selected_quantity()) == 1, "品质%d：盐图标一次点击只加一份" % quality)
	_check(not warehouse.get("_claim_button").disabled, "品质%d：鼠标多选材料启用领取" % quality)
	var selected_list: Control = warehouse.get("_selected_list")
	_check(is_instance_valid(selected_list) and selected_list.get_child_count() >= 2, "品质%d：已选区显示图标名称与加减行" % quality)
	if quality == 1:
		var wheel_point := scroll.get_global_rect().get_center()
		get_viewport().warp_mouse(wheel_point)
		for _i in 7:
			var wheel := InputEventMouseButton.new(); wheel.position = wheel_point; wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
			get_viewport().push_input(wheel); await get_tree().process_frame
		var last: Control = slots_grid.get_child(29)
		_check(scroll.scroll_vertical > 0 and scroll.get_global_rect().encloses(last.get_global_rect()), "品质1：滚轮到达末行")
		scroll.scroll_vertical = 0
		await get_tree().process_frame
		var meat_row: Control = warehouse.get("_selected_rows").get("rockmane_meat")
		var salt_row: Control = warehouse.get("_selected_rows").get("rock_salt")
		await _click(meat_row.get_child(0).get_node("Minus"))
		await _click(salt_row.get_child(0).get_node("Minus"))
		_check(warehouse.get("_selected").is_empty() and warehouse.get("_claim_button").disabled, "品质1：已选区减一后清空且领取保持禁用")
		await _click(warehouse.get("_meat_slot").get("_icon_button")); await _click(warehouse.get("_salt_slot").get("_icon_button"))
		await _click(warehouse.get("_cancel_button"))
		_check(not warehouse.visible and sm.inventory_snapshot().rockmane_meat == 0 and tm.idx == 11, "品质1：取消仓库不改库存且停留步骤")
		await _send_key(KEY_E); await _wait_until(func(): return warehouse.visible, 60)
		await _click(warehouse.get("_meat_slot").get("_icon_button")); await _click(warehouse.get("_salt_slot").get("_icon_button"))
		_check(warehouse.get("_selected").size() == 2, "品质1：仓库重开清空旧选择后可重新选择")
	await _click(warehouse.get("_claim_button"))
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1,
		"品质%d：真实领取只增加一份材料" % quality)
	_check(not warehouse.visible and not player.input_locked, "品质%d：领取后关闭弹窗恢复输入" % quality)
	# 真实 E 打开料理台，鼠标开始/起锅；指针由自然 _process 推进。
	await _click(tracker.get("_task_button"))
	_check(bool(tracker.get("_expanded")), "品质%d：料理前再次展开任务" % quality)
	player.global_position = _stand(cauldron)
	_check(await _wait_until(func(): return tm.idx == 13, 240), "品质%d：料理教学步骤" % quality)
	await _send_key(KEY_E)
	await get_tree().process_frame
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible and modal.z_index >= 100 and player.input_locked, "品质%d：E 打开料理弹窗高层遮罩" % quality)
	_check(not bool(tracker.get("_expanded")), "品质%d：打开料理前任务详情收起" % quality)
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
	var before_inventory: Dictionary = sm.inventory_snapshot()
	var before_prepared: Dictionary = sm.prepared_dishes_snapshot()
	var before_reputation: int = sm.reputation()
	var before_settlement: Dictionary = sm.data.get("first_order_settlement", {}).duplicate(true)
	await _send_key(KEY_E)
	_check(sm.inventory_snapshot() == before_inventory and sm.prepared_dishes_snapshot() == before_prepared and sm.reputation() == before_reputation and sm.data.get("first_order_settlement", {}) == before_settlement and not sm.deliver_first_order().success, "品质%d：重复交付不重复结算" % quality)
	if quality == 3:
		await _run_post_delivery_empty_warehouse()
	tm._cancel_current_run()
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame

func _run_post_delivery_empty_warehouse() -> void:
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	var player := scene.get_node("Player")
	var store := scene.get_node("InteractPoints/Store")
	var deadline := Time.get_ticks_msec() + 12000
	while tm.active and Time.get_ticks_msec() < deadline:
		var wrapup := str(tm.steps[tm.idx].get("wrapup_id", ""))
		if wrapup == "warehouse_move":
			break
		if tm.steps[tm.idx].get("type", "") == "dialog" and guide.dialog.visible:
			var old_idx: int = tm.idx
			await _send_key(KEY_SPACE)
			if tm.idx == old_idx and guide.dialog.visible:
				await _send_key(KEY_ENTER)
		else:
			await get_tree().process_frame
	_check(str(tm.steps[tm.idx].get("wrapup_id", "")) in ["warehouse_move", "warehouse_inspect"], "交付后继续到仓库检查步骤")
	player.global_position = _stand(store)
	_check(await _wait_until(func(): return str(tm.steps[tm.idx].get("wrapup_id", "")) == "warehouse_inspect", 300), "交付后真实移动到空仓库")
	await _send_key(KEY_E)
	await get_tree().process_frame
	var modal := scene.get_node("UIOverlay/WarehouseModal")
	_check(modal.visible and bool(modal.get("_empty_stock")) and str(modal.get("_message").text) == "没有任何食物" and not modal.get("_claim_button").visible, "交付后E打开空仓库并隐藏领取")
	await _click(modal.get("_cancel_button"))
	_check(not modal.visible and str(tm.steps[tm.idx].get("wrapup_id", "")) == "salt_pool", "确认空仓库后推进盐池线索")
	await _advance_dialogues_until("map_review", 12000)
	var panel := scene.get_node("UIOverlay/DeparturePanel")
	_check(bool(panel.get("_open")), "交付后真实对白打开地图确认面板")
	var map_modal: Control = panel.get("_modal")
	var rows: Control = map_modal.get_child(0).get_child(0)
	var confirm: Button = rows.get_child(rows.get_child_count() - 1) as Button
	_check(is_instance_valid(confirm), "地图面板存在确认按钮")
	await _click(confirm)
	await _advance_dialogues_until("ready_to_depart", 12000)
	var departure := sm.departure_state()
	_check(sm.is_ready_to_depart() and str(departure.get("step", "")) == "ready_to_depart" and departure.get("party", []) == ["yaya", "tieshan"], "交付后地图确认推进到ready_to_depart")

func _advance_dialogues_until(target_wrapup: String, timeout_ms: int) -> void:
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	var deadline := Time.get_ticks_msec() + timeout_ms
	while tm.active and Time.get_ticks_msec() < deadline and str(tm.steps[tm.idx].get("wrapup_id", "")) != target_wrapup:
		if tm.steps[tm.idx].get("type", "") == "dialog" and guide.dialog.visible:
			var old_idx: int = tm.idx
			await _send_key(KEY_SPACE)
			if tm.idx == old_idx and guide.dialog.visible:
				await _send_key(KEY_ENTER)
		else:
			await get_tree().process_frame
	_check(tm.active and str(tm.steps[tm.idx].get("wrapup_id", "")) == target_wrapup, "阶段推进到" + target_wrapup)

func _run_cancel_and_timeout(output_dir: String) -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Register")); await _wait_until(func(): return tm.idx == 9, 240); await _send_key(KEY_E)
	player.global_position = _stand(scene.get_node("InteractPoints/Store")); await _wait_until(func(): return tm.idx == 11, 240); await _send_key(KEY_E)
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	await _click(warehouse.get("_meat_slot").get("_icon_button")); await _click(warehouse.get("_salt_slot").get("_icon_button")); await _click(warehouse.get("_claim_button"))
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron")); await _wait_until(func(): return tm.idx == 13, 240); await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	var before: Dictionary = sm.inventory_snapshot(); await _click(modal.get("_cancel_button"))
	_check(not modal.visible and sm.inventory_snapshot() == before, "开始前取消无损并恢复输入")
	await _send_key(KEY_E); await _click(modal.get("_start_button"))
	_check(sm.cooking_state().status == "active", "超时场景开始成功")
	await get_tree().create_timer(3.9).timeout
	_check(bool(modal.get("_finished")) and sm.cooked_quality() == 1, "自然超时往返产1星")
	var timeout_state: Dictionary = sm.data.duplicate(true)
	await _click(modal.get("_start_button"))
	_check(sm.data == timeout_state and bool(modal.get("_finished")), "超时完成后重复开始不改状态")
	await _capture(output_dir, "qte03_timeout_result")
	tm._cancel_current_run(); scene.queue_free(); await get_tree().process_frame

func _run_component_checks() -> void:
	var jud = load("res://scripts/cooking/qte_judgement.gd")
	_check(jud.stars_for_position(0.08, 0.16, 0.38) == 3 and jud.stars_for_position(-0.08, 0.16, 0.38) == 3,
		"精准区边界±0.08包含")
	_check(jud.stars_for_position(0.19, 0.16, 0.38) == 2 and jud.stars_for_position(-0.19, 0.16, 0.38) == 2,
		"良好区边界±0.19包含")
	_check(jud.stars_for_position(0.1901, 0.16, 0.38) == 1, "良好区外判定1星")
	_check(jud.stars_for_position(0.08, 0.10, 0.38) == 2 and jud.stars_for_position(0.08, 0.16, 0.38) == 3, "判定窗口参数改变边界行为")
	_check(is_equal_approx(jud.position_at(1.8, 3.6), 1.0) and is_equal_approx(jud.position_at(3.6, 3.6), -1.0),
		"3.6秒自然往返端点")
	_check(not is_equal_approx(jud.position_at(0.9, 3.6), jud.position_at(0.9, 1.8)), "时长参数改变同一时刻指针")
	# 该项是组件判定层证据：两套配置在同一输入下产生不同星级/速度；默认 GUI 截图另作为视觉证据。

func _prepare_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free(); await get_tree().process_frame
	sm.data = sm._defaults()
	# 合法接单前夹具：只恢复序章已见客人，不伪造订单/库存/教程索引。
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	sm.save()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	await get_tree().process_frame; await get_tree().process_frame
	tm.start(); await get_tree().process_frame

func _reach_frontdesk() -> void:
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	_check(await _wait_until(func(): return tm.idx == 6, 180), "接单前恢复到客人对白")
	var deadline := Time.get_ticks_msec() + 6000
	while tm.active and tm.idx < 8 and Time.get_ticks_msec() < deadline:
		var before_idx: int = tm.idx
		if guide.dialog.visible:
			await _send_key(KEY_SPACE)
			await get_tree().process_frame
			# 若空格未推进当前可见行，再用 Enter 继续；仍由实际输入驱动。
			if tm.idx == before_idx and guide.dialog.visible:
				await _send_key(KEY_ENTER)
		else:
			await get_tree().process_frame
	_check(tm.idx >= 8, "接单前进入前台移动教学")

func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new(); event.keycode = keycode; event.pressed = true
	get_viewport().push_input(event); await get_tree().process_frame
	event = InputEventKey.new(); event.keycode = keycode; event.pressed = false
	get_viewport().push_input(event); await get_tree().process_frame

func _click(control: Control) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var center := control.get_global_rect().get_center(); get_viewport().warp_mouse(center)
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT; event.position = center; event.pressed = true
	get_viewport().push_input(event); await get_tree().process_frame
	event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = center; event.pressed = false
	get_viewport().push_input(event); await get_tree().process_frame

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
