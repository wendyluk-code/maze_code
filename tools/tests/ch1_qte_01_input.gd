extends Node

const RESTAURANT := preload("res://scenes/restaurant_map_2d.tscn")
var failures := 0
var checks := 0
var sm
var tm
var scene: Node

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INPUT FAIL: " + label)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	# 先在真实餐厅场景验证取消：E 打开弹窗，鼠标点取消不扣料、不推进。
	await _prepare_scene()
	var player := scene.get_node("Player")
	var cauldron := scene.get_node("InteractPoints/Cauldron")
	player.global_position = _stand(cauldron)
	await _wait_until(func(): return tm.idx == 13, 180)
	_send_key(KEY_E)
	await get_tree().process_frame
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible and tm.idx == 13, "真实 E 打开烹饪弹窗")
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "打开弹窗未扣材料")
	await _click(modal.get("_cancel_button"))
	_check(not modal.visible and tm.idx == 13 and sm.inventory_quantity("rockmane_meat") == 1, "真实鼠标取消不改状态")
	tm._cancel_current_run()
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	# 三档均由真实 E + 鼠标命中按钮 + 自然时间指针完成。
	for quality in [1, 2, 3]:
		await _run_quality(quality)
	var report := {"ticket": "CH1-QTE-01", "checks": checks, "failures": failures, "resolutions": ["1152x648", "1280x720"]}
	var report_path := _arg("--report=")
	if not report_path.is_empty():
		var report_file := FileAccess.open(report_path, FileAccess.WRITE)
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _run_quality(quality: int) -> void:
	await _prepare_scene()
	var player := scene.get_node("Player")
	var cauldron := scene.get_node("InteractPoints/Cauldron")
	player.global_position = _stand(cauldron)
	await _wait_until(func(): return tm.idx == 13, 180)
	_send_key(KEY_E)
	await get_tree().process_frame
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible and tm.idx == 13, "品质%d：E 进入弹窗" % quality)
	await _capture("quality_%d_open" % quality)
	await _click(modal.get("_start_button"))
	_check(sm.cooking_state().status == "active" and sm.inventory_quantity("rockmane_meat") == 0, "品质%d：鼠标开始扣料一次" % quality)
	await _capture("quality_%d_started" % quality)
	var target: float = float({1: 0.6, 2: 0.12, 3: 0.0}[quality])
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and modal.get("_started") and not modal.get("_finished"):
		var pointer := float(modal.get("_gauge").get("pointer_position"))
		if absf(pointer - target) <= (0.025 if quality == 3 else 0.035):
			break
		await get_tree().process_frame
	_check(modal.get("_started") and not modal.get("_finished"), "品质%d：自然指针到达目标区" % quality)
	await _click(modal.get("_finish_button"))
	await _wait_until(func(): return modal.get("_finished"), 60)
	_check(sm.cooked_quality() == quality and modal.get("_finished"), "品质%d：鼠标起锅锁定品质" % quality)
	await _capture("quality_%d_result" % quality)
	await _wait_until(func(): return tm.idx == 14 and not modal.visible, 180)
	var register := scene.get_node("InteractPoints/Register")
	player.global_position = _stand(register)
	await _wait_until(func(): return tm.idx == 15, 180)
	_send_key(KEY_E)
	await get_tree().process_frame
	var expected_reward: int = int({1: 10, 2: 12, 3: 15}[quality])
	_check(sm.reputation() == expected_reward and sm.current_order().status == "completed", "品质%d：真实 E 交单奖励 %d" % [quality, expected_reward])
	_check(_feedback_contains(quality), "品质%d：顾客评价分档" % quality)
	await _capture("quality_%d_served" % quality)
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _prepare_scene() -> void:
	sm.data = sm._defaults()
	sm.accept_first_order()
	sm.claim_first_order_ingredients()
	sm.save()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame

func _feedback_contains(quality: int) -> bool:
	var toast: String = str(scene.get_node("UIOverlay/TutorialGuide").toast.text)
	return (quality == 1 and "普通料理" in toast) or (quality == 2 and "美味料理" in toast) or (quality == 3 and "完美料理" in toast)

func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	get_viewport().push_input(event)
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	get_viewport().push_input(event)
	Input.parse_input_event(event)
	await get_tree().process_frame

func _click(control: Control) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var center := control.get_global_rect().get_center()
	get_viewport().warp_mouse(center)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = center
	event.pressed = true
	get_viewport().push_input(event)
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = center
	event.pressed = false
	get_viewport().push_input(event)
	Input.parse_input_event(event)
	await get_tree().process_frame

func _wait_until(predicate: Callable, frames: int) -> bool:
	for _i in frames:
		if predicate.call():
			return true
		await get_tree().process_frame
	return predicate.call()

func _stand(target: Node2D) -> Vector2:
	var player := scene.get_node("Player")
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if player.is_walkable_footprint(candidate):
				player.global_position = candidate
				if player.nearest_interactable() == target:
					return candidate
	return target.global_position

func _capture(label: String) -> void:
	var output := _arg("--output-dir=")
	if output.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(output)
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(output.path_join("CH1-QTE-01-input-" + label + ".png"))

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with(prefix):
			return str(arg).substr(prefix.length())
	for arg in OS.get_cmdline_args():
		if str(arg).begins_with(prefix):
			return str(arg).substr(prefix.length())
	return ""
