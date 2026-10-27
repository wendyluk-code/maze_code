extends "res://tools/tests/cooking_countdown_input.gd"
## 实际餐厅接单对白、料理台教学和真实输入回归，继承已有隔离夹具。

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation() and DisplayServer.get_name() != "headless", "隔离存档与实际渲染")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			await _task_cutout_case(resolution)
			await _prepare_collected()
			var modal = await _open_cooking()
			_check(modal._gauge.get("_pointer") != null, "批准指针纹理成功加载")
			if modal._gauge.get("_pointer") != null:
				var texture: AtlasTexture = modal._gauge._pointer
				var source := Image.load_from_file("res://assets/ui/cooking/cooking_pointer_v1.png")
				_check(source.get_pixel(0,0).a == 0.0 and source.get_pixel(source.get_width()/2,source.get_height()/2).a > .99,
					"批准素材具有真实透明背景和不透明金色主体", {"used_rect":str(source.get_used_rect()),"atlas_rect":str(texture.region),"factor":modal._gauge._design_scale()})
				_check(texture.region.encloses(Rect2(453,112,348,1012)) and texture.region.size == Vector2(352,1016),
					"主体边界与两尖完整保留，不让透明杂点缩小指针")
			await _capture(evidence, "cooking_left_%dx%d" % [resolution.x,resolution.y])
			await _verify_spotlight(modal)
			for position in [0.0, 1.0]:
				modal._gauge.set_pointer(position)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				await _capture(evidence, "cooking_%s_%dx%d" % ["center" if position == 0.0 else "right", resolution.x,resolution.y])
				await _verify_spotlight(modal)
				var expected: Vector2 = modal._gauge._design_offset() + modal._gauge._arc_centerline((position + 1.0)*.5) * modal._gauge._design_scale()
				_check(modal._gauge.pointer_tip().distance_to(expected) < .001, "指针显示中心与原曲线判定交点一致")
				_check(modal._gauge._pointer_sprite.position.distance_to(modal._gauge.pointer_tip()) < .001,
					"实际金色纹理中心与评分落点一致")
			await _send_key(KEY_E)
			_check(not modal._lesson_blocker.visible and not modal._started, "确认料理说明清除遮罩且不透传开始")
			await _send_key(KEY_ESCAPE)
			_check(not modal.visible and not scene.get_node("Player").input_locked, "取消料理弹窗恢复输入")
		await _cleanup()
	var report := {"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name()}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("TUTORIAL_CUTOUT_POINTER ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _task_cutout_case(resolution: Vector2i) -> void:
	await _cleanup()
	await _prepare_scene()
	await _reach_frontdesk()
	var player = scene.get_node("Player")
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	var tracker = scene.get_node("UIOverlay/OrderTracking")
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	_check(await _wait_until(func(): return tm.current_stage == 3 and tm.steps[tm.idx].type == "interact", 240), "到达前台真实接单步骤")
	await _send_key(KEY_E)
	_check(tm._order_explanation_pending and guide.dialog.visible and tracker._expanded, "真实接单后显示说明和两个子任务")
	await get_tree().create_timer(.35).timeout
	guide.dialog._advance()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _capture(evidence, "tasks_%dx%d" % [resolution.x,resolution.y])
	var shaded := get_viewport().get_texture().get_image()
	guide.dim.hide()
	guide.set_process(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var clear := get_viewport().get_texture().get_image()
	guide.set_process(true)
	guide.dim.show()
	for panel in tracker._subtask_panels:
		var rect: Rect2 = panel.get_global_rect().grow(-5)
		var difference := absf(_brightness(shaded,rect) - _brightness(clear,rect))
		_check(difference < .04, panel.name + "挖空保持原亮度", {"difference":difference,"rect":str(rect)})
	var holes: Array[Rect2] = tracker.explanation_cutout_rects()
	_check(holes.size() == 1 and holes[0] == tracker._panel.get_global_rect(), "单个挖空贴合整个订单列表实际尺寸")
	var main: Rect2 = tracker._order_main.get_global_rect().grow(-5)
	_check(absf(_brightness(shaded,main) - _brightness(clear,main)) < .04, "顶部订单任务也保持原亮度")
	var entry: Rect2 = tracker._task_button.get_global_rect().grow(-5)
	_check(_brightness(shaded,entry) < _brightness(clear,entry) * .85, "当前任务按钮仍被压暗")
	_check(guide.dim.mouse_filter == Control.MOUSE_FILTER_STOP, "透明孔洞沿用原输入阻挡")
	var moved_rect: Rect2 = tracker._subtask_panels[0].get_global_rect()
	tracker._panel.position += Vector2(20,12)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var moved_image := get_viewport().get_texture().get_image()
	var new_rect: Rect2 = tracker._subtask_panels[0].get_global_rect()
	_check(new_rect.position.distance_to(moved_rect.position + Vector2(20,12)) < .01
		and _brightness(moved_image,new_rect.grow(-5)) > 2.3, "子任务位置变化后挖空跟随真实布局")
	await _capture(evidence, "tasks_moved_%dx%d" % [resolution.x,resolution.y])
	await _click_at(tracker._subtask_panels[0].get_global_rect().get_center())
	_check(not tm._order_explanation_pending and not tracker._explanation_highlight and player.input_locked and tm.steps[tm.idx].type == "recipe_unlock", "点击挖空关闭说明并进入食谱解锁", {"pending":tm._order_explanation_pending,"highlight":tracker._explanation_highlight,"locked":player.input_locked,"step":tm.steps[tm.idx],"dialog":guide.dialog.visible})
	_check(not tracker._expanded and not guide.dim.visible, "推进说明收起详情和遮罩")
	_check(tracker.explanation_cutout_rects().is_empty(), "说明结束后不再提供挖空目标")
	await _send_key(KEY_E)
	await get_tree().create_timer(.65).timeout
	_check(not player.input_locked, "关闭食谱解锁后恢复移动")
	# 再次显示同一说明用于取消生命周期验收，不进行第二次经营事务。
	tm._cancel_current_run()
	tm.start([{"stage":3,"type":"dialog","speaker":"芽芽","order_explanation":true,"lines":["订单制作会分成【领取食材】和【制作料理】两部分。"]}])
	await get_tree().process_frame
	_check(not tracker.explanation_cutout_rects().is_empty(), "取消前重新建立说明挖空")
	tm._cancel_current_run()
	await get_tree().process_frame
	_check(tracker.explanation_cutout_rects().is_empty() and not guide.dim.visible and not player.input_locked, "取消教程清除挖空和输入锁")
	await _cleanup()

func _reach_frontdesk() -> void:
	# 教程步骤编号随对白拆分而变化，以正式步骤类型和阶段判定。
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	var deadline := Time.get_ticks_msec() + 6000
	while tm.active and tm.current_stage < 3 and Time.get_ticks_msec() < deadline:
		if guide.dialog.visible:
			await _send_key(KEY_E)
		else:
			await get_tree().process_frame
	_check(tm.active and tm.current_stage == 3, "真实对白进入前台教学")
