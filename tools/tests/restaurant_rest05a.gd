extends "res://tools/tests/restaurant_rest04.gd"
const Lesson := preload("res://scripts/ui/components/restaurant_arrival_lesson.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		await _common_dialog_mouse()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _first_customer()
			for phase in ["front","clock","return"]: await _resume_lesson(phase)
			await _old_save_and_freezer()
		await _entry_save_failure()
		await _tieshan_preserved()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _open_restaurant() -> Node:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	return get_tree().get_first_node_in_group("restaurant_hud")

func _close_restaurant() -> void:
	scene.queue_free()
	await get_tree().process_frame

func _clock_snapshot() -> Array:
	var day := Day.snapshot(sm)
	return [day.remaining,day.arrival_left,sm.restaurant_customers().front.get("remaining"),day.arrived]

func _finish_dialog(lesson: Node) -> void:
	if lesson.dialog._shown<str(lesson.dialog._lines[0]).length(): await _click_dialog()
	await _click_dialog()

func _click_dialog() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(570,580)
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _common_dialog_mouse() -> void:
	var box = preload("res://scenes/ui/dialog_box.tscn").instantiate()
	add_child(box)
	box.start("芽芽",["鼠标补全这句对白。","第二句对白。"],preload("res://assets/characters/yaya_portrait.png"))
	await _click_dialog()
	_check(box._line_idx==0 and box.dialog_text.text=="鼠标补全这句对白。","通用对白左键仅补全当前句")
	await _click_dialog()
	_check(box._line_idx==1 and box.visible,"通用对白一次左键仅推进一句")
	await _send_key(KEY_E)
	_check(box._line_idx==1 and box.dialog_text.text=="第二句对白。","通用对白E与左键补全一致")
	await _click_dialog()
	_check(not box.visible,"通用对白左键完成并关闭")
	box.queue_free()
	await get_tree().process_frame

func _first_customer() -> void:
	_seed_cycle()
	sm.data.erase(Lesson.KEY)
	var hud = await _open_restaurant()
	var flow = hud.customer_flow
	await _wait_until(func(): return flow._arrival_tutorial_busy,180)
	_check(flow._arrival_tutorial_busy,"第一天首客渐显完成自动进入教学")
	if not flow._arrival_tutorial_busy:
		await _close_restaurant()
		return
	var lesson = flow.arrival_lesson
	var front: Dictionary = sm.restaurant_customers().front
	var actor: Sprite2D = flow.actors[front.id]
	_check(actor.modulate.a==1 and front.phase=="front","教学发生在前台渐显完成后")
	_check(hud._player.input_locked and not hud._player.is_physics_processing(),"镜头期间锁操作")
	var clocks := _clock_snapshot()
	var camera := get_viewport().get_camera_2d()
	var start: Vector2 = lesson.camera_before.position
	await get_tree().create_timer(0.25).timeout
	_check(lesson.moving and camera.global_position.distance_to(start)>1 and camera.global_position.distance_to(actor.global_position+Vector2(0,60))>1,"镜头到前台有中间位置")
	await _shot("rest05a_camera_out")
	await _wait_until(func(): return lesson.dialog.visible,90)
	_check(lesson.dialog._lines==[Lesson.FRONT_LINE],"第一句严格使用确认原文")
	await _click_dialog()
	_check(lesson.phase=="front" and lesson.dialog.dialog_text.text==Lesson.FRONT_LINE,"左键一次补全文字且松开不跳句")
	hud.toast_label.show_message("遮挡回归测试",10)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not hud.toast_label.visible,"教学期间撤下HUD悬浮提示")
	var front_cutout: Vector4 = lesson.dim.material.get_shader_parameter("ingredients_rect")
	var front_rect := Rect2(front_cutout.x,front_cutout.y,front_cutout.z,front_cutout.w)
	_check(front_rect.size.x>20 and front_rect.size.y>20 and front_rect.has_point(actor.get_global_transform_with_canvas()*lesson.customer_rect.get_center()),"第一句蒙层挖空真实顾客屏幕位置")
	await get_tree().create_timer(0.9).timeout
	await _shot("rest05a_front_line")
	_check(_clock_snapshot()==clocks,"阅读及镜头期间营业耐心来客计时全部暂停")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _finish_dialog(lesson)
	_check(lesson.retry.is_valid() and sm.data[Lesson.KEY].phase=="front" and hud._player.input_locked,"第一句保存失败不推进且保持锁")
	sm._active_save_path = path
	await _click_dialog()
	_check(lesson.phase=="clock" and lesson.dialog._lines==[Lesson.CLOCK_LINE],"左键重试保存后展示第二句原文")
	await get_tree().process_frame
	var cutout: Vector4 = lesson.dim.material.get_shader_parameter("ingredients_rect")
	var target: Rect2 = hud.find_child("RestaurantDaySign",true,false).details_label.get_global_rect().grow(5)
	_check(Rect2(cutout.x,cutout.y,cutout.z,cutout.w)==target,"第二句蒙层准确镂空营业倒计时")
	await _send_key(KEY_E)
	await _shot("rest05a_clock_cutout")
	await _send_key(KEY_E)
	_check(sm.data[Lesson.KEY].phase=="return" and lesson.moving,"第二次确认持久化回程阶段")
	var away: Vector2 = camera.global_position
	await get_tree().create_timer(0.25).timeout
	_check(camera.global_position.distance_to(start)>1 and camera.global_position.distance_to(away)>1,"返回主角镜头有中间位置")
	sm._active_save_path = ""
	await _wait_until(func(): return lesson.retry.is_valid(),90)
	_check(flow._arrival_tutorial_busy and hud._player.input_locked and sm.data[Lesson.KEY].phase=="return","完成标记保存失败不提前释放")
	_check(_clock_snapshot()==clocks,"保存失败等待重试仍暂停全部计时")
	sm._active_save_path = path
	await _send_key(KEY_E)
	_check(sm.data[Lesson.KEY].phase=="done" and not flow._arrival_tutorial_busy and not hud._player.input_locked,"成功只一次并恢复输入")
	await get_tree().create_timer(0.45).timeout
	_check(float(Day.snapshot(sm).remaining)<float(clocks[0]) and float(sm.restaurant_customers().front.remaining)<float(clocks[2]),"完成后营业和耐心恢复计时")
	await _bubble_edges(flow,actor)
	sm.save()
	await _close_restaurant()
	sm.load_data()
	hud = await _open_restaurant()
	await get_tree().create_timer(0.9).timeout
	_check(not hud.customer_flow._arrival_tutorial_busy and sm.data[Lesson.KEY].phase=="done","完成后退出读档不重播")
	await _close_restaurant()

func _bubble_edges(flow: Node, actor: Sprite2D) -> void:
	var camera := get_viewport().get_camera_2d()
	var original := camera.global_position
	camera.set_process(false)
	var limits := [camera.limit_left,camera.limit_right,camera.limit_top,camera.limit_bottom]
	camera.limit_left = -10000
	camera.limit_right = 10000
	camera.limit_top = -10000
	camera.limit_bottom = 10000
	var bubble = actor.get_node("OrderBubble")
	for point in [actor.global_position,actor.global_position+Vector2(0,2000),actor.global_position,actor.global_position+Vector2(2000,0),actor.global_position]:
		camera.global_position = point
		camera.reset_smoothing()
		await get_tree().create_timer(0.08).timeout
		var on_screen: bool = point==actor.global_position
		_check(bubble.visible==on_screen,"人物屏外隐藏且重新入屏恢复气泡")
		_check(bubble.position.is_equal_approx(preload("res://scripts/ui/components/customer_head_anchor.gd").local_point(actor)),"气泡跟随真实头顶锚点")
		if on_screen: await _shot("rest05a_bubble_head")
		else: await _shot("rest05a_bubble_offscreen")
	camera.limit_left = limits[0]
	camera.limit_right = limits[1]
	camera.limit_top = limits[2]
	camera.limit_bottom = limits[3]
	camera.global_position = original
	camera.set_process(true)

func _resume_lesson(phase: String) -> void:
	_seed_cycle()
	var result: Dictionary = sm.ensure_restaurant_customer()
	sm.advance_restaurant_customer(result.order.id,"arriving","front")
	sm.data[Lesson.KEY] = {"phase":phase,"order_id":result.order.id}
	sm.save()
	sm.load_data()
	var hud = await _open_restaurant()
	await _wait_until(func(): return hud.customer_flow._arrival_tutorial_busy,90)
	var lesson = hud.customer_flow.arrival_lesson
	_check(is_instance_valid(lesson),"读档恢复教学阶段 "+phase)
	if not is_instance_valid(lesson):
		await _close_restaurant()
		return
	await get_tree().create_timer(0.8).timeout
	if phase=="return": _check(sm.data[Lesson.KEY].phase=="done" and not hud._player.input_locked,"回程读档完成恢复")
	else:
		_check(lesson.phase==phase and lesson.dialog.visible,"读档仅恢复未读阶段 "+phase)
		await _shot("rest05a_resume_"+phase)
	await _close_restaurant()

func _old_save_and_freezer() -> void:
	_seed_cycle()
	sm.data.erase(Lesson.KEY)
	sm.data[Day.KEY].day = 2
	sm.data.freezer_unlock_notice_seen = false
	var hud = await _open_restaurant()
	await get_tree().create_timer(1.3).timeout
	_check(not hud.customer_flow._arrival_tutorial_busy and not hud.exploration_guide.reading,"旧档第二天不补播首客或冰柜对白")
	_check(sm.freezer_unlocked() and not sm.freezer_notice_pending(),"冰柜解锁保留且旧待读静默清理")
	hud._player.position = _stand(scene.get_node("InteractPoints/Fridge"))
	hud._player.last_valid = hud._player.position
	_check(Drink.begin(sm).success and Drink.finish(sm,0.8).success,"冰柜入口准备真实甘露水")
	await _send_key(KEY_E)
	_check(Drink.snapshot(sm).held.is_empty() and Drink.snapshot(sm).slots.any(func(c): return not c.is_empty()),"删除对白后实际E仍可将甘露水放入冰柜")
	await _close_restaurant()

func _entry_save_failure() -> void:
	_seed_cycle()
	sm.data.erase(Lesson.KEY)
	var order: Dictionary = sm.ensure_restaurant_customer().order
	sm.advance_restaurant_customer(order.id,"arriving","front")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	var hud = await _open_restaurant()
	await _wait_until(func(): return hud.customer_flow._arrival_tutorial_busy,90)
	var lesson = hud.customer_flow.arrival_lesson
	_check(is_instance_valid(lesson) and lesson.retry.is_valid() and not sm.data.has(Lesson.KEY),"教学首次保存失败保留可重试且无假检查点")
	var clocks := _clock_snapshot()
	await get_tree().create_timer(0.3).timeout
	_check(_clock_snapshot()==clocks and hud._player.input_locked,"教学首次保存失败也暂停并锁输入")
	sm._active_save_path = path
	await _send_key(KEY_E)
	await get_tree().create_timer(0.8).timeout
	_check(lesson.phase=="front" and lesson.dialog.visible,"首次保存失败按E恢复第一句")
	await _close_restaurant()
	# 已经接过首单的旧档，不因为缺少新标记而重播。
	_seed_cycle()
	sm.data.erase(Lesson.KEY)
	order = sm.ensure_restaurant_customer().order
	sm.advance_restaurant_customer(order.id,"arriving","front")
	sm.data[Day.KEY].arrived = 2
	hud = await _open_restaurant()
	await get_tree().create_timer(0.9).timeout
	_check(not hud.customer_flow._arrival_tutorial_busy,"第一天非首位顾客旧档不补播")
	await _close_restaurant()
