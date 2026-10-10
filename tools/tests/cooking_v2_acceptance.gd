extends "res://tools/tests/ch1_qte_03_input.gd"
## Real GUI acceptance for the approved cauldron design. Fixtures only seed saves;
## user-facing transactions use viewport keyboard/mouse input.

const ModalScript := preload("res://scripts/ui/cooking_modal.gd")
const Judgement := preload("res://scripts/cooking/qte_judgement.gd")
var evidence := ""
var case_label := ""

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "独立存档目录")
	_check(DisplayServer.get_name() != "headless", "实际 GUI 渲染")
	if failures == 0:
		await _recipe_states()
		await _quality_flow(3, Vector2i(1152, 648), true)
		await _quality_flow(2, Vector2i(1280, 720), false)
		await _quality_flow(1, Vector2i(1152, 648), false)
		await _timeout_flow()
		_run_component_checks()
	var report := {"checks": checks, "failures": failures, "results": results,
		"display": DisplayServer.get_name(), "resolutions": observed_resolutions,
		"user_dir": ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _cleanup() -> void:
	if tm.active:
		tm._cancel_current_run()
	if is_instance_valid(scene):
		scene.queue_free()
		await get_tree().process_frame
		scene = null

func _prepare_collected() -> void:
	await _cleanup()
	sm.data = sm._defaults()
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success, "夹具合法接单")
	_check(sm.claim_first_order_ingredients().success, "夹具合法领取")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame

func _full_order_and_claim() -> void:
	await _cleanup()
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	_check(await _wait_until(func(): return tm.idx == 9, 240), "首单真实流程：到达前台")
	await _send_key(KEY_E)
	_check(sm.current_order().status == "in_progress", "首单真实 E 接单")
	_check(sm.FIRST_ORDER_ITEM_ID in sm.unlocked_recipe_ids(), "真实接单解锁菜谱")
	_check(guide.dialog.visible, "接单保留芽芽分步说明")
	for _i in 4:
		if not guide.dialog.visible:
			break
		await _send_key(KEY_E)
	_check(not guide.dialog.visible and not player.input_locked, "说明可按 E 结束恢复移动")
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	_check(await _wait_until(func(): return tm.idx == 11, 240), "首单真实流程：到达仓库")
	await _send_key(KEY_E)
	var warehouse := scene.get_node("UIOverlay/WarehouseModal")
	_check(warehouse.visible, "E 打开仓库")
	await _click(warehouse.get("_meat_slot").get("_icon_button"))
	await _click(warehouse.get("_salt_slot").get("_icon_button"))
	await _click(warehouse.get("_claim_button"))
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "真实仓库领取一肉一盐")
	_check(not warehouse.visible, "领取后关闭仓库")

