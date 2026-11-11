extends "res://tools/tests/restaurant_service_cycle.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _first_order()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _first_order() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://tieshan-bubble-interaction.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success,"首单真实接单")
	_check(sm.claim_first_order_ingredients().success and sm.cook_first_order().success,"真实取料制作")
	_check(sm.save(),"成品阶段保存")
	sm.load_data()
	_check(sm.lifecycle_stage()=="dish_ready","成品阶段读档恢复")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.3).timeout
	tm.start()
	await get_tree().create_timer(0.5).timeout
	var player = get_tree().get_first_node_in_group("player")
	var guest = tm._parked_guest
	_check(is_instance_valid(guest),"读档恢复铁山")
	if not is_instance_valid(guest): return
	var bubble = guest.get_node("OrderBubble")
	var bar = scene.get_node("InteractPoints/BarCounter")
	var ui = scene.get_node("UIOverlay")
	player.position = Vector2(900,700)
	player.last_valid = player.position
	await get_tree().create_timer(0.2).timeout
	_check(bubble.visible and not bubble.selected,"远处仍有料理气泡但无E")
	await _send_key(KEY_E)
	_check(not sm.has_first_order_settlement(),"远处E不能交付")
	player.position = preload("res://scripts/restaurant/three_seat_layout.gd").service_point(0)
	player.last_valid = player.position
	await get_tree().create_timer(0.5).timeout
	_check(player.nearest_interactable()==bar,"靠近铁山原上菜位置选中吧台")
	_check(bubble.selected,"气泡选中显示E")
	_check(not ui._buttons[bar].visible,"不再显示E上菜矩形按钮")
	_check(tm.steps[tm.idx].get("hint")=="靠近铁山，按 E 交单上菜","教学文案同步")
	_check((bubble.get_global_transform_with_canvas()*(Vector2(20,-72)+bubble.body_offset)).y>=7.9,"气泡E不被屏幕上沿裁切")
	await get_tree().create_timer(3.8).timeout
	await _shot("tieshan_selected_E")
	player.input_locked = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not bubble.selected,"输入锁时隐藏E")
	player.input_locked = false
	await get_tree().process_frame
	await _send_key(KEY_E)
	await get_tree().create_timer(0.2).timeout
	_check(sm.has_first_order_settlement(),"真实E沿原首单结算")
	_check(not bubble.visible,"交付成功气泡消失")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame
