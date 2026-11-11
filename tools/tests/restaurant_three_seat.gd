extends "res://tools/tests/restaurant_service_cycle.gd"
const Three := preload("res://scripts/restaurant/three_seat_layout.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures == 0:
		if _arg("--mode=")=="service":
			await _full_service()
		elif _arg("--mode=")=="clock":
			await _clock_three()
		elif _arg("--mode=")=="migration":
			_migration()
		elif _arg("--mode=")=="feedback":
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _feedback_paths()
		else:
			_transactions()
			_migration()
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _front_and_seats()
				await _feedback_paths()
			await _tieshan_preserved()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("REST3 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _arrive() -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var result: Dictionary = sm.ensure_restaurant_customer()
	_check(result.get("created",false),"顾客先生成在前台入口")
	if not result.get("created",false): return {}
	var id: String = result.order.id
	_check(sm.advance_restaurant_customer(id,"arriving","front").success,"走到前台才开始候客")
	_check(sm.accept_restaurant_customer(id).success,"明确接单才入座")
	_check(sm.advance_restaurant_customer(id,"seating","waiting").success,"坐稳才开始水或料理倒计时")
	return sm.restaurant_customer_order(id)

func _rollback(action: Callable, label: String) -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	var result: Dictionary = action.call()
	_check(not result.success and sm.data == before,label)
	sm._active_save_path = path

func _transactions() -> void:
	_seed_cycle()
	var cooldown: Dictionary = sm.ensure_restaurant_customer().order
	sm.advance_restaurant_customer(cooldown.id,"arriving","front")
	sm.accept_restaurant_customer(cooldown.id)
	Cycle.tick(sm,11)
	_check(not sm.ensure_restaurant_customer().get("created",false),"来客间隔11秒不刷新")
	Cycle.tick(sm,1)
	_check(sm.ensure_restaurant_customer().get("created",false),"来客间隔12秒开放下一位")
	_seed_cycle()
	_check(Cycle.FRONT_SECONDS==40 and Cycle.DRINK_SECONDS==40 and Cycle.FOOD_SECONDS==100 and Cycle.ARRIVAL_SECONDS==12,"确认四个计时常数")
	_check(Day.snapshot(sm).plan.filter(func(p): return p.drink).size()==3,"十份计划恰好三位先点水")
	_rollback(func(): return sm.ensure_restaurant_customer(),"来客保存失败完整回滚")
	var first: Dictionary = sm.ensure_restaurant_customer().order
	_check(first.phase=="arriving" and first.seat==-1 and sm.restaurant_customers().seated.is_empty(),"不会自动入座")
	Cycle.tick(sm,10)
	_check(sm.restaurant_customer_order(first.id).remaining==40,"前往点餐处行走不扣耐心")
	_check(not sm.accept_restaurant_customer(first.id).success,"尚未到前台不能接单")
	sm.advance_restaurant_customer(first.id,"arriving","front")
	_check(not sm.ensure_restaurant_customer().get("created",false),"前台最多一人")
	_rollback(func(): return sm.accept_restaurant_customer(first.id),"接单保存失败保留前台客")
	Cycle.tick(sm,39)
	_check(sm.restaurant_customer_order(first.id).phase=="front" and sm.restaurant_customer_order(first.id).remaining==1,"候客39秒仍可接单")
	_rollback(func(): return Cycle.tick(sm,1),"候客超时保存失败不扣罚")
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	Cycle.tick(sm,1)
	_check(sm.restaurant_customer_order(first.id).outcome=="front_timeout" and sm.gold_balance()==gold-1 and sm.reputation()==rep-1,"候客40秒扣1金币1声望")
	sm.load_data()
	Cycle.tick(sm,2)
	_check(sm.gold_balance()==gold-1 and sm.reputation()==rep-1,"候客失败读档不重复扣罚")
	_rollback(func(): return sm.advance_restaurant_customer(first.id,"leaving","departed"),"离场保存失败保留人物检查点")
	sm.advance_restaurant_customer(first.id,"leaving","departed")
	for stage in ["drink","food"]:
		var order := _arrive()
		_stage(order.id,stage,40 if stage=="drink" else 100)
		var total: float = sm.restaurant_customer_order(order.id).remaining
		Cycle.tick(sm,total-1)
		_check(sm.restaurant_customer_order(order.id).remaining==1 and sm.restaurant_customer_order(order.id).phase=="waiting",stage+"只在完整耐心耗尽后超时")
		gold = sm.gold_balance()
		rep = sm.reputation()
		_rollback(func(): return Cycle.tick(sm,1),stage+"超时保存失败全量回滚")
		Cycle.tick(sm,1)
		_check(sm.restaurant_customer_order(order.id).phase=="leaving" and sm.gold_balance()==gold-2 and sm.reputation()==rep-1,stage+"超时扣2金币1声望并离开")
		sm.load_data()
		Cycle.tick(sm,2)
		_check(sm.gold_balance()==gold-2 and sm.reputation()==rep-1,stage+"离场读档不重复扣罚")
		sm.advance_restaurant_customer(order.id,"leaving","departed")
	_seed_cycle()
	first = sm.ensure_restaurant_customer().order
	sm.advance_restaurant_customer(first.id,"arriving","front")
	sm.accept_restaurant_customer(first.id)
	var remaining: float = sm.restaurant_customer_order(first.id).remaining
	Cycle.tick(sm,15)
	_check(sm.restaurant_customer_order(first.id).remaining==remaining,"去座位行走不扣耐心")
	sm.advance_restaurant_customer(first.id,"seating","waiting")
	for i in 2: _arrive()
	sm.data[Day.KEY].arrival_left = 0
	_check(sm.restaurant_customers().seated.size()==3 and not sm.ensure_restaurant_customer().get("created",false),"满三座无新增来客")
	_stage(first.id,"food",0.1)
	Cycle.tick(sm,0.1)
	_check(not sm.ensure_restaurant_customer().get("created",false),"离场完成前仍占座")
	sm.advance_restaurant_customer(first.id,"leaving","departed")
	_check(sm.ensure_restaurant_customer().get("created",false),"离场完成释放座位可来客")
	_seed_cycle()
	first = sm.ensure_restaurant_customer().order
	sm.advance_restaurant_customer(first.id,"arriving","front")
	sm.data[Day.KEY].remaining = 0.1
	sm.data.restaurant_customers.front.remaining = 0.1
	gold = sm.gold_balance()
	rep = sm.reputation()
	Cycle.tick(sm,0.1)
	_check(Day.snapshot(sm).status=="closing" and sm.restaurant_customer_order(first.id).outcome=="closed" and sm.gold_balance()==gold and sm.reputation()==rep,"营业结束优先无罚送走未接单客")
	_check(Day.snapshot(sm).has("settlement"),"到时不等顾客走出门立即结算")
	sm.advance_restaurant_customer(first.id,"leaving","departed")
	_check(Cycle.acknowledge_settlement(sm).success,"确认结算后进入次日")
	_check(not Cycle.acknowledge_settlement(sm).success and Day.snapshot(sm).day==2,"次日不重复结算")
	_seed_cycle()
	var seated := _arrive()
	_stage(seated.id,"food",100)
	sm.data[Day.KEY].remaining = 0.1
	Cycle.tick(sm,0.1)
	_check(Day.snapshot(sm).status=="closing" and sm.restaurant_customer_order(seated.id).phase=="leaving" and not sm.ensure_restaurant_customer().get("created",false),"营业结束已接单顾客无罚离场并停止新客")
	for stage in ["front","drink","food"]:
		var bubble := preload("res://scripts/ui/components/service_order_bubble.gd").new()
		var total := 100.0 if stage=="food" else 40.0
		bubble.setup_order({"stage":stage,"remaining":total*0.2+0.01,"item_id":"salt_grilled_rockmane"})
		_check(not bubble.warning,stage+"最后20%之前不预警")
		bubble.setup_order({"stage":stage,"remaining":total*0.2,"item_id":"salt_grilled_rockmane"})
		_check(bubble.warning,stage+"最后20%边界预警")
		bubble.free()
	_water_and_food()

func _water_and_food() -> void:
	for cold in [0.0,2.99,3.0,8.0,8.001]:
		_check(Drink.grade({"cold":cold,"chill_revision":3})==(4 if cold>8 else 1 if cold>=3 else 0),"保留新版冰度边界"+str(cold))
	for kind in ["good","amount","ice","spoiled","unrequested"]:
		_seed_cycle()
		var order := _arrive()
		_stage(order.id,"food" if kind=="unrequested" else "drink",23)
		sm.data.restaurant_customers.seated[0].drink_ice = 0
		_make_cup(0.76 if kind=="amount" else 0.65)
		if kind in ["ice","spoiled"]: sm.data[Drink.KEY].held.cold = 3.0 if kind=="ice" else 8.001
		var gold: int = sm.gold_balance()
		var rep: int = sm.reputation()
		_rollback(func(): return Drink.deliver(sm,order.id),kind+"送水失败回滚水杯与金币")
		var result := Drink.deliver(sm,order.id)
		var expected := 7 if kind=="good" else 0 if kind=="unrequested" else -1
		_check(result.success and sm.gold_balance()==gold+expected and sm.reputation()==rep and Drink.snapshot(sm).held.is_empty(),kind+"送水消耗杯子且奖罚正确")
		_check(sm.restaurant_customer_order(order.id).stage=="food" and sm.restaurant_customer_order(order.id).remaining==(23 if kind=="unrequested" else 100),kind+"料理计时契约")
		sm.load_data()
		_check(not Drink.deliver(sm,order.id).success and sm.gold_balance()==gold+expected,kind+"读档重复交付不重扣重奖")
	_seed_cycle()
	var order := _arrive()
	_stage(order.id,"food",100)
	_food()
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	_rollback(func(): return sm.deliver_restaurant_customer(order.id),"错误料理保存失败不耗料理不扣金币")
	var wrong: Dictionary = sm.deliver_restaurant_customer(order.id)
	_check(wrong.success and wrong.outcome=="wrong_dish" and sm.gold_balance()==gold-2 and sm.reputation()==rep and sm.inventory_quantity("slime_candy")==0,"错误料理消耗并扣2金币不扣声望")
	sm.load_data()
	_check(not sm.deliver_restaurant_customer(order.id).success and sm.gold_balance()==gold-2,"错误料理读档不重复结算")
	sm.advance_restaurant_customer(order.id,"leaving","departed")
	order = _arrive()
	_stage(order.id,"food",0.1)
	sm.data.gold = 0
	sm.data.reputation = 0
	Cycle.tick(sm,0.1)
	_check(sm.gold_balance()==0 and sm.reputation()==0,"金币声望最低零")

func _front_and_seats() -> void:
	_seed_cycle()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	await get_tree().create_timer(0.6).timeout
	var flow = hud.customer_flow
	var player = scene.get_node("Player")
	_check(not scene.get_node("SixSeatBarArt").visible and scene.get_node("SeatAnchors").get_child_count()==3,"实际地图恢复原三座底图")
	_check(scene.get_node("InteractPoints/Register").is_in_group("interactable"),"独立前台保留交互组")
	for i in 3:
		if i>0: sm.data[Day.KEY].arrival_left = 0.0
		await _wait_until(func(): return sm.restaurant_customers().front.get("phase")=="front",240)
		var front: Dictionary = sm.restaurant_customers().front
		_check(front.get("phase")=="front","真实行走到前台")
		if front.is_empty(): break
		flow.take_order()
		_check(not sm.restaurant_customers().front.is_empty(),"远离前台不能接单")
		player.position = _stand(scene.get_node("InteractPoints/Register"))
		player.last_valid = player.position
		await get_tree().create_timer(0.3).timeout
		await _shot("front_before_accept_"+str(i))
		await _send_key(KEY_E)
		_check(sm.restaurant_customers().front.is_empty() and sm.restaurant_customer_order(front.id).get("phase")=="seating","真实E前台接单开始走向座位")
		await _wait_until(func(): return sm.restaurant_customer_order(front.id).get("phase")=="waiting",480)
		_check(sm.restaurant_customer_order(front.id).get("phase")=="waiting","真实路径移动后坐稳")
		player.position = Vector2(1000,850)
		player.last_valid = player.position
	_check(sm.restaurant_customers().seated.size()==3,"实际场景三座均占用")
	for i in 3:
		player.position = Three.service_point(i)
		player.last_valid = player.position
		await get_tree().create_timer(0.3).timeout
		_check(player.is_walkable_footprint(player.position),"第%d座上菜站位可走"%i)
		_check(flow.selected_id=="service_%d"%(i+1),"按距离选中第%d座"%i,{"position":str(player.position),"selected":flow.selected_id,"target":str(player.nearest_interactable()),"bar_polygon":str(scene.get_node("InteractPoints/BarCounter").interaction_polygon),"bar_distance":player.interaction_distance_to(scene.get_node("InteractPoints/BarCounter"))})
	await _shot("three_seats")
	scene.queue_free()
	await get_tree().process_frame

func _feedback_paths() -> void:
	for kind in ["front_timeout","drink_timeout","timeout","wrong_dish","bad_drink","question"]:
		_seed_cycle()
		var order: Dictionary
		if kind=="front_timeout":
			order = sm.ensure_restaurant_customer().order
			sm.advance_restaurant_customer(order.id,"arriving","front")
			sm.data.restaurant_customers.front.remaining = 7.0
		else:
			order = _arrive()
			_stage(order.id,"drink" if kind in ["drink_timeout","bad_drink"] else "food",7)
			sm.data.restaurant_customers.seated[0].drink_ice = 0
		scene = RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.5).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var flow = hud.customer_flow
		var player = scene.get_node("Player")
		player.position = _stand(scene.get_node("InteractPoints/Register")) if kind=="front_timeout" else Three.service_point(0)
		player.last_valid = player.position
		await get_tree().create_timer(0.3).timeout
		flow.set_process(false)
		var actor: Sprite2D = flow.actors[order.id]
		_check(actor.get_node("OrderBubble").warning,"最后20%才有气泡预警："+kind)
		await _shot(kind+"_warning")
		var start := actor.position
		if kind in ["front_timeout","drink_timeout","timeout"]: Cycle.tick(sm,7)
		elif kind=="wrong_dish":
			_food()
			await _send_key(KEY_E)
		else:
			_make_cup(0.76 if kind=="bad_drink" else 0.65)
			await _send_key(KEY_E)
		flow._sync()
		await get_tree().create_timer(0.3).timeout
		_check(actor.get_node_or_null("CustomerFeedback")!=null,"真实事件显示表情文字："+kind)
		var feedback = actor.get_node_or_null("CustomerFeedback")
		if feedback != null:
			var transform: Transform2D = feedback.text_bubble.get_global_transform_with_canvas()
			var rect := Rect2(transform*Vector2(-126,-58),Vector2(252,48)*transform.x.length())
			_check(rect.position.y>=7.9 and rect.position.x>=7.9 and rect.end.x<=get_viewport().get_visible_rect().size.x-7.9,"反馈文字完整在屏幕内："+kind)
			_check(not rect.intersects(Rect2(get_viewport().get_visible_rect().size.x*0.5-105,0,210,80)),"反馈文字避开营业牌："+kind)
		await _shot(kind+"_feedback")
		if kind in ["bad_drink","question"]:
			_check(sm.restaurant_customer_order(order.id).phase=="waiting","水反馈后继续等餐："+kind)
			await get_tree().create_timer(2.1).timeout
			flow._sync()
			_check(actor.get_node_or_null("CustomerFeedback")==null and actor.get_node("OrderBubble").visible,"2.2秒后恢复订单气泡："+kind)
		else:
			await get_tree().create_timer(2.3).timeout
			_check(is_instance_valid(actor) and actor.position.distance_to(start)>15 and not sm.restaurant_customer_order(order.id).is_empty(),"反馈后可见移动且尚未释放："+kind)
			await _shot(kind+"_walking")
			await get_tree().create_timer(6.0).timeout
			flow._sync()
			_check(sm.restaurant_customer_order(order.id).is_empty() and not flow.actors.has(order.id),"走到出口才移除："+kind)
		scene.queue_free()
		await get_tree().process_frame

func _clock_three() -> void:
	_seed_cycle()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(2.2).timeout
	var front: Dictionary = sm.restaurant_customers().front
	_check(front.get("phase")=="front","墙钟验收顾客已到点餐处")
	var start: float = front.remaining
	var business: float = Day.snapshot(sm).remaining
	await get_tree().create_timer(10).timeout
	var current: Dictionary = sm.restaurant_customers().front
	_check(absf((start-float(current.remaining))-10)<0.8,"真实十秒对应候客耐心")
	_check(absf((business-float(Day.snapshot(sm).remaining))-10)<0.8,"真实十秒对应营业倒计时")
	await get_tree().create_timer(31).timeout
	_check(sm.restaurant_customer_order(front.id).get("phase")=="leaving" or sm.restaurant_customer_order(front.id).is_empty(),"真实40秒候客超时离场")
	_check(sm.gold_balance()==99 and sm.reputation()==99,"墙钟超时只扣一次1金币1声望")
	await _shot("real_clock_front_timeout")
	scene.queue_free()
	await get_tree().process_frame

func _migration() -> void:
	_seed_cycle()
	var base := _arrive()
	var old: Dictionary = sm.data.restaurant_customers.duplicate(true)
	old.erase("layout_revision")
	old.erase("legacy_waiting")
	old.seated = []
	old.serial = 6
	for i in 6:
		var order := base.duplicate(true)
		order.id = "service_%d"%(i+1)
		order.seat = i
		order.stage = "food"
		order.phase = "waiting"
		order.remaining = 31.0+i
		old.seated.append(order)
	old.seated[4].stage = "done"
	old.seated[4].phase = "eating"
	old.seated[4].food_done = true
	old.seated[5].stage = "done"
	old.seated[5].phase = "leaving"
	old.seated[5].outcome = "wrong_dish"
	sm.data.restaurant_customers = old
	var gold: int = sm.gold_balance()
	_rollback(func(): return Cycle.migrate_customers(sm),"旧六座迁移保存失败保留原始数据")
	_check(Cycle.migrate_customers(sm).success,"旧六座原子迁移")
	var migrated: Dictionary = sm.data.restaurant_customers.duplicate(true)
	_check(migrated.seated.size()==3 and migrated.legacy_waiting.size()==3,"旧六座保留三座与三条已接单待入座记录")
	for i in 3:
		_check(migrated.seated[i].id==old.seated[i].id and migrated.seated[i].remaining==old.seated[i].remaining,"前三位ID耐心不变")
		_check(migrated.legacy_waiting[i].id==old.seated[i+3].id and migrated.legacy_waiting[i].remaining==old.seated[i+3].remaining,"多余三位ID耐心不变")
	var snapshot: Dictionary = sm.data.duplicate(true)
	_check(Cycle.migrate_customers(sm).success and sm.data==snapshot,"重复迁移不改阶段耐心及订单")
	sm.save()
	sm.load_data()
	_check(JSON.parse_string(JSON.stringify(sm.restaurant_customers()))==JSON.parse_string(JSON.stringify(migrated)),"旧档迁移后读档全部记录保留",{"before":migrated,"after":sm.restaurant_customers()})
	Cycle.tick(sm,10)
	_check(sm.restaurant_customer_order("service_4").remaining==34 and sm.restaurant_customer_order("service_4").phase=="waiting","待入座旧客暂停耐心且阶段不变")
	_stage("service_1","food",0.1)
	Cycle.tick(sm,0.1)
	sm.advance_restaurant_customer("service_1","leaving","departed")
	_rollback(func(): return sm.ensure_restaurant_customer(),"旧客恢复入座保存失败不丢不复制")
	_check(sm.ensure_restaurant_customer().get("resumed",false),"腾座优先恢复旧客")
	_check(sm.restaurant_customer_order("service_4").phase=="seating" and sm.restaurant_customer_order("service_4").remaining==34,"旧客走向座位保留剩余时间")
	Cycle.tick(sm,1)
	sm.advance_restaurant_customer("service_4","seating","waiting")
	_check(sm.restaurant_customer_order("service_4").phase=="waiting" and sm.restaurant_customer_order("service_4").remaining==34,"坐稳恢复原等餐阶段")
	_check(sm.gold_balance()==gold-2,"迁移与恢复不额外扣罚或奖励")
	for id in ["service_2","service_3","service_4"]: _stage(id,"food",0.1)
	Cycle.tick(sm,0.1)
	for id in ["service_2","service_3","service_4"]: sm.advance_restaurant_customer(id,"leaving","departed")
	gold = sm.gold_balance()
	_check(sm.ensure_restaurant_customer().get("resumed",false),"恢复旧档已进食顾客")
	sm.advance_restaurant_customer("service_5","seating","waiting")
	_check(sm.restaurant_customer_order("service_5").phase=="eating","迁移保留进食阶段，不重新等待料理")
	sm.advance_restaurant_customer("service_5","eating","farewell")
	sm.advance_restaurant_customer("service_5","farewell","leaving")
	sm.advance_restaurant_customer("service_5","leaving","departed")
	_check(sm.ensure_restaurant_customer().get("resumed",false),"恢复旧档已扣罚离场顾客")
	sm.advance_restaurant_customer("service_6","seating","waiting")
	_check(sm.restaurant_customer_order("service_6").phase=="leaving" and sm.restaurant_customer_order("service_6").outcome=="wrong_dish","迁移保留离场结果")
	Cycle.tick(sm,10)
	_check(sm.gold_balance()==gold,"旧进食与离场恢复不重复奖惩")
	_seed_cycle()
	var front: Dictionary = sm.ensure_restaurant_customer().order
	sm.advance_restaurant_customer(front.id,"arriving","front")
	sm.data.restaurant_customers.erase("layout_revision")
	Cycle.migrate_customers(sm)
	_check(sm.restaurant_customer_order(front.id).phase=="front" and sm.restaurant_customers().seated.is_empty(),"未接单旧客不被提前接单")
	var mixed: Dictionary = sm.data.restaurant_customers.duplicate(true)
	mixed.erase("layout_revision")
	mixed.seated = old.seated.slice(0,3).duplicate(true)
	mixed.front.id = "legacy_front"
	sm.data.restaurant_customers = mixed
	_check(Cycle.migrate_customers(sm).success and sm._customers_valid(sm.restaurant_customers()),"三座旧客加未接单前台客可迁移")
	_check(not sm.accept_restaurant_customer("legacy_front").success and sm.restaurant_customers().front.id=="legacy_front","满座旧档保留未接单客，不强行入座")

func _full_service() -> void:
	_seed_cycle()
	# 从准备界面的真实按钮开始，而非只测保存函数。
	sm.data.erase(Day.KEY)
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var player = scene.get_node("Player")
	hud._open_day_menu()
	_check(hud.day_menu.visible,"准备阶段可以打开菜单")
	hud.day_menu.draft = {"salt_grilled_rockmane":1}
	hud.day_menu._rebuild()
	await _click(hud.day_menu.confirm_button)
	_check(Day.snapshot(sm).status=="open" and not hud.day_menu.visible and not player.input_locked,"真实开始营业按钮原子保存并恢复输入")
	await get_tree().create_timer(0.9).timeout
	await _wait_until(func(): return sm.restaurant_customers().front.get("phase")=="front",240)
	var front: Dictionary = sm.restaurant_customers().front
	player.position = _stand(scene.get_node("InteractPoints/Register"))
	player.last_valid = player.position
	await _send_key(KEY_E)
	await _wait_until(func(): return sm.restaurant_customer_order(front.id).get("phase")=="waiting",480)
	var order: Dictionary = sm.restaurant_customer_order(front.id)
	_check(not sm.ensure_restaurant_customer().get("closed",false),"最后一份已点单但仍有顾客时保留服务")
	await _shot("sold_out_serving")
	_stage(order.id,"drink",40)
	for actual in sm.data.restaurant_customers.seated:
		if actual.id == order.id: actual.drink_ice = 1
	var cart = scene.get_node("InteractPoints/FoodCart")
	player.position = _stand(cart)
	player.last_valid = player.position
	await _send_key(KEY_E)
	var pour = hud.ganlu.modal
	_check(pour.visible and player.input_locked,"真实E打开小餐车")
	_check(pour.hold.text=="按住倒水" and pour.hold.size.x==190,"倒水按钮复用190宽组件且无空格文案")
	await _key_hold(KEY_SPACE,true)
	await get_tree().create_timer(2.9).timeout
	await _shot("pouring_short_button")
	await _key_hold(KEY_SPACE,false)
	var amount: float = pour.amount
	_check(pour.finished and not pour.committed and Drink.snapshot(sm).held.get("phase")=="pouring","松手停止倒水，端起前不发成品杯")
	await _send_key(KEY_SPACE)
	_check(pour.amount==amount,"不能补倒")
	# 等待余水落完、结果翻入及按钮实际启用，不以旧动画延迟推断可以点击。
	if not await _service_checkpoint(func(): return pour.result_popup.is_visible_in_tree() and pour.result_popup._ready_for_input and pour.result_popup._confirm_button.is_visible_in_tree() and not pour.result_popup._confirm_button.disabled,6.0,"结算翻入完成且端起按钮可用"): return
	_check(not pour.committed and Drink.snapshot(sm).held.get("phase")=="pouring","结算展示不提前提交杯子")
	if pour.view.has_method("has_airborne_water"):
		_check(not pour.view.has_airborne_water() and is_equal_approx(float(pour.view.amount),amount),"结果可操作时余水全部入杯且最终倒量一致")
	_check(pour.result_popup._confirm_button.text=="端起","达标水结算提供端起动作")
	await _click(pour.result_popup._confirm_button)
	if not await _service_checkpoint(func(): return not pour.visible and not player.input_locked and Drink.snapshot(sm).held.get("phase")=="ready",2.0,"端起生成成品杯并恢复操作"): return
	_check(is_equal_approx(float(Drink.snapshot(sm).held.amount),amount),"端起保留最终倒量")
	player.position = _stand(scene.get_node("InteractPoints/Fridge"))
	player.last_valid = player.position
	var freezer_view = hud.ganlu.freezer_view
	if not await _service_checkpoint(func(): return hud.ganlu.can_use_freezer() and freezer_view.selected_slot==freezer_view.nearest_slot() and freezer_view.prompt.is_visible_in_tree() and not freezer_view.buttons[freezer_view.selected_slot].disabled,2.0,"靠近冰柜选中可用杯位并显示E提示"): return
	var selected: int = freezer_view.nearest_slot()
	# 新冰柜使用公共交互按钮；旧工作树的图形提示仍可用于兼容验证。
	if freezer_view.prompt is Control:
		_check(freezer_view.prompt.get_node("Content/ActionLabel").text=="冰镇","当前冰柜复用E冰镇提示")
	var held_before: Dictionary = Drink.snapshot(sm).held.duplicate(true)
	await _send_key(KEY_E)
	if not await _service_checkpoint(func(): return not Drink.snapshot(sm).slots[selected].is_empty() and Drink.snapshot(sm).held.is_empty(),2.0,"真实E放入选中杯位并清空手持"): return
	_check(is_equal_approx(float(Drink.snapshot(sm).slots[selected].amount),float(held_before.amount)),"冰柜保存的是刚端起的同一杯水")
	_check(freezer_view.selected_slot==selected and freezer_view.prompt.is_visible_in_tree(),"放杯后保持同一杯位高亮与E提示")
	if not await _service_checkpoint(func(): return not Drink.chilling(Drink.snapshot(sm).slots[selected]) and not freezer_view.buttons[selected].disabled,6.0,"真实冰镇达到可取状态且杯位按钮启用"): return
	await _shot("freezer_selected_chilling")
	await _send_key(KEY_E)
	if not await _service_checkpoint(func(): return Drink.snapshot(sm).slots[selected].is_empty() and Drink.snapshot(sm).held.get("phase")=="ready",2.0,"真实E取出同一杯并释放杯位"): return
	_check(Drink.grade(Drink.snapshot(sm).held)==1 and is_equal_approx(float(Drink.snapshot(sm).held.amount),amount),"真实冰镇取出加冰水且倒量不变")
	player.position = Three.service_point(int(order.seat))
	player.last_valid = player.position
	await _send_key(KEY_E)
	_check(sm.restaurant_customer_order(order.id).stage=="food","实际倒水冰镇交付接续料理")
	player.position = _stand(scene.get_node("InteractPoints/Store"))
	player.last_valid = player.position
	await _send_key(KEY_E)
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	_check(warehouse.is_visible_in_tree(),"真实仓库界面可见")
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._salt_slot._icon_button)
	await _shot("warehouse_suggestion")
	await _click(warehouse._claim_button)
	_check(sm.carried_ingredients()=={"rockmane_meat":1,"rock_salt":1} and not player.input_locked,"真实点击取一份配方材料")
	player.position = _stand(scene.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.position
	await _send_key(KEY_E)
	var cooking = scene.get_node("HUD/CookingModal")
	_check(cooking.visible,"真实E打开烹饪")
	await _click(cooking._start_button)
	var deadline := Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline and not cooking._finished:
		if cooking._finish_button.is_visible_in_tree() and not cooking._finish_button.disabled:
			await _click(cooking._finish_button)
		await get_tree().process_frame
	_check(cooking._finished and sm.carried_dish_count()==1,"真实烹饪起锅生成单份料理")
	if cooking._finished:
		_check(await _wait_until(func(): return cooking._result_popup.is_visible_in_tree() and not cooking._result_popup._confirm_button.disabled,180),"等待实际结果窗确认按钮就绪")
		await _click(cooking._result_popup._confirm_button)
	_check(not player.input_locked,"烹饪确认恢复移动")
	player.position = Three.service_point(int(order.seat))
	player.last_valid = player.position
	await _send_key(KEY_E)
	_check(sm.restaurant_customer_order(order.id).get("outcome")=="served","真实菜单到取料烹饪交付全链路")
	await get_tree().create_timer(8.0).timeout
	_check(sm.restaurant_customer_order(order.id).is_empty(),"正常顾客不弹阻塞对白并自动离场")
	_check(await _wait_until(func(): return is_instance_valid(hud.day_settlement) and hud.day_settlement.visible,180),"最后一份料理实际交付离场后立即弹结算")
	if is_instance_valid(hud.day_settlement): await _click(hud.day_settlement._confirm_button)
	_check(Day.snapshot(sm).day==2 and Day.snapshot(sm).status=="preparing","确认营业结算进入次日准备")
	await _shot("sold_out_next_day")

	scene.queue_free()
	await get_tree().process_frame

## 仅完整服务夹具使用墙钟上限；失败保留断言并停止后续输入，避免连锁误报。
func _service_checkpoint(predicate: Callable, timeout_seconds: float, label: String) -> bool:
	var started := Time.get_ticks_msec()
	var deadline := started + int(timeout_seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var passed: bool = predicate.call()
	_check(passed,label,{"elapsed_ms":Time.get_ticks_msec()-started,"timeout_seconds":timeout_seconds})
	if not passed:
		await _shot("service_failed_checkpoint")
		scene.queue_free()
		await get_tree().process_frame
	return passed