func _quality_flow(quality: int, resolution: Vector2i, full_flow: bool) -> void:
	DisplayServer.window_set_size(resolution)
	await get_tree().process_frame
	await get_tree().process_frame
	case_label = "q%d_%dx%d" % [quality, resolution.x, resolution.y]
	observed_resolutions.append({"requested": str(resolution), "window": str(DisplayServer.window_get_size()), "viewport": str(get_viewport().get_visible_rect().size)})
	_check(DisplayServer.window_get_size() == resolution, case_label + " 窗口尺寸生效")
	if full_flow:
		await _full_order_and_claim()
	else:
		await _prepare_collected()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	_check(await _wait_until(func(): return tm.idx == 13, 240), case_label + " 料理教学步骤")
	var before: Dictionary = sm.inventory_snapshot()
	await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible and not modal.get("_started") and sm.inventory_snapshot() == before, case_label + " 首次 E 仅打开不误开始不扣料")
	_check(player.input_locked, case_label + " 料理弹窗锁定移动")
	await get_tree().create_timer(0.16).timeout
	_check_layout(modal)
	_check(is_zero_approx(float(modal.get("_gauge").get("pointer_position"))), case_label + " 空闲菱形指针居中")
	await _shot("ready")
	await _verify_gauge_geometry(modal)
	if full_flow:
		await _send_key(KEY_ESCAPE)
		_check(not modal.visible and not player.input_locked and sm.inventory_snapshot() == before and tm.idx == 13, "开始前 ESC 取消不扣料不推进")
		await _send_key(KEY_E)
	await _click(modal.get("_start_button"))
	_check(sm.cooking_state().status == "active" and sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0, case_label + " 开始仅扣一份配方")
	_check(sm.reputation() == 0, case_label + " 开始不结算声望")
	await _verify_running(modal)
	await _shot("running")
	var target: float = {1: -0.6, 2: -0.14, 3: 0.0}[quality]
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and not bool(modal.get("_finished")):
		if absf(float(modal.get("_gauge").get("pointer_position")) - target) <= 0.019:
			break
		await get_tree().process_frame
	_check(not bool(modal.get("_finished")), case_label + " 指针自然到达目标区")
	if quality == 3:
		await _send_key(KEY_SPACE)
	else:
		await _click_now(modal.get("_finish_button"))
	_check(sm.cooked_quality() == quality and sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, case_label + " 真实结束按钮产出对应星级", {"pointer": modal.get("_locked_pointer"), "actual_quality": sm.cooked_quality()})
	_check(sm.reputation() == 0, case_label + " 做成料理仍未结算声望")
	await _verify_stopped(modal)
	await get_tree().create_timer(1.1).timeout
	var popup = modal.get("_result_popup")
	_check(popup.visible and not modal.get("_panel").visible and tm.idx == 13 and player.input_locked, case_label + " 独立结果等待确认不自动关闭")
	_check(popup._dish_name.text == "盐烤岩鬃肉" and popup._icon.texture != null and popup.quality == quality, case_label + " 结果显示料理图标名称与实际星级")
	_check(popup._confirm_button.text == "确认", case_label + " 按钮文案为确认")
	_check(not popup._stars is Label and popup._stars.quality == quality and popup._stars.CENTERS.size() == 3, case_label + " 固定三颗图形星槽且无星级文案")
	_check(not popup._stars.is_processing(), case_label + " 星星入场后停止动画处理")
	await RenderingServer.frame_post_draw
	var rating_image := get_viewport().get_texture().get_image()
	for index in 3:
		var center: Vector2 = popup._stars.global_position + popup._stars.CENTERS[index]
		var gold_pixels := 0
		for dx in range(-6,7):
			for dy in range(-6,7):
				var pixel := rating_image.get_pixel(int(center.x)+dx,int(center.y)+dy)
				if pixel.r > 0.9 and pixel.g > 0.65 and pixel.b < 0.45: gold_pixels += 1
		_check((gold_pixels > 100) == (index < quality),case_label + " 实际绘制亮星和空槽正确："+str(index),{"gold_pixels":gold_pixels})
	_check(not scene.get_node("UIOverlay/TutorialGuide").toast.visible, case_label + " 不再使用完成toast")
	await _send_key(KEY_SPACE)
	_check(popup.visible, case_label + " 结束烹饪空格不会关闭结果")
	await _shot("result")
	if quality == 2:
		await _send_key(KEY_E)
	else:
		await _click(popup._confirm_button)
	_check(await _wait_until(func(): return tm.idx in [14,15] and tm.current_stage == 6 and not modal.visible, 240), case_label + " 确认结果后进入上菜引导")
	_check(not player.input_locked, case_label + " 制作结束恢复移动")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	_check(await _wait_until(func(): return tm.idx == 15, 240), case_label + " 交付教学步骤")
	await _send_key(KEY_E)
	var expected_reward: int = {1: 60, 2: 80, 3: 100}[quality]
	_check(sm.current_order().status == "completed" and sm.reputation() == expected_reward, case_label + " 交付按星级结算声望")
	_check(_feedback_contains(scene.get_node("UIOverlay/TutorialGuide"), quality), case_label + " 顾客评价正确")
	await _shot("delivered")
	await _cleanup()

