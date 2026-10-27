extends "res://tools/tests/cooking_v2_acceptance.gd"

func _capture(output_dir: String, label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await super._capture(output_dir, label)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(960,540), Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			await _lesson_case(resolution)
		await _timeout_case()
		await _skip_frame_case()
		await _quality_case(1)
		await _quality_case(2)
		await _result_hold_cancel_case()
		await _followup_case()
		await _cleanup()
		await _dialog_mouse_case()
		var formal: Dictionary = sm.data.duplicate(true)
		sm.begin_replay()
		_check(sm.acknowledge_cooking_guide() and sm.data == formal, "教学标记遵守重播隔离")
		sm.end_replay()
	var report := {"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name()}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("COOKING_COUNTDOWN ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _open_cooking() -> Control:
	var player: Node2D = scene.get_node("Player")
	var target: Node2D = scene.get_node("InteractPoints/Cauldron")
	player.global_position = _stand(target)
	await get_tree().physics_frame
	await get_tree().process_frame
	await _send_key(KEY_E)
	var modal: Control = scene.get_node("HUD/CookingModal")
	_check(modal.visible, "E打开真实料理台")
	return modal

func _lesson_case(resolution: Vector2i) -> void:
	await _prepare_collected()
	var modal = await _open_cooking()
	_check(modal._lesson_paused and modal._lesson_dialog.visible and not modal._started, "首次打开即显示教学，尚未开始烹饪")
	_check(modal._gauge.pointer_position == -1.0, "打开料理台指针位于左侧红区")
	_check(modal._countdown.visible and modal._countdown.text == "05:00", "打开弹窗即显示两位秒与小数05:00")
	await _capture(evidence, "idle_left_%dx%d" % [resolution.x,resolution.y])
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "教学前未扣除原料")
	_check(modal._gauge.tutorial_highlight and modal._start_button.disabled and modal._finish_button.disabled, "教学高亮指针且禁用烹饪按钮")
	_check(modal._cancel_button.disabled, "教学期间关闭按钮同步禁用")
	for button in modal._recipe_choices.get_children():
		if button is BaseButton: _check(button.disabled, "教学期间配方按钮同步禁用")
	modal._on_start_pressed()
	_check(not modal._started, "教学中直接调用也不能提前开火")
	_check(modal._lesson_dialog.speaker_name.text == "芽芽" and modal._lesson_dialog.dialog_text.text == modal.COOKING_GUIDE_LINE, "芽芽头像与完整教学文案")
	_check(modal._lesson_dialog.portrait_texture.texture != null, "教学显示芽芽头像")
	var zones: PackedFloat32Array = modal._gauge.zone_boundaries()
	var green_width: float = zones[3] - zones[2]
	_check(is_equal_approx(zones[2] - zones[1], green_width * 2.0)
		and is_equal_approx(zones[4] - zones[3], green_width * 2.0), "两侧黄色各为绿色总宽度的两倍")
	var boundaries_match := true
	for side in [-1.0, 1.0]:
		for sample in [[0.079, 3], [0.081, 2], [0.399, 2], [0.401, 1]]:
			boundaries_match = boundaries_match and Judgement.stars_for_position(side * sample[0], modal._perfect_width, modal._good_width) == sample[1]
	_check(boundaries_match, "两侧绿黄红边界与实际评分一致")
	var elapsed: float = modal._elapsed
	var pointer: float = modal._gauge.pointer_position
	var anim: float = modal._gauge.animation_time
	var countdown: String = modal._countdown.text
	var step: int = tm.idx
	await get_tree().create_timer(3.2).timeout
	await _send_key(KEY_SPACE)
	await _send_key(KEY_ESCAPE)
	_check(modal._lesson_paused and modal._elapsed == elapsed and modal._gauge.pointer_position == pointer, "教学超过三秒且其他输入不消耗倒计时")
	_check(modal._gauge.animation_time == anim and not modal._finished, "教学冻结火苗食材动画且不提前出餐")
	_check(modal._countdown.text == countdown, "教学中毫秒显示同步冻结")
	await _capture(evidence, "lesson_%dx%d" % [resolution.x,resolution.y])
	await _verify_spotlight(modal)
	var dialog_rect: Rect2 = modal._lesson_dialog.get_global_rect()
	_check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(dialog_rect), "小大窗口教学完整位于画面内")
	_check(is_equal_approx(dialog_rect.size.y, 124.0)
		and is_equal_approx(get_viewport().get_visible_rect().size.y - dialog_rect.end.y, 30.0), "教学沿用原对白高度124与底距30")
	_check(not modal._lesson_dialog.dialog_text.get_global_rect().intersects(modal._lesson_dialog.next_icon.get_global_rect()), "长对白为E提示留位不重叠")
	var previous: Dictionary = sm.data.duplicate(true)
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	await _send_key(KEY_E)
	_check(modal._lesson_paused and sm.data == previous, "教学保存失败保持暂停且标记回滚")
	_check("教学进度未保存，请按 E 重试。" in modal._lesson_dialog.dialog_text.text, "失败重试提示在最上层对白内可见")
	sm._active_save_path = save_path
	if resolution.x == 960:
		await _click_at(modal._start_button.get_global_rect().get_center())
	else:
		await _send_key(KEY_E)
	_check(not modal._lesson_paused and not modal._lesson_dialog.visible and not modal._gauge.tutorial_highlight, "空白左键或E关闭教学")
	_check(not modal._started and modal._elapsed == 0.0 and modal._gauge.pointer_position == -1.0 and tm.idx == step, "关闭教学不透传启动，指针与五秒计时仍待命")
	_check(not modal._start_button.disabled and modal._finish_button.disabled, "关闭教学只恢复开始按钮")
	_check(not modal._cancel_button.disabled and modal._lesson_button_states.is_empty(), "教学结束恢复关闭按钮并释放禁用快照")
	await _click(modal._start_button)
	_check(modal._started and modal._gauge.pointer_position < -.75, "主动开始后指针从左红区向右移动")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_display_seconds(modal._countdown.text) < 5.0 and _display_seconds(modal._countdown.text) > 4.5, "主动开始后从五秒递减")
	_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0, "开始仅扣一份原料")
	# 约1.111秒经过绿区中心，使用真实鼠标按下即时锁定。
	_check(await _wait_seconds(func(): return absf(modal._gauge.pointer_position) < .04, 2.0) and not modal._lesson_paused, "指针到绿区中心且不重复教学")
	await _finish_click(modal)
	await _verify_result_hold(modal, "three_stars_%dx%d" % [resolution.x,resolution.y])
	_check(sm.cooked_quality() == 3 and modal._result_popup.visible, "教学后真实点击结束得到三星弹窗")
	await _capture(evidence, "three_stars_%dx%d" % [resolution.x,resolution.y])
	sm.load_data()
	_check(not sm.needs_cooking_guide() and sm.data.cooking_guide_seen, "教学标记读档保持")
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, "仅产出一份成品")

func _finish_click(modal: Control) -> void:
	var point: Vector2 = modal._finish_button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame

func _timeout_case() -> void:
	await _prepare_collected()
	_check(sm.acknowledge_cooking_guide(), "已教学前置")
	var modal = await _open_cooking()
	await _click(modal._start_button)
	var displays: Array[String] = [modal._countdown.text]
	var reached_right := false
	var returned_left := false
	var until := Time.get_ticks_msec() + 7000
	while not modal._finished and Time.get_ticks_msec() < until:
		if not modal._countdown.text in displays: displays.append(modal._countdown.text)
		if modal._gauge.pointer_position > .95: reached_right = true
		if reached_right and modal._gauge.pointer_position < -.95: returned_left = true
		await get_tree().process_frame
	if not modal._countdown.text in displays: displays.append(modal._countdown.text)
	var pattern := RegEx.create_from_string("^0[0-5]:[0-9]{2}$")
	var valid_format := displays.size() > 10 and displays[-1] == "00:00"
	var previous := 5.0
	for display in displays:
		valid_format = valid_format and pattern.search(display) != null and _display_seconds(display) <= previous
		previous = _display_seconds(display)
	_check(valid_format, "两位秒与小数持续递减至00:00", {"samples":displays.size()})
	_check(reached_right and returned_left and not modal._lesson_paused, "再次提速后五秒内完成左右往返")
	_check(modal._elapsed == 5.0 and sm.cooked_quality() == 1, "五秒倒计时归零自动一星结算")

func _skip_frame_case() -> void:
	await _prepare_collected()
	var modal = await _open_cooking()
	modal._process(4.0)
	_check(modal._lesson_paused and modal._elapsed == 0.0 and not modal._started, "教学期间长帧不启动烹饪")
	tm._cancel_current_run()
	_check(not modal._lesson_paused and not modal.visible and not modal._lesson_dialog.visible, "中断教学清除输入遮挡与暂停")
	_check(sm.cooked_quality() == 0 and sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "开火前中断不扣料也不产出料理")
	modal.open_for_order()
	_check(modal._lesson_paused and modal._lesson_dialog.visible, "未确认教学中断后重开仍显示说明")
	await _send_key(KEY_E)
	await _send_key(KEY_ESCAPE)
	_check(not modal.visible and not modal._lesson_blocker.visible, "确认教学后可取消弹窗且移除遮挡")
	modal.open_for_order()
	_check(not modal._lesson_paused and not modal._start_button.disabled, "已确认教学重开不重复显示且可以开始")

func _quality_case(stars: int) -> void:
	await _prepare_collected()
	sm.acknowledge_cooking_guide()
	var modal = await _open_cooking()
	await _click(modal._start_button)
	if stars == 2:
		_check(await _wait_seconds(func(): return absf(modal._gauge.pointer_position) > .28 and absf(modal._gauge.pointer_position) <= .32, 3.0), "自然进入加宽后的黄色区域")
	await _finish_click(modal)
	await _verify_result_hold(modal, "quality_%d" % stars)
	_check(sm.cooked_quality() == stars and modal._result_popup.visible, "真实点击维持%d星判定" % stars)

func _verify_result_hold(modal: Control, label: String) -> void:
	var started_at := Time.get_ticks_msec()
	var pointer: float = modal._gauge.pointer_position
	var countdown: String = modal._countdown.text
	var saved: Dictionary = sm.data.duplicate(true)
	_check(modal._finished and modal._panel.visible and not modal._result_popup.visible
		and modal._finish_button.disabled and not modal._gauge.running, "结束后立即锁定指针并保留烹饪界面")
	await _send_key(KEY_SPACE)
	await _send_key(KEY_E)
	await _send_key(KEY_ESCAPE)
	await _finish_click(modal)
	await get_tree().create_timer(0.10).timeout
	_check(modal.visible and modal._panel.visible and not modal._result_popup.visible
		and modal._gauge.pointer_position == pointer and modal._countdown.text == countdown
		and sm.data == saved, "停留期间仍保持落点，连点和按键不重复结算或提前切走")
	await _capture(evidence, "hold_" + label)
	_check(await _wait_seconds(func(): return modal._result_popup.visible, 2.0), "半秒后自动显示料理结果")
	var elapsed_ms := Time.get_ticks_msec() - started_at
	_check(elapsed_ms >= 400 and elapsed_ms < 1100 and not modal._panel.visible
		and modal._gauge.pointer_position == pointer and sm.data == saved,
		"结果在约半秒后出现，品质落点及成品不变", {"elapsed_ms":elapsed_ms})

func _result_hold_cancel_case() -> void:
	await _prepare_collected()
	sm.acknowledge_cooking_guide()
	var modal = await _open_cooking()
	await _click(modal._start_button)
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	await _finish_click(modal)
	var pointer: float = modal._gauge.pointer_position
	_check(not modal._finished and not modal._result_popup.visible and modal._result_hold_until_msec == 0,
		"保存失败保留落点供重试，不启动成功展示等待")
	sm._active_save_path = save_path
	await _finish_click(modal)
	_check(modal._finished and modal._gauge.pointer_position == pointer and modal._result_hold_until_msec > 0,
		"保存重试成功沿用原落点并开始半秒停留")
	var saved: Dictionary = sm.data.duplicate(true)
	modal.close_modal()
	modal.open_for_order()
	await get_tree().create_timer(2.2).timeout
	_check(modal.visible and modal._panel.visible and not modal._result_popup.visible
		and modal._result_hold_until_msec == 0 and sm.data == saved,
		"停留期间关闭重开，旧等待不会弹出结果或重复产出")

func _followup_case() -> void:
	await _cleanup()
	sm.data = sm._defaults()
	sm.accept_first_order(); sm.claim_first_order_ingredients(); sm.cook_first_order(); sm.deliver_first_order()
	for step in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(step) or step == "ready_to_depart": continue
		sm.advance_departure(step)
	for step in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(step)
	_check(sm.register_customer_order("qte-followup", sm.FIRST_ORDER_ITEM_ID).success and sm.accept_waiting_customer_order().success, "后续顾客接单")
	sm.data.warehouse_stock = {"rockmane_meat":1,"rock_salt":1}
	sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1})
	_check(not sm.needs_cooking_guide(), "旧档后续订单即使无已读标记也不教学")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	var modal = await _open_cooking()
	await _click(modal._start_button)
	await get_tree().create_timer(5.2).timeout
	_check(modal._elapsed == 5.0 and not modal._lesson_paused and sm.cooked_quality() == 1, "后续顾客复用五秒倒计时且无首章教学")

func _display_seconds(value: String) -> float:
	var parts := value.split(":")
	if parts.size() != 2:
		return -1.0
	return parts[0].to_float() + parts[1].to_float() / 100.0

func _wait_seconds(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return predicate.call()

func _click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame

func _brightness(image: Image, rect: Rect2) -> float:
	var clipped := rect.intersection(Rect2(Vector2.ZERO, image.get_size()))
	var total := 0.0
	var count := 0
	for y in range(int(clipped.position.y), int(clipped.end.y), 2):
		for x in range(int(clipped.position.x), int(clipped.end.x), 2):
			var color := image.get_pixel(x,y)
			total += color.r + color.g + color.b
			count += 1
	return total / maxf(1.0,count)

func _verify_spotlight(modal: Control) -> void:
	await RenderingServer.frame_post_draw
	var shaded := get_viewport().get_texture().get_image()
	modal._lesson_blocker.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var clear := get_viewport().get_texture().get_image()
	modal._lesson_blocker.show()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pointer: Vector2 = modal._gauge.get_global_transform() * modal._gauge.pointer_tip()
	var focus := Rect2(pointer - Vector2(12,12),Vector2(24,24))
	var dialog: Rect2 = modal._lesson_dialog.get_global_rect().grow(-10)
	var pot_center: Vector2 = modal._gauge.get_global_transform() * (modal._gauge.size * Vector2(.5,.6))
	var pot := Rect2(pot_center - Vector2(20,20),Vector2(40,40))
	_check(absf(_brightness(shaded,focus) - _brightness(clear,focus)) < .04, "镂空处指针保持原始亮度")
	var band_visible := true
	for step in range(41):
		for inset in [0.0, modal._gauge.BAND_WIDTH * 0.5, modal._gauge.BAND_WIDTH]:
			var local: Vector2 = modal._gauge._design_offset() + modal._gauge.arc_point(float(step) / 40.0, inset) * modal._gauge._design_scale()
			var point: Vector2 = modal._gauge.get_global_transform() * local
			var area := Rect2(point - Vector2(2,2), Vector2(4,4))
			band_visible = band_visible and absf(_brightness(shaded,area) - _brightness(clear,area)) < .04
	_check(band_visible, "整条弧形带及上下边缘均完整挖空，不受教学遮罩压暗")
	# 原对白底板为96%不透明，允许其余4%的下层变化透出，不应被68%的教学暗幕覆盖。
	_check(_brightness(shaded,dialog) > _brightness(clear,dialog) * .94, "对白位于教学蒙层上方保持清晰",
		{"shaded":_brightness(shaded,dialog),"clear":_brightness(clear,dialog)})
	_check(_brightness(shaded,pot) < _brightness(clear,pot) * .55, "汤锅和教学背景被遮罩压暗")
	_check(modal._lesson_blocker.get_index() < modal._lesson_dialog.get_index(), "教学遮罩位于对白下方")

func _dialog_mouse_case() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var background := Button.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var clicks: Array = []
	background.pressed.connect(func(): clicks.append(true))
	var dialog = preload("res://scenes/ui/dialog_box.tscn").instantiate()
	layer.add_child(dialog)
	var finishes: Array = []
	dialog.finished.connect(func(): finishes.append(true))
	dialog.start("芽芽", ["第一句对白。", "第二句对白。"], preload("res://assets/characters/yaya_portrait.png"))
	dialog.set_process(false)
	await _click_at(Vector2(30,40))
	_check(dialog._line_idx == 0 and dialog.dialog_text.text == "第一句对白。", "全局空白点击先补全当前对白，不重复跳句")
	await _click_at(Vector2(30,40))
	_check(dialog._line_idx == 1 and dialog.visible, "再次空白点击推进一句对白")
	await _click_at(Vector2(30,40))
	await _click_at(Vector2(30,40))
	_check(not dialog.visible and finishes.size() == 1 and clicks.is_empty(), "末句点击关闭对白一次且不触发背后按钮")
	layer.queue_free()
	await get_tree().process_frame
