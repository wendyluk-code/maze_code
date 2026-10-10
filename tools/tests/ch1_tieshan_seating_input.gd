extends "res://tools/tests/ch1_qte_03_input.gd"
## CH1-TS-02: viewport 键鼠输入与真实餐厅场景渲染。非系统键盘注入。
var _sequence_images: Array[Image] = []
var _sequence_times: Array[int] = []

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	var output_dir := _arg("--output-dir=")
	_check(_verify_isolation(), "隔离 user:// 存档")
	_check(DisplayServer.get_name() != "headless", "实际 GUI 渲染")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			await _run_resolution(resolution, output_dir)
		await _interrupt_at_phase("rising", false)
		await _interrupt_at_phase("fade_out", true)
		await _interrupt_at_phase("fade_in", false)
		await _interrupt_at_phase("sitting", false)
		await _test_early_delivery_cancel()
		await _run_reload_and_cancellation()
		await _test_same_guest_replay()
	var report := {"ticket": "CH1-TS-02", "checks": checks, "failures": failures,
		"results": results, "display": DisplayServer.get_name(),
		"input_source": "viewport InputEventKey/MouseButton",
		"user_dir": ProjectSettings.globalize_path("user://")}
	var report_path := _arg("--report=")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _run_resolution(resolution: Vector2i, output_dir: String) -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register")
	var guest: Node2D = tm.get("_parked_guest")
	var phase_events: Array = []
	var rise_samples: Array = []
	var rise_origin: Vector2 = guest.global_position
	guest.portrait.frame_changed.connect(func():
		if guest.seating_phase == "rising" and guest.portrait.animation == &"rise":
			rise_samples.append({"frame":guest.portrait.frame, "position":guest.global_position,
				"foot_y":guest.portrait.to_global(Vector2(240,448)).y, "shadow_y":guest.ground_shadow.global_position.y}))
	guest.seating_phase_changed.connect(func(phase: String): phase_events.append({"phase":phase,"position":[guest.position.x,guest.position.y],"alpha":guest.portrait.modulate.a,"at_ms":Time.get_ticks_msec()}))
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var guide := scene.get_node("UIOverlay/TutorialGuide")
	var label := "%dx%d" % [resolution.x, resolution.y]
	_check(DisplayServer.window_get_size() == resolution, label + " 实际窗口尺寸")
	var hero_body: Sprite2D = player.get_node("Body")
	var hero_height: float = float(hero_body.texture.get_height()) * hero_body.scale.y
	var collapse_height: float = float(guest.portrait.sprite_frames.get_frame_texture(&"collapse", 0).get_image().get_used_rect().size.y) * guest.portrait.scale.y
	_check(absf(hero_height - 130.0) < 0.1 and absf(collapse_height / hero_height - 1.182) < 0.02,
		label + " 原进场站姿尺寸与锚点保留", {"hero_world_px": hero_height, "collapse_world_px": collapse_height})
	player.global_position = _stand(register)
	_check(await _wait_until(func(): return tm.idx == 9, 240), label + " 前台接单步骤")
	await _send_key(KEY_E)
	_check(sm.current_order().get("status") == "in_progress" and guide.dialog.visible, label + " 首次E仅接单并显示说明")
	_check(is_instance_valid(guest) and not guest.seating_started and guest.seating_phase == "prone", label + " 说明期间保持趴姿")
	await _capture(output_dir, "explanation_" + label)
	await _send_key(KEY_E)
	_check(guide.dialog.visible and not guest.seating_started, label + " 文本未完时E仅补全文字")
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return not guide.dialog.visible and tm.current_stage == 4, 90), label + " 结束说明进入仓库阶段")
	_check(guest.seating_started and guest.seating_phase == "rising", label + " 同步启动起身")
	_check(not tracker.get("_expanded") and not player.input_locked, label + " 任务收起且玩家可移动")
	_check(is_equal_approx(guest.portrait.scale.x, 0.351765) and guest.portrait.position == Vector2(-84.599, -157.591),
		label + " 起身沿用原倒地帧比例与锚点")
	_check(guest.ground_shadow.position == Vector2.ZERO and absf(-157.591 + 447.0 * 0.351765) < 1.0,
		label + " 起身阴影与原帧脚底共用地面基线")
	var before: Dictionary = sm.current_order().duplicate(true)
	await _send_key(KEY_E)
	_check(sm.current_order() == before and guest.seating_started, label + " 重按E不重复接单或演出")
	await _capture(output_dir, "rising_" + label)
	var claimed_early := false
	if resolution.x == 1280:
		player.global_position = _stand(scene.get_node("InteractPoints/Store"))
		_check(await _wait_until(func(): return tm.idx == 11, 240), label + " 起身时玩家并行移动到仓库")
		await _send_key(KEY_E)
		var early_warehouse := scene.get_node("UIOverlay/WarehouseModal")
		_check(early_warehouse.visible, label + " 演出期间E打开仓库")
		await _click(early_warehouse.get("_meat_slot").get("_icon_button"))
		await _click(early_warehouse.get("_salt_slot").get("_icon_button"))
		await _click(early_warehouse.get("_claim_button"))
		claimed_early = true
		_check(not guest.seating_completed and sm.inventory_quantity("rockmane_meat") == 1, label + " 演出未完成时领取材料不阻塞")
	var seen := {}
	var frame := 0
	var snapshots := {}
	_sequence_images.clear()
	_sequence_times.clear()
	var deadline := Time.get_ticks_msec() + 10000
	while is_instance_valid(guest) and not guest.seating_completed and Time.get_ticks_msec() < deadline:
		var phase: String = guest.seating_phase
		if phase == "rising" and guest.portrait.frame == 7 and not snapshots.has("rise_standing"):
			await RenderingServer.frame_post_draw
			snapshots["rise_standing"] = get_viewport().get_texture().get_image()
		if not seen.has(phase) and phase in ["fade_out", "fade_in", "sitting"]:
			seen[phase] = true
			await RenderingServer.frame_post_draw
			snapshots[phase] = get_viewport().get_texture().get_image()
			if phase == "sitting":
				_check(guest.portrait.scale.x >= 0.37, label + " 坐下保留人物体量不缩成小人")
		if resolution.x == 1152:
			await _record_frame(output_dir.path_join("frames_" + label), frame)
		frame += 1
		await get_tree().create_timer(0.025).timeout
	_check(is_instance_valid(guest) and guest.seating_completed and guest.seating_phase == "waiting", label + " 连续演出到达等待坐姿")
	var max_rise_drift := 0.0
	var max_foot_drift := 0.0
	var max_shadow_drift := 0.0
	var rise_frames := {}
	for sample in rise_samples:
		rise_frames[sample.frame] = true
		max_rise_drift = maxf(max_rise_drift, sample.position.distance_to(rise_origin))
		max_foot_drift = maxf(max_foot_drift, absf(sample.foot_y - rise_origin.y))
		max_shadow_drift = maxf(max_shadow_drift, absf(sample.shadow_y - rise_origin.y))
	_check(rise_frames.size() == 8, label + " 采样全部八张起身帧")
	_check(max_rise_drift < 0.001 and max_foot_drift < 0.001 and max_shadow_drift < 0.001,
		label + " 起身全程角色脚底与阴影固定在原地", {"root_drift":max_rise_drift,"foot_drift":max_foot_drift,"shadow_drift":max_shadow_drift})
	_check(guest.position.distance_to(Vector2(471, 271)) < 1.0, label + " 对齐第一椅脚点")
	var phases: Array = phase_events.map(func(event: Dictionary): return event.phase)
	_check(phases == ["rising","fade_out","fade_in","sitting","waiting"],label + " 起身淡出换位淡入落座且无行走阶段",{"phases":phases})
	var fade_in_event: Dictionary = phase_events[2] if phase_events.size() > 2 else {}
	_check(fade_in_event.get("position") == [471.0,271.0] and is_zero_approx(float(fade_in_event.get("alpha",1.0))),label + " 完全透明时切至第一椅位置")
	_check(guest.portrait.flip_h and is_equal_approx(guest.portrait.modulate.a,1.0),label + " 落座保持右向且完全可见")
	var duration: float = float(phase_events[-1].at_ms - phase_events[0].at_ms) / 1000.0
	_check(duration >= 4.4 and duration < 6.5,label + " 演出约五秒完成",{"seconds":duration})
	for key in snapshots:
		snapshots[key].save_png(output_dir.path_join(str(key) + "_" + label + ".png"))
	_save_sequence_frames(output_dir.path_join("frames_" + label))
	await _capture(output_dir, "waiting_" + label)
	var trace_file := FileAccess.open(output_dir.path_join("phase_events_" + label + ".json"),FileAccess.WRITE)
	trace_file.store_string(JSON.stringify(phase_events,"\t"))
	trace_file.close()
	# 玩家在演出期间及之后沿原流程领取；本测试保持镜头拍完连续演出。
	if not claimed_early:
		player.global_position = _stand(scene.get_node("InteractPoints/Store"))
		_check(await _wait_until(func(): return tm.idx == 11, 240), label + " 仓库交互步骤")
		await _send_key(KEY_E)
		var warehouse := scene.get_node("UIOverlay/WarehouseModal")
		_check(warehouse.visible, label + " E可打开仓库")
		await _click(warehouse.get("_meat_slot").get("_icon_button"))
		await _click(warehouse.get("_salt_slot").get("_icon_button"))
		await _click(warehouse.get("_claim_button"))
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, label + " 领取材料正常")
	if resolution.x == 1152:
		await _cook_and_deliver(output_dir, label, guest)
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _cook_and_deliver(output_dir: String, label: String, guest: Node2D) -> void:
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	_check(await _wait_until(func(): return tm.idx == 13, 240), label + " 料理步骤")
	await _send_key(KEY_E)
	var modal := scene.get_node("HUD/CookingModal")
	_check(modal.visible, label + " E打开料理台")
	await _click(modal.get("_start_button"))
	await get_tree().create_timer(0.45).timeout
	await _click(modal.get("_finish_button"))
	_check(await _wait_until(func(): return tm.idx == 14 and not modal.visible, 300), label + " QTE完成")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	_check(await _wait_until(func(): return tm.idx == 15, 240), label + " 交付步骤")
	await _send_key(KEY_E)
	_check(sm.current_order().get("status") == "completed" and sm.reputation() > 0, label + " 真实上菜结算")
	_check(guest.seating_completed and guest.seating_phase == "waiting", label + " 上菜后无幽灵动作")
	await _capture(output_dir, "delivered_" + label)

func _run_reload_and_cancellation() -> void:
	# 合法已接单检查点：新实例直接坐等，取消不保留 Tween。
	sm.data = sm._defaults()
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success, "已接单夹具合法")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame
	await get_tree().process_frame
	var guest: Node2D = tm.get("_parked_guest")
	_check(is_instance_valid(guest) and guest.seating_completed and guest.seating_phase == "waiting" and is_equal_approx(guest.portrait.modulate.a,1.0), "读档直接恢复座位并完全可见，不重播")
	_check(tm.current_stage == 4, "读档恢复仓库阶段")
	tm._cancel_current_run()
	await get_tree().process_frame
	_check(not is_instance_valid(guest), "跳过/取消删除旧客人与 Tween")
	scene.queue_free()
	await get_tree().process_frame

func _interrupt_at_phase(phase: String, leave_scene: bool) -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	await _wait_until(func(): return tm.idx == 9, 240)
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	var guest: Node2D = tm.get("_parked_guest")
	var phase_deadline := Time.get_ticks_msec() + 23000
	while is_instance_valid(guest) and guest.seating_phase != phase and Time.get_ticks_msec() < phase_deadline:
		await get_tree().process_frame
	_check(is_instance_valid(guest) and guest.seating_phase == phase, phase + " 中断前稳定复现",
		{"actual_phase": guest.seating_phase if is_instance_valid(guest) else "destroyed"})
	if leave_scene:
		get_tree().root.remove_child(scene)
		scene.free()
		_check(not tm.active, phase + " 场景离树取消教程")
	else:
		# 第一章已移除跳过入口；直接验证管理器取消时的演出清理契约。
		tm._cancel_current_run()
		_check(not tm.active, phase + " 管理器取消教程")
		scene.queue_free()
	await get_tree().process_frame
	_check(not is_instance_valid(guest), phase + " 旧客人及异步动作销毁")
	sm.load_data()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame
	await get_tree().process_frame
	var restored: Node2D = tm.get("_parked_guest")
	_check(is_instance_valid(restored) and restored.seating_completed and restored.seating_phase == "waiting" and is_equal_approx(restored.portrait.modulate.a,1.0), phase + " 重进直接坐等且无透明残留")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _test_early_delivery_cancel() -> void:
	await _prepare_scene()
	await _reach_frontdesk()
	var player := scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	await _wait_until(func(): return tm.idx == 9, 240)
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	var guest: Node2D = tm.get("_parked_guest")
	_check(guest.seating_phase == "rising", "快速交付取消前仍在起身")
	guest.on_order_served()
	_check(guest.seating_completed and guest.position == Vector2(471, 271), "提前交付即刻取消旧动作并入座")
	await get_tree().create_timer(0.2).timeout
	_check(guest.seating_phase == "waiting" and guest.position == Vector2(471, 271), "取消后的旧协程不会复活")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