func _recipe_states() -> void:
	# Set up invalid/extra inventory only here; all mutation attempts are real GUI clicks.
	for mode in ["locked", "missing_salt", "extra_and_finished", "extra_only"]:
		sm.data = sm._defaults()
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		if mode == "locked":
			sm.data[sm.UNLOCKED_RECIPES_KEY] = []
		elif mode == "missing_salt":
			sm.data.inventory.rock_salt = 0
		else:
			sm.data.inventory.rockmane_meat = 3
			sm.data.inventory.rock_salt = 2
			sm.data.inventory.salt_grilled_rockmane = 1 if mode == "extra_and_finished" else 0
		var modal := Control.new()
		modal.set_script(ModalScript)
		add_child(modal)
		await get_tree().process_frame
		var before: Dictionary = sm.inventory_snapshot()
		modal.open_for_order()
		await get_tree().process_frame
		_check(sm.inventory_snapshot() == before, mode + " 打开零消耗")
		if mode in ["locked", "missing_salt"]:
			_check(modal.get("_start_button").disabled, mode + " 禁止开始")
			await _click(modal.get("_start_button"))
			_check(sm.inventory_snapshot() == before and sm.cooking_state().status == "idle", mode + " 禁用按钮没有事务")
		else:
			_check(bool(modal.get("_start_button").disabled) == (mode == "extra_and_finished"), "首单已有成品禁用；仅多份原料可开始")
			_check(sm.carried_ingredients() == {"rockmane_meat": 3, "rock_salt": 2}, "原料过滤成品且保留真实数量")
			await _verify_carried(modal)
			if mode == "extra_only":
				await _click(modal.get("_start_button"))
				_check(sm.inventory_quantity("rockmane_meat") == 2 and sm.inventory_quantity("rock_salt") == 1, "多余携带食材仅扣所选配方一份")
				var save_path: String = sm._active_save_path
				sm._active_save_path = ""
				await _click_now(modal.get("_finish_button"))
				_check(not modal.get("_result_popup").visible and not modal.get("_finished"), "保存失败不展示成功结果")
				var locked: int = modal.get("_locked_stars")
				sm._active_save_path = save_path
				await _click_now(modal.get("_finish_button"))
				_check(modal.get("_result_popup").quality == locked, "保存重试结果保持首次锁定品质")
				await _click_now(modal.get("_finish_button"))
				_check(sm.inventory_quantity("rockmane_meat") == 2 and sm.inventory_quantity("rock_salt") == 1 and sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1, "结束重复点击不重复扣料或产出")
		modal.close_modal()
		modal.queue_free()
		await get_tree().process_frame

func _timeout_flow() -> void:
	await _prepare_collected()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	await _wait_until(func(): return tm.idx == 13, 240)
	await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	await _click(modal.get("_start_button"))
	await _send_key(KEY_ESCAPE)
	_check(modal.visible and modal.get("_started"), "运行中 ESC 不退款或中断 QTE")
	var timeout_deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < timeout_deadline and not bool(modal.get("_finished")):
		await get_tree().process_frame
	_check(bool(modal.get("_finished")), "无人操作自动结算")
	_check(sm.cooked_quality() == 1 and sm.inventory_quantity("rockmane_meat") == 0, "超时一星不退款")
	await _cleanup()

func _check_layout(modal: Control) -> void:
	var panel: Control = modal.get("_panel")
	_check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), case_label + " 弹窗完整位于视口", {"rect": str(panel.get_global_rect())})
	for field in ["_start_button", "_finish_button", "_cancel_button"]:
		var button: Button = modal.get(field)
		if button.is_visible_in_tree():
			_check(panel.get_global_rect().encloses(button.get_global_rect()), case_label + " 按钮完整 " + field)
		_check(button.get_theme_font("font") == SproutTheme.FONT_CN, case_label + " 组件库字体 " + field)
	var start: Button = modal.get("_start_button")
	_check(start.get_theme_stylebox("normal") is StyleBoxTexture and start.text == "开始烹饪", case_label + " 开始按钮组件库样式")
	_check(modal.get("_finish_button").text == "结束烹饪", case_label + " 结束按钮明确文案")

