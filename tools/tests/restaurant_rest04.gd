extends "res://tools/tests/restaurant_three_seat.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures == 0:
		if _arg("--mode=") == "departure":
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _normal_departure(false)
				await _normal_departure(true)
			await _tieshan_preserved()
		elif _arg("--mode=") == "resume":
			await _resume_rest04()
		else:
			_settlement_transactions()
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _rest04_scene(false)
				await _rest04_scene(true)
			await _tieshan_preserved()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("REST04 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _normal_departure(resume: bool) -> void:
	_seed_cycle()
	var order := _arrive()
	_stage(order.id,"food",100)
	sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1})
	sm.start_cooking("salt_grilled_rockmane")
	sm.finish_first_order_cooking(3)
	_check(sm.deliver_restaurant_customer(order.id).success,"正常料理真实结算后进食")
	sm.data[Day.KEY].arrived = sm.data[Day.KEY].plan.size()
	if resume:
		sm.advance_restaurant_customer(order.id,"eating","farewell")
		sm.advance_restaurant_customer(order.id,"farewell","leaving")
		sm.save()
		sm.load_data()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var player = scene.get_node("Player")
	player.position = Three.service_point(0)
	player.last_valid = player.position
	var camera := get_viewport().get_camera_2d()
	camera.global_position = player.position
	camera.reset_smoothing()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	await _wait_until(func(): return is_instance_valid(hud.customer_flow) and hud.customer_flow.actors.has(order.id),120)
	var flow = hud.customer_flow
	var actor: Sprite2D = flow.actors[order.id]
	var origin := actor.position
	if not resume:
		_check(sm.restaurant_customer_order(order.id).phase=="eating","生产场景从进食开始")
		await _shot("normal_eating")
		await _wait_until(func(): return sm.restaurant_customer_order(order.id).get("phase")=="leaving",240)
	await _wait_until(func(): return is_instance_valid(actor) and actor.modulate.a<0.95,60)
	_check(is_instance_valid(actor) and actor.position.distance_to(origin)<0.1,"站起淡出期间位置不变")
	_check(actor.modulate.a>0 and actor.modulate.a<1,"正常离场真实透明度渐变")
	var atlas: AtlasTexture = actor.texture
	_check(atlas.region.position.y==0 and not actor.flip_h,"吃完切回原站姿帧")
	_check(not sm.restaurant_customers().seated.is_empty() and Day.snapshot(sm).status=="open","淡出完成之前不腾座不提前结算")
	await _shot("normal_standing_fade_resume" if resume else "normal_standing_fade")
	var gold: int = sm.gold_balance()
	if resume:
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		await get_tree().create_timer(0.5).timeout
		_check(not sm.restaurant_customer_order(order.id).is_empty(),"淡出释放保存失败保留持久订单")
		sm._active_save_path = path
	await _wait_until(func(): return sm.restaurant_customer_order(order.id).is_empty(),180)
	await _wait_until(func(): return is_instance_valid(hud.day_settlement) and hud.day_settlement.visible,120)
	_check(not flow.actors.has(order.id) and sm.restaurant_customers().seated.is_empty(),"淡出后移除人物释放座位")
	_check(is_instance_valid(hud.day_settlement) and hud.day_settlement.visible,"最终正常顾客淡出后立即弹结算")
	_check(sm.gold_balance()==gold,"离场及重试不重复发钱")
	await _shot("normal_departed_resume" if resume else "normal_departed")
	scene.queue_free()
	await get_tree().process_frame