func _record_frame(folder: String, number: int) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		_sequence_times.append(Time.get_ticks_msec())
		image.resize(576, 324, Image.INTERPOLATE_LANCZOS)
		_sequence_images.append(image)

func _save_sequence_frames(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for index in range(_sequence_images.size()):
		_sequence_images[index].save_jpg(folder.path_join("%04d.jpg" % index),0.9)
	var times_file := FileAccess.open(folder.path_join("timestamps.json"),FileAccess.WRITE)
	times_file.store_string(JSON.stringify(_sequence_times))
	times_file.close()
	_sequence_images.clear()
	_sequence_times.clear()

func _test_same_guest_replay() -> void:
	var guest := (load("res://scenes/guest_placeholder.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(guest)
	guest.settle_prone()
	guest.play_seating()
	var deadline := Time.get_ticks_msec() + 7000
	while guest.seating_phase != "fade_out" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	_check(guest.seating_phase == "fade_out" and guest.portrait.modulate.a < 0.9, "同实例在渐隐中取消")
	guest.settle_prone()
	_check(guest.portrait.visible and is_equal_approx(guest.portrait.modulate.a,1.0) and is_equal_approx(guest.ground_shadow.modulate.a,1.0) and not guest.portrait.flip_h,
		"取消立即恢复可见趴姿、阴影与原朝向")
	await get_tree().create_timer(0.35).timeout
	_check(guest.seating_phase == "prone" and guest.position == guest.START_POSITION and is_equal_approx(guest.portrait.modulate.a,1.0),"取消后旧渐隐与换位不会继续")
	guest.play_seating()
	deadline = Time.get_ticks_msec() + 7000
	while guest.seating_phase != "fade_in" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(guest.seating_phase == "fade_in" and guest.position == guest.SEAT_GROUND_POSITION and guest.portrait.flip_h,
		"同实例重播可正常进入椅边右向渐显")
	guest.on_order_served()
	_check(guest.seating_phase == "waiting" and is_equal_approx(guest.portrait.modulate.a,1.0),"渐显中提前交付恢复完整可见坐姿")
	await get_tree().create_timer(0.5).timeout
	_check(guest.seating_phase == "waiting" and is_equal_approx(guest.portrait.modulate.a,1.0),"提前交付后旧渐显协程不会复活")
	guest.queue_free()
	await get_tree().process_frame