func _verify_carried(modal: Control) -> void:
	var gauge: Control = modal.get("_gauge")
	_check(gauge.get("ingredients") == {"rockmane_meat": 3, "rock_salt": 2}, "锅内直接展示真实携带原料数量，不含成品")
	_check(not bool(gauge.get("running")), "打开不播放火与食材动画")
	_check(modal.get("_available_recipe_ids") == ["salt_grilled_rockmane"], "自动只匹配足量已解锁配方")
	var row: Control = modal.get("_recipe_choices")
	_check(row.get_child_count() == 2 and row.get_child(1).text == "盐烤岩鬃肉", "料理下方显示已匹配料理名称")
	_check(row.get_child(1).icon != null, "匹配料理使用既有成品图标")

func _verify_running(modal: Control) -> void:
	var gauge: Control = modal.get("_gauge")
	_check(bool(gauge.get("running")) and gauge.is_processing(), case_label + " 开始启动独立火焰食材动画")
	_check(gauge.get("ingredients") == {"rockmane_meat": 1, "rock_salt": 1}, case_label + " 烹饪展示本次投入原料")
	_check(not modal.get("_start_button").visible and modal.get("_finish_button").visible and not modal.get("_finish_button").disabled, case_label + " 单主按钮切换结束烹饪")
	var before_time: float = gauge.get("animation_time")
	await get_tree().create_timer(0.09).timeout
	_check(float(gauge.get("animation_time")) > before_time, case_label + " 动画时钟推进")
	for _sample in 3:
		await _check_drawn_pointer(gauge)
		await get_tree().create_timer(0.04).timeout
	var boundaries: PackedFloat32Array = gauge.zone_boundaries()
	var expected := [0.0, 0.405, 0.46, 0.54, 0.595, 1.0]
	var aligned := boundaries.size() == expected.size()
	for index in range(mini(boundaries.size(), expected.size())):
		aligned = aligned and absf(boundaries[index] - expected[index]) < 0.00001
	_check(aligned, case_label + " 实绘弧带边界对应原 QTE 判定阈值", {"boundaries": Array(boundaries)})
	_check(Rect2(Vector2.ZERO, gauge.size).has_point(gauge.pointer_tip()), case_label + " 指针尖端位于可见图层")
	_check(gauge.get("_pot") != null and gauge.get("_fire") != null, case_label + " 锅体与火焰真实分层 PNG 资源保持")

func _verify_stopped(modal: Control) -> void:
	var gauge: Control = modal.get("_gauge")
	var pointer: float = gauge.get("pointer_position")
	_check(not bool(gauge.get("running")) and not gauge.is_processing(), case_label + " 结束停火停止食材动画")
	await get_tree().create_timer(0.09).timeout
	_check(is_equal_approx(pointer, float(gauge.get("pointer_position"))) and is_zero_approx(float(gauge.get("animation_time"))), case_label + " 判定后指针及动画稳定")

