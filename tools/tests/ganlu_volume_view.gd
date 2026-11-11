extends "res://tools/tests/restaurant_service_cycle.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_seed_cycle()
		sm.data.erase(Day.KEY)
		var scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.5).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var pour = hud.ganlu.modal
		hud.ganlu.cart()
		await get_tree().create_timer(0.2).timeout
		for level in [0.15,0.55,1.0]:
			pour.view.set_process(false)
			pour.view.amount = level
			pour.view.depths.fill(level*139)
			pour.view.queue_redraw()
			await _shot("water_level_%d" % int(level*100))
		pour.view.reset_motion()
		pour.view.set_process(true)
		pour.close_button.release_focus()
		await _shot("pour_centered")
		var motion := InputEventMouseMotion.new()
		motion.position = pour.close_button.get_global_rect().get_center()
		get_viewport().warp_mouse(motion.position)
		get_viewport().push_input(motion)
		await get_tree().create_timer(0.15).timeout
		await _shot("close_hover")
		_check(absf(pour.view.get_global_rect().get_center().x-pour.panel.get_global_rect().get_center().x)<1,"杯子画布与弹窗中轴一致")
		# 实际鼠标按住并松开，先验证不足水量进入结果而非携带。
		var button_point: Vector2 = pour.hold.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.position = button_point
		down.pressed = true
		get_viewport().push_input(down)
		await get_tree().create_timer(0.18).timeout
		_check(pour.view.amount==0 and pour.view.has_airborne_water(),"首股水尚在空中时杯底不涨水")
		await _shot("before_landing")
		await get_tree().create_timer(0.22).timeout
		var up := down.duplicate()
		up.pressed = false
		get_viewport().push_input(up)
		var frozen: float = pour.amount
		_check(pour.finished and pour.panel.visible and not pour.result_popup.visible,"松手锁定水量并保留倒水画面")
		pour.start_pour()
		pour.dismiss()
		await get_tree().create_timer(0.7).timeout
		_check(is_equal_approx(pour.amount,frozen) and absf(pour.view.tilt)<0.001,"演出不增加水量且茶壶回正")
		_check(pour.view.wall_hits>0,"低水位水流碰壁沿内壁落下")
		_check(is_equal_approx(pour.view.amount,frozen) and not pour.view.has_airborne_water(),"松手后余水全部入杯且总水量守恒")
		await _shot("pot_returned")
		await get_tree().create_timer(1.6).timeout
		_check(pour.finished and pour.result_popup.visible,"真实鼠标松手显示不足结算")
		await _click(pour.result_popup._confirm_button)
		for value in [0.2,1.1]:
			pour.start_pour()
			pour.amount = value
			pour.stop_pour()
			await get_tree().create_timer(1.6).timeout
			_check(pour.result_popup.visible and Drink.snapshot(sm).held.phase=="pouring","不合格仍不能端走")
			_check(not Drink.finish(sm,value).success,"事务拒绝不合格水量")
			await _shot("too_low" if value<0.65 else "too_high")
			await _send_key(KEY_ESCAPE)
			_check(pour.visible and hud._player.input_locked,"Esc不能绕过重新倒水")
			await _click(pour.result_popup._confirm_button)
			_check(pour.visible and not pour.started and Drink.snapshot(sm).held.is_empty(),"重倒清空杯子且不关闭窗口")
		await _key_hold(KEY_SPACE,true)
		var frame_index := 0
		while pour.amount<0.33:
			await _shot("flow_%03d" % frame_index)
			frame_index += 1
			await get_tree().create_timer(0.035).timeout
		_check(pour.view.amount<pour.amount and pour.view.amount>0,"连续倒水时区分杯内与空中水量")
		var offsets: Array = Array(pour.view.surface_offsets)
		var wave_range: float = offsets.max()-offsets.min()
		_check(wave_range>0.1,"落点产生连续水面起伏")
		await _shot("pour_in_motion")
		_check(pour.view.tilt < -0.25 and pour.view.drops.size()>0 and pour.view.ripples.size()>0,"倾壶、重力水滴与落水涟漪运行")
		while pour.amount<0.64:
			await _shot("flow_%03d" % frame_index)
			frame_index += 1
			await get_tree().create_timer(0.035).timeout
		var total_depth := 0.0
		var nonnegative := true
		for depth in pour.view.depths:
			total_depth += depth
			nonnegative = nonnegative and depth>=0
		_check(nonnegative and absf(total_depth/(139*33)-pour.view.amount)<0.0001,"杯内单元流动守恒且无负水深")
		await _key_hold(KEY_SPACE,false)
		for frame in range(38):
			await _shot("transition_%02d" % frame)
			await get_tree().create_timer(0.04).timeout
		await get_tree().create_timer(0.3).timeout
		_check(pour.finished and Drink.pour_factor(pour.amount)>0,"真实空格按住松开得到达标结果")
		await _shot("ready")
		var old_path: String = sm._active_save_path
		sm._active_save_path = ""
		await _click(pour.result_popup._confirm_button)
		_check(pour.visible and not pour.committed and not pour.result_popup._confirm_button.disabled,"端起保存失败保留结果可重试")
		sm._active_save_path = old_path
		await _click(pour.result_popup._confirm_button)
		_check(not pour.visible and not hud._player.input_locked and Drink.snapshot(sm).held.phase=="ready","达标端起恢复操作")
		hud.toast_label.dismiss()
		await get_tree().create_timer(3.0).timeout
		await _shot("carried_new_cup")
		sm.load_data()
		_check(Drink.snapshot(sm).held.phase=="ready","端起后重载保留水杯")
		_check(Drink.slot(sm,0).success,"新杯可以放入冰柜")
		Drink.tick(sm,3.0)
		_check(Drink.slot(sm,0).success,"冰镇达标后取回新杯")
		Day.save_menu(sm,{"salt_grilled_rockmane":10})
		Cycle.begin_day(sm)
		var customer := _arrive()
		_stage(customer.id,"drink",20)
		var served := Drink.deliver(sm,customer.id)
		_check(served.success and Drink.snapshot(sm).held.is_empty(),"新杯冰镇后可交付客人")
		Drink.discard(sm)
		hud.ganlu.cart()
		pour.start_pour()
		scene.queue_free()
		await get_tree().process_frame
		sm.load_data()
		scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.5).timeout
		_check(Drink.snapshot(sm).held.is_empty(),"真实场景重进清除中断倒水")
		scene.queue_free()
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _arrive() -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var result: Dictionary = sm.ensure_restaurant_customer()
	_check(result.get("created",false),"实际生成普通顾客")
	if not result.get("created",false): return {}
	var id: String = result.order.id
	if result.order.phase=="arriving":
		_check(sm.advance_restaurant_customer(id,"arriving","front").success,"当前经营流程顾客到前台")
		_check(sm.accept_restaurant_customer(id).success,"当前经营流程接单入座")
	_check(sm.advance_restaurant_customer(id,"seating","waiting").success,"入座后开始等待")
	return sm.restaurant_customer_order(id)