func _settlement_transactions() -> void:
	_seed_cycle()
	var order := _arrive()
	_stage(order.id,"food",0.1)
	sm.data[Day.KEY].remaining = 0.1
	_rollback(func(): return Cycle.tick(sm,0.2),"营业到时保存失败完整回滚")
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	_check(Cycle.tick(sm,0.2).success,"营业到时提交结算")
	_check(sm.gold_balance()==gold and sm.reputation()==rep,"营业与耐心同时到零无罚无奖")
	_check(sm.restaurant_customer_order(order.id).outcome=="closed","未完成订单无罚结束")
	var summary: Dictionary = Day.snapshot(sm).settlement.duplicate(true)
	sm.load_data()
	_check(_same_saved(Day.snapshot(sm).settlement,summary),"读档恢复未确认结算",{"before":summary,"after":Day.snapshot(sm).settlement})
	Cycle.tick(sm,100)
	_check(not sm.ensure_restaurant_customer().get("created",false) and sm.gold_balance()==gold,"结算停止来客及所有耐心扣罚")
	_rollback(func(): return Cycle.acknowledge_settlement(sm),"确认保存失败保留可重试结算")
	_check(Cycle.acknowledge_settlement(sm).success,"确认进入下一天准备")
	_check(Day.snapshot(sm).day==2 and sm.restaurant_customers().seated.is_empty(),"确认清除尚未离完旧客")
	_check(not Cycle.acknowledge_settlement(sm).success and sm.gold_balance()==gold,"重复确认不跨天不发钱")
	_check(Cycle.open_with_menu(sm,{"salt_grilled_rockmane":1}).success,"下一天正常开业")
	_seed_cycle()
	order = _arrive()
	sm.data[Day.KEY].erase("start_gold")
	sm.data[Day.KEY].erase("start_serial")
	sm.data.restaurant_order_receipts = {"service_0":{"gold_awarded":999,"outcome":"served"},order.id:{"gold_awarded":12,"reputation_awarded":3,"outcome":"served"}}
	sm.data[Drink.KEY] = {"held":{},"slots":[{},{},{}],"receipts":{order.id:{"gold":7}}}
	Cycle.settle(sm,"time")
	_check(Day.snapshot(sm).settlement.legacy and Day.snapshot(sm).settlement.income==19 and Day.snapshot(sm).settlement.completed==1,"旧档只统计本日服务序号回执，包含水账，不混历史")
	_seed_cycle()
	order = _arrive()
	sm.data[Day.KEY].arrived = sm.data[Day.KEY].plan.size()
	var pending := order.duplicate(true)
	pending.id = "service_11"
	pending.seat = -1
	sm.data.restaurant_customers.serial = 11
	sm.data.restaurant_customers.legacy_waiting = [pending]
	sm.ensure_restaurant_customer()
	_check(Day.snapshot(sm).status=="open" and not sm.restaurant_customers().seated.is_empty(),"菜单用完仍为营业中，旧档待入座不提前结算")
	_seed_cycle()
	order = _arrive()
	_stage(order.id,"food",0.1)
	sm.data.gold = 0
	sm.data.reputation = 0
	sm.data[Day.KEY].start_gold = 0
	sm.data[Day.KEY].start_reputation = 0
	Cycle.tick(sm,0.1)
	Cycle.settle(sm,"time")
	_check(Day.snapshot(sm).settlement.deductions==0 and Day.snapshot(sm).settlement.net==0,"余额零时只统计实际扣款")

func _rest04_scene(timed: bool) -> void:
	_seed_cycle()
	sm.data[Day.KEY].menu = {"salt_grilled_rockmane":1}
	sm.data[Day.KEY].plan = [{"recipe":"salt_grilled_rockmane","drink":false}]
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.25).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.customer_flow
	var player = scene.get_node("Player")
	await _wait_until(func(): return not sm.restaurant_customers().front.is_empty(),120)
	var front: Dictionary = sm.restaurant_customers().front
	var id: String = front.id
	var actor: Sprite2D = flow.actors[id]
	_check(actor.position==preload("res://scripts/restaurant/customer_catalog.gd").COUNTER,"前台原地渐显位置")
	await _shot("arrival_fade_"+str(timed))
	await _wait_until(func(): return sm.restaurant_customer_order(id).get("phase")=="front",120)
	player.position = _stand(scene.get_node("InteractPoints/Register"))
	player.last_valid = player.position
	sm.data.restaurant_customers.front.remaining = 7.0
	await get_tree().create_timer(0.25).timeout
	await _shot("front_warning_"+str(timed))
	await _send_key(KEY_E)
	_check(sm.restaurant_customer_order(id).get("phase")=="seating","实际E接单进入淡出入座")
	_check(not sm.accept_restaurant_customer(id).success,"渐变期间不可重复接单")
	await get_tree().create_timer(0.15).timeout
	_check(float(sm.restaurant_customer_order(id).remaining)==100.0,"入座淡入完成前不扣耐心")
	await _shot("seating_fade_"+str(timed))
	await _wait_until(func(): return sm.restaurant_customer_order(id).get("phase")=="waiting",150)
	player.position = Three.service_point(0)
	player.last_valid = player.position
	_stage(id,"food",15)
	await get_tree().create_timer(0.3).timeout
	_check(flow.selected_id==id,"近距选中顾客头顶E")
	var ui = scene.get_node("UIOverlay")
	_check(not ui._buttons[scene.get_node("InteractPoints/BarCounter")].visible,"吧台无通用上菜矩形按钮")
	var sign = hud.find_child("RestaurantDaySign",true,false)
	_check(sign.status_label.text=="营业中" and not sign.get_node("OpenMenu").visible,"份数分配完仍营业中且禁用菜单")
	hud.show_toast("金币 +12 · 声望 +3")
	await get_tree().process_frame
	_check(hud.toast_label.get_global_rect().position.y>80,"餐厅Toast固定避开营业牌和天数")
	await _shot("food_warning_unique_E_"+str(timed))
	if timed:
		sm.data[Day.KEY].remaining = 0.01
		_stage(id,"food",0.01)
	else:
		_stage(id,"food",100)
		_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).success,"实际仓库取料")
		_check(sm.start_cooking("salt_grilled_rockmane").success and sm.finish_first_order_cooking(3).success,"实际料理事务")
		await _send_key(KEY_E)
		_check(sm.restaurant_customer_order(id).phase=="eating","实际E给选中顾客上菜")
		_check(Day.snapshot(sm).status=="open","仍有进食客不提前结算")
	await _wait_until(func(): return is_instance_valid(hud.day_settlement) and hud.day_settlement.visible,900)
	_check(is_instance_valid(hud.day_settlement) and hud.day_settlement.visible,"实际流程弹出营业结算")
	if not is_instance_valid(hud.day_settlement):
		scene.queue_free()
		await get_tree().process_frame
		return
	_check(player.input_locked and sign.status_label.text=="结算中","结算锁服务输入并明确牌子状态")
	if timed:
		_check(not sm.restaurant_customers().seated.is_empty(),"到时不等待离场立即弹窗")
		var start: Vector2 = actor.position
		await get_tree().create_timer(0.6).timeout
		_check(not is_instance_valid(actor) or actor.position.distance_to(start)>5,"模态期间背景顾客继续离场")
		_check(sm.gold_balance()==100 and sm.reputation()==100,"同帧营业与耐心到零场景无扣罚")
	else:
		_check(sm.restaurant_customers().seated.is_empty(),"菜单用完最后顾客离场即结算")
		_check(Day.snapshot(sm).settlement.completed==1,"实际完成料理计入当日结算")
	await _shot("settlement_"+str(timed))
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	hud.day_settlement.close_modal()
	_check(hud.day_settlement.visible and player.input_locked,"实际弹窗保存失败保留输入锁和重试")
	sm._active_save_path = path
	hud.day_settlement.close_modal()
	await get_tree().process_frame
	_check(not hud.day_settlement.visible and not player.input_locked and Day.snapshot(sm).day==2,"确认成功恢复输入进入第二天")
	_check(Cycle.open_with_menu(sm,{"salt_grilled_rockmane":1}).success,"实际场景确认后立即再开业")
	await get_tree().create_timer(0.6).timeout
	_check(not sm.restaurant_customers().front.is_empty(),"新一天来客不被旧客卡住")
	scene.queue_free()
	await get_tree().process_frame

func _resume_rest04() -> void:
	for phase in ["arriving","seating","closing"]:
		_seed_cycle()
		var order: Dictionary = sm.ensure_restaurant_customer().order
		if phase != "arriving":
			sm.advance_restaurant_customer(order.id,"arriving","front")
			sm.accept_restaurant_customer(order.id)
		if phase == "closing": Cycle.settle(sm,"time")
		sm.save()
		sm.load_data()
		scene = RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(1.2).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var player = scene.get_node("Player")
		if phase == "closing":
			_check(is_instance_valid(hud.day_settlement) and hud.day_settlement.visible and player.input_locked,"读档真实场景自动恢复待确认结算和输入锁")
			await _shot("resume_settlement")
			await _click(hud.day_settlement._confirm_button)
			_check(Day.snapshot(sm).day==2 and not player.input_locked,"读档结算真实点击确认跨天恢复输入")
		else:
			_check(sm.restaurant_customer_order(order.id).get("phase")==("front" if phase=="arriving" else "waiting"),phase+"读档完成渐显而非丢失顾客")
			_check(sm.restaurant_customer_order(order.id).remaining>38 if phase=="arriving" else sm.restaurant_customer_order(order.id).remaining>98,phase+"读档渐变不提前消耗耐心")
			player.position = Three.service_point(2)
			player.last_valid = player.position
			await get_tree().create_timer(0.2).timeout
			_check(hud.customer_flow.selected_id.is_empty(),"无顾客服务目标")
			_check(not scene.get_node("UIOverlay")._buttons[scene.get_node("InteractPoints/BarCounter")].visible,"无目标也没有通用上菜按钮")
		scene.queue_free()
		await get_tree().process_frame