func _verify_gauge_geometry(modal: Control) -> void:
	# 只在尚未开始的视觉夹具中定位指针，不改实际 QTE 时间或事务状态。
	var gauge: Control = modal.get("_gauge")
	var width: float = gauge.BAND_WIDTH
	var factor: float = gauge._design_scale()
	var offset: Vector2 = gauge._design_offset()
	var left: Vector2 = gauge.arc_point(0.0,width * 0.5)
	var middle: Vector2 = gauge.arc_point(0.5,width * 0.5)
	var right: Vector2 = gauge.arc_point(1.0,width * 0.5)
	_check(middle.y < left.y and middle.y < right.y and is_equal_approx(left.y,right.y) and left.x < middle.x and middle.x < right.x,
		case_label + " 弧带是上拱∩且左右对称",{"left":str(left),"middle":str(middle),"right":str(right)})
	var thickness: float = gauge.arc_point(0.5,0.0).distance_to(gauge.arc_point(0.5,width))
	_check(thickness * factor >= 12.0 and thickness * factor <= 18.0,case_label + " 弧带加粗后清晰可见",{"screen_thickness":thickness*factor})
	for pointer in [-1.0,-0.19,-0.08,0.0,0.08,0.19,1.0]:
		gauge.set_pointer(pointer)
		var fraction: float = (pointer + 1.0) * 0.5
		var outer: Vector2 = gauge.arc_point(fraction,0.0)
		var inner: Vector2 = gauge.arc_point(fraction,width)
		var expected_center: Vector2 = offset + (outer + inner) * 0.5 * factor
		var actual: Vector2 = gauge.pointer_tip()
		_check(actual.distance_to(expected_center) < 0.1 and Rect2(Vector2.ZERO,gauge.size).has_point(actual),case_label + " 指针中心落弧带中线 %.2f" % pointer,{"center":str(actual),"error":actual.distance_to(expected_center)})
		await _check_drawn_pointer(gauge)
		if pointer in [-1.0,0.0,1.0] and not case_label.begins_with("q1_"):
			await _shot("pointer_" + str(pointer))
	# 把指针移到端点，避开采样像素；检查真实绘制色区而非仅检查返回值。
	gauge.set_pointer(-1.0)
	await RenderingServer.frame_post_draw

	var frame := get_viewport().get_texture().get_image()
	for pointer in [-0.6,-0.13,0.0,0.13,0.6]:
		var fraction: float = (pointer + 1.0) * 0.5
		var local_point: Vector2 = offset + gauge.arc_point(fraction,width*0.5) * factor
		var pixel: Vector2 = gauge.get_global_transform_with_canvas() * local_point
		var color := frame.get_pixelv(Vector2i(pixel))
		var stars := Judgement.stars_for_position(pointer,float(gauge.perfect_width),float(gauge.good_width))
		var matches := (color.r > color.g + 0.07 and color.r > color.b + 0.07) if stars == 1 else ((color.r > color.b + 0.12 and color.g > color.b + 0.12) if stars == 2 else (color.g > color.r + 0.04 and color.g > color.b + 0.02))
		_check(matches,case_label + " 实绘色区与真实判定一致 %.2f→%d星" % [pointer,stars],{"pixel":str(pixel),"color":str(color)})
	gauge.set_pointer(0.0)
	await RenderingServer.frame_post_draw

func _check_drawn_pointer(gauge: Control) -> void:
	await RenderingServer.frame_post_draw
	var pixel: Vector2 = gauge.get_global_transform_with_canvas() * gauge.pointer_tip()
	var frame := get_viewport().get_texture().get_image()
	var drawn := frame.get_pixelv(Vector2i(pixel.round()))
	var expected := Color("#41433e")
	_check(absf(drawn.r-expected.r)+absf(drawn.g-expected.g)+absf(drawn.b-expected.b) < 0.12,
		case_label + " 实绘菱形覆盖弧带中心", {"pixel":str(pixel),"color":str(drawn),"running":gauge.running})

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await _capture(evidence, case_label + "_" + label)

func _click_now(control: Control) -> void:
	# Dispatch both native viewport events at the observed QTE frame, avoiding test
	# helper pre-hover waits that would shift a narrow judgement window.
	var center := control.get_global_rect().get_center()
	get_viewport().warp_mouse(center)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = center
	down.pressed = true
	get_viewport().push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = center
	up.pressed = false
	get_viewport().push_input(up)
	await get_tree().process_frame
