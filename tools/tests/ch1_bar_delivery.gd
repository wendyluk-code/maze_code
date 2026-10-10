extends "res://tools/tests/ch1_qte_03_input.gd"
## 吧台交付聚焦验收：合法业务夹具准备成品，实际场景输入完成交付。

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	if not _verify_isolation():
		get_tree().quit(2)
		return
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		for quality in [1,2,3]:
			await _delivery_case(resolution,quality)
	var report := {"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name(),"resolutions":observed_resolutions}
	FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	get_tree().quit(0 if failures == 0 else 1)

func _delivery_case(resolution: Vector2i, quality: int) -> void:
	DisplayServer.window_set_size(resolution)
	await get_tree().process_frame
	var label := "%dx%d_%d星" % [resolution.x,resolution.y,quality]
	observed_resolutions.append(str(DisplayServer.window_get_size()))
	_check(DisplayServer.window_get_size() == resolution,label + " 实际窗口尺寸")
	sm.data = sm._defaults()
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.start_first_order_cooking().success and sm.finish_first_order_cooking(quality).success,label + " 合法成品夹具")
	await _mount_delivery_scene()
	var player := scene.get_node("Player")
	var bar := scene.get_node("InteractPoints/BarCounter")
	var register := scene.get_node("InteractPoints/Register")
	_check(tm.current_stage == 6 and tm.resolve_target(str(tm.steps[tm.idx].get("target",""))) == bar,label + " 读档交付目标为吧台")
	player.global_position = _stand(bar)
	player.last_valid = player.global_position
	_check(await _wait_until(func(): return tm.idx == 15,240),label + " 走至吧台进入交单步骤")
	var bar_stand: Vector2 = player.global_position
	var before: Dictionary = sm.data.duplicate(true)
	var disk := FileAccess.get_file_as_string(sm.SAVE_PATH)
	player.global_position = _frontdesk_stand(register,bar)
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	player.interacted.emit(register)
	_check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk and tm.idx == 15,label + " 前台E及前台信号均不能交单")
	var front_button: Control = scene.get_node("UIOverlay").get("_buttons")[register]
	_check(not front_button.visible or front_button.get_node("Content/ActionLabel").text != "交单上菜",label + " 前台不会显示交单上菜")
	player.global_position = Vector2(-10000,-10000)
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	player.interacted.emit(bar)
	_check(sm.data == before and FileAccess.get_file_as_string(sm.SAVE_PATH) == disk and tm.idx == 15,label + " 远离吧台E和伪造吧台信号均不交单")
	player.global_position = bar_stand
	player.last_valid = bar_stand
	player.interacted.emit(register)
	player.interacted.emit(scene.get_node("InteractPoints/Store"))
	_check(sm.data == before and tm.idx == 15,label + " 吧台站位错目标信号不交单")
	await get_tree().create_timer(0.25).timeout
	var button: Control = scene.get_node("UIOverlay").get("_buttons")[bar]
	var register_button: Control = scene.get_node("UIOverlay").get("_buttons")[register]
	_check(button.visible and button.get_node("Content/ActionLabel").text == "交单上菜" and not register_button.visible and player.nearest_interactable() == bar,label + " 吧台显示E交单上菜且选择器一致",{"position":str(bar_stand),"distance":player.interaction_distance_to(bar)})
	await RenderingServer.frame_post_draw
	await _capture(_arg("--output-dir="),label + "_吧台交单按钮")
	await _send_key(KEY_E)
	var reward: int = {1:10,2:12,3:15}[quality]
	_check(sm.has_first_order_settlement() and sm.reputation() == reward and sm.current_order().status == "completed" and tm.current_stage == 7,label + " 吧台E结算并推进阶段7")
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 0 and int(sm.prepared_dishes_snapshot()[sm.FIRST_ORDER_ITEM_ID][str(quality)]) == 0,label + " 仅扣对应品质成品一份")
	_check(_feedback_contains(scene.get_node("UIOverlay/TutorialGuide"),quality),label + " 品质顾客评价保持正确")
	await RenderingServer.frame_post_draw
	await _capture(_arg("--output-dir="),label + "_交单完成")
	var settlement: Dictionary = sm.data.first_order_settlement.duplicate(true)
	var inventory: Dictionary = sm.inventory_snapshot()
	for i in 3:
		await _send_key(KEY_E)
		player.interacted.emit(bar)
	_check(sm.reputation() == reward and sm.data.first_order_settlement == settlement and sm.inventory_snapshot() == inventory,label + " 重复E信号不重复结算")
	await _unmount_delivery_scene()
	sm.load_data()
	await _mount_delivery_scene()
	_check(sm.reputation() == reward and sm.data.first_order_settlement == JSON.parse_string(JSON.stringify(settlement)) and sm.inventory_snapshot() == inventory and tm.current_stage == 7,label + " 重新读盘进场保持完成奖励且阶段7",{"stage":tm.current_stage,"idx":tm.idx,"reward":sm.reputation(),"inventory":sm.inventory_snapshot(),"expected_inventory":inventory,"settlement":sm.data.first_order_settlement,"expected_settlement":settlement})
	_check(tm.get("_parked_guest").seating_completed,label + " 重进铁山仍在吧台等候")
	await _unmount_delivery_scene()

func _frontdesk_stand(register: Node2D,bar: Node2D) -> Vector2:
	var player := scene.get_node("Player")
	for y in range(-200,241,10):
		for x in range(-200,241,10):
			var point := register.global_position + Vector2(x,y)
			if not player.is_walkable_footprint(point): continue
			player.global_position = point
			if player.interaction_distance_to(register) <= 90.0 and player.interaction_distance_to(bar) > 120.0: return point
	_check(false,"找到前台独立合法站位")
	return register.global_position

func _mount_delivery_scene() -> void:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame
	await get_tree().process_frame

func _unmount_delivery_scene() -> void:
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame
