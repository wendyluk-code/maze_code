extends "res://tools/tests/ganlu_service.gd"
const Cycle := preload("res://scripts/restaurant/service_cycle.gd")
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Layout := preload("res://scripts/restaurant/six_seat_layout.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"正式存档隔离")
	if failures == 0:
		if _arg("--mode=") == "clock":
			await _real_clock()
		elif _arg("--mode=") == "resume":
			_resume_cycle()
		else:
			_state_cycle()
			await _visuals_and_inputs()
			_resume_seed()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _visuals_and_inputs() -> void:
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		await _scene_cycle()
	await _real_service()
	await _tieshan_preserved()

func _seed_cycle() -> void:
	_completed()
	sm.data["first_exploration_gate_v1"] = "done"
	tm.active = false
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.set_yufeng_salia_state("done")
	sm.acknowledge_freezer_notice()
	sm.data.gold = 100
	sm.data.reputation = 100
	sm.data.warehouse_stock = {"rockmane_meat":30,"rock_salt":30}
	sm.data.unlocked_recipe_ids = ["salt_grilled_rockmane","slime_candy"]
	sm.data.restaurant_customers = {"serial":0,"front":{},"queue":[],"seated":[]}
	sm.data.erase(Day.KEY)
	sm.data.erase(Drink.KEY)
	_check(Day.save_menu(sm,{"salt_grilled_rockmane":10}).success,"确认十份菜单")
	_check(Cycle.begin_day(sm).success,"菜单进入真实营业")

func _arrive() -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var result: Dictionary = sm.ensure_restaurant_customer()
	_check(result.get("created",false),"实际生成普通顾客")
	if not result.get("created",false): return {}
	var id: String = result.order.id
	_check(sm.advance_restaurant_customer(id,"seating","waiting").success,"入座后开始等待")
	return sm.restaurant_customer_order(id)

func _stage(id: String, stage: String, remaining: float) -> void:
	for order in sm.data.restaurant_customers.seated:
		if order.id == id:
			order.stage = stage
			order.remaining = remaining
			order.drink_done = stage != "drink"
			if stage == "drink": order.drink_ice = 2

func _state_cycle() -> void:
	for seconds in [0.0,2.9,3.0,5.9,6.0,8.9,9.0,11.9,12.0,14.9,15.0,17.9,18.0]:
		var cup := {"cold":seconds,"chill_revision":2}
		var expected := 4 if seconds>=18 else 3 if seconds>=15 else 2 if seconds>=9 else 1 if seconds>=3 else 0
		_check(Drink.grade(cup)==expected,"冰镇阶段边界%s" % seconds)
	_check(Drink.fill({"cold":3.0})==Drink.fill({"cold":5.9}),"少冰窗口暂停上涨")
	_check(Drink.fill({"cold":9.0})==Drink.fill({"cold":11.9}),"中冰窗口暂停上涨")
	_check(Drink.ice_factor(4,3)==0 and Drink.ice_factor(4,0)==0,"过冰对所有需求均无小费")
	_seed_cycle()
	_check(Day.snapshot(sm).plan.filter(func(p): return p.drink).size()==3,"每日十位中恰好三位点甘露水")
	_check(Day.snapshot(sm).remaining==300,"营业固定五分钟")
	for n in range(1,11):
		_check(Day.snapshot(sm).plan.slice(0,n).filter(func(p): return p.drink).size()==int(round(n*0.3)),"提前结束也按入座人数计算饮水比例%d"%n)
	var stock: Dictionary = sm.warehouse_snapshot()
	_check(stock.rockmane_meat==30,"开业不重复消耗原料")
	_check(not Cycle.begin_day(sm).success,"不能重复开业")
	var order := _arrive()
	_stage(order.id,"drink",20.0)
	var rep: int = sm.reputation()
	var gold: int = sm.gold_balance()
	_check(Cycle.tick(sm,19).success and sm.restaurant_customer_order(order.id).stage=="drink","饮水19秒未超时")
	sm.save()
	sm.load_data()
	_check(sm.restaurant_customer_order(order.id).remaining==1,"读档不重置等待时间")
	_check(Cycle.tick(sm,1).success and sm.restaurant_customer_order(order.id).stage=="food" and sm.restaurant_customer_order(order.id).remaining==60,"饮水20秒后开始完整60秒料理")
	_check(sm.gold_balance()==gold and sm.reputation()==rep,"饮水超时不扣奖励")
	_make_cup()
	var extra := Drink.deliver(sm,order.id)
	_check(extra.success and extra.question and Drink.snapshot(sm).held.is_empty() and sm.gold_balance()==gold,"未点水/超时后送水消耗杯子只冒问号")
	_stage(order.id,"drink",20)
	_make_cup()
	sm.data[Drink.KEY].held.cold = 18.0
	sm.data[Drink.KEY].held.chill_revision = 2
	for seated_order in sm.data.restaurant_customers.seated:
		if seated_order.id==order.id: seated_order.drink_ice = 3
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Drink.deliver(sm,order.id).success and sm.data==before,"饮水保存失败杯子和阶段全部回滚")
	sm._active_save_path = path
	var delivered := Drink.deliver(sm,order.id)
	_check(delivered.success and delivered.penalty==2 and delivered.gold==3 and delivered.factor==0 and sm.reputation()==rep,"满冰订单收到过冰仍扣2金币且无小费不扣声望")
	_check(sm.restaurant_customer_order(order.id).stage=="food","错冰度仍进入料理")
	_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).success,"按一份配方实际领取食材")
	_check(not Drink.begin(sm).success,"携食材不能倒水")
	_check(sm.start_cooking("salt_grilled_rockmane").success,"真实扣料开锅")
	_check(not Drink.begin(sm).success,"烹饪中不能凭空持水")
	_check(sm.finish_first_order_cooking(3).success,"起锅携带一份料理")
	_check(not Drink.begin(sm).success and not sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).success,"料理与食材、水互斥")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.deliver_restaurant_customer(order.id).success and sm.data==before,"料理交付保存失败完整回滚")
	sm._active_save_path = path
	_check(sm.deliver_restaurant_customer(order.id).success and sm.restaurant_customer_order(order.id).phase=="eating","正确料理结算进食")
	_check(not sm.deliver_restaurant_customer(order.id).success,"重复上菜无奖励")
	_check(sm.advance_restaurant_customer(order.id,"eating","farewell").success and sm.advance_restaurant_customer(order.id,"farewell","leaving").success and sm.advance_restaurant_customer(order.id,"leaving","departed").success,"进食离场释放座位")
	order = _arrive()
	_stage(order.id,"food",0.2)
	gold = sm.gold_balance()
	rep = sm.reputation()
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Cycle.tick(sm,1).success and sm.data==before,"超时保存失败扣款阶段回滚")
	sm._active_save_path = path
	_check(Cycle.tick(sm,0.2).success and sm.restaurant_customer_order(order.id).phase=="leaving" and sm.gold_balance()==gold-2 and sm.reputation()==rep-1,"料理超时扣金币2声望1离开")
	Cycle.tick(sm,60)
	_check(sm.gold_balance()==gold-2 and sm.reputation()==rep-1,"超时不重复扣款")
	sm.advance_restaurant_customer(order.id,"leaving","departed")
	order = _arrive()
	_stage(order.id,"food",60)
	_food()
	gold = sm.gold_balance()
	_check(sm.deliver_restaurant_customer(order.id).get("outcome")=="wrong_dish" and sm.gold_balance()==gold-2 and sm.inventory_quantity("slime_candy")==0,"错误料理消耗并扣2金币离场")
	sm.advance_restaurant_customer(order.id,"leaving","departed")
	# 完成剩余七位，证明不再受三人一次性限制，回到下一天准备。
	for i in 7:
		order = _arrive()
		_stage(order.id,"food",0.1)
		Cycle.tick(sm,0.1)
		sm.advance_restaurant_customer(order.id,"leaving","departed")
	_check(float(Day.snapshot(sm).remaining)>0,"菜单用尽时尚未达到五分钟")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.ensure_restaurant_customer().success and sm.data==before,"提前打烊保存失败完整回滚")
	sm._active_save_path = path
	_check(sm.ensure_restaurant_customer().get("closed",false) and Day.snapshot(sm).day==2,"菜单售罄且顾客离场立即进入第二天")
	_check(not sm.ensure_restaurant_customer().get("closed",false) and Day.snapshot(sm).day==2,"重复打烊不重复增加天数")
	_check(Day.save_menu(sm,{"salt_grilled_rockmane":10}).success and Cycle.begin_day(sm).success,"下一天可再次开业")
	for i in 6: _arrive()
	sm.data[Day.KEY].arrival_left = 0
	_check(not sm.ensure_restaurant_customer().get("created",false) and sm.restaurant_customers().seated.size()==6,"满六席停止来客无排队")
	sm.data[Day.KEY].remaining = 0.1
	Cycle.tick(sm,0.1)
	_check(Day.snapshot(sm).status=="closing" and sm.restaurant_customers().seated.size()==6 and not sm.ensure_restaurant_customer().get("created",false),"五分钟结束停止来客且保留已入座客人")
	_check(not Cycle.open_with_menu(sm,{"salt_grilled_rockmane":1}).success,"收尾阶段不能提前开下一天")
	var frozen: Dictionary = sm.data.duplicate(true)
	sm.save()
	sm.load_data()
	var restored: Array = sm.restaurant_customers().seated
	var same_orders: bool = restored.size()==frozen.restaurant_customers.seated.size()
	for i in restored.size():
		var expected: Dictionary = frozen.restaurant_customers.seated[i].duplicate(true)
		var actual: Dictionary = restored[i].duplicate(true)
		# JSON十进制往返允许浮点舍入；阶段、座位、ID及其他字段必须逐项保留。
		same_orders = same_orders and is_equal_approx(float(actual.remaining),float(expected.remaining))
		actual.erase("remaining")
		expected.erase("remaining")
		same_orders = same_orders and JSON.parse_string(JSON.stringify(actual))==JSON.parse_string(JSON.stringify(expected))
	_check(same_orders and Day.snapshot(sm).status=="closing","收尾与在座订单读档不重置",{"before":frozen.restaurant_customers.seated,"after":restored,"day_status":Day.snapshot(sm).status})
	# 旧普通顾客只迁移订单，已结算料理不重复收费；首章另行验收。
	_seed_cycle()
	order = _arrive()
	for actual in sm.data.restaurant_customers.seated:
		actual.erase("cycle")
		actual.erase("stage")
		actual.erase("remaining")
		actual.drink_ice = 1
		actual.drink_done = false
		actual.food_done = false
	_check(Cycle.migrate_customers(sm).success and sm.restaurant_customer_order(order.id).stage=="drink","旧普通订单接续为先水后菜")
	before = sm.data.duplicate(true)
	_check(Cycle.migrate_customers(sm).success and sm.data==before,"重复迁移不重置倒计时")
	_make_cup()
	var wrong_one := Drink.deliver(sm,order.id)
	_check(wrong_one.success and wrong_one.penalty==1 and wrong_one.gold==5,"冰差一档扣1并保留半档小费")
	_check(sm.quest_snapshot().active.any(func(q): return q.id=="customer_order:"+order.id),"料理阶段才生成任务")
	_check(sm.mark_active_quests_read().success,"玩家主动查看才能清除未读")
	_stage(order.id,"food",0.1)
	sm.data.gold = 0
	sm.data.reputation = 0
	Cycle.tick(sm,0.1)
	_check(sm.gold_balance()==0 and sm.reputation()==0,"余额不足扣至零不写负数")
	_check(sm.quest_snapshot().archived.any(func(q): return q.id=="customer_order:"+order.id),"超时订单归档不残留活动任务")
	sm.advance_restaurant_customer(order.id,"leaving","departed")
	before = sm.data.duplicate(true)
	sm.data[Day.KEY].remaining = -1
	var bad: Dictionary = sm.data.duplicate(true)
	_check(not Cycle.tick(sm,1).success and sm.data==bad,"损坏营业时间拒绝推进且保留原始数据")
	sm.data = before

func _scene_cycle() -> void:
	_seed_cycle()
	for i in 6:
		var order := _arrive()
		_stage(order.id,"drink" if i==0 else "food",10.0 if i==0 else 35.0)
	sm.save()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.8).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.customer_flow
	var player = scene.get_node("Player")
	player.position = Layout.service_point(0)
	player.last_valid = player.position
	await get_tree().create_timer(0.3).timeout
	_check(flow.selected_id=="service_1","靠近第一席明确选中第一位")
	var bubble = flow.actors["service_1"].get_node("OrderBubble")
	_check(bubble.drink and not bubble.food and bubble.selected,"仅显示饮水气泡及E选中态")
	await _shot("six_seats_countdown")
	for actor in flow.actors.values():
		var probe = actor.get_node("OrderBubble")
		var top: Vector2 = probe.get_global_transform_with_canvas() * Vector2(-42,-90)
		_check(top.y >= 0,"普通气泡不被屏幕顶部裁切",{"actor":actor.name,"top":str(top),"position":str(probe.position)})
		var rect := Rect2(top,Vector2(84,78)*0.72*scene.get_node("Camera").zoom)
		_check(not rect.intersects(Rect2(get_viewport().get_visible_rect().size.x*0.5-105,0,210,80)),"气泡避开营业牌")
	_make_cup()
	await _send_key(KEY_E)
	await get_tree().create_timer(0.3).timeout
	_check(sm.restaurant_customer_order("service_1").stage=="food" and Drink.snapshot(sm).held.is_empty(),"真实E向所选顾客交水转料理")
	_check(bubble.food and not bubble.drink and bubble.ingredients.size()==2,"料理气泡显示实际配方图标")
	await _shot("food_selected")
	_make_cup()
	await _send_key(KEY_E)
	await get_tree().create_timer(0.3).timeout
	_check(bubble.question and sm.restaurant_customer_order("service_1").phase=="waiting","重复水问号并继续等待")
	await _shot("unrequested_water")
	player.position = Layout.service_point(1)
	player.last_valid = player.position
	await get_tree().create_timer(0.3).timeout
	_check(flow.selected_id=="service_2" and not bubble.selected,"沿吧台移动切换指定对象")
	_food()
	await _send_key(KEY_E)
	await get_tree().create_timer(1.2).timeout
	_check(sm.restaurant_customer_order("service_2").is_empty(),"真实E错误料理只让第二位离场")
	_check(sm.restaurant_customer_order("service_1").phase=="waiting","第一位未被自动匹配或影响")
	await _shot("wrong_dish_departed")
	scene.queue_free()
	await get_tree().process_frame

func _resume_seed() -> void:
	_seed_cycle()
	var first := _arrive()
	_stage(first.id,"drink",17)
	var second := _arrive()
	_stage(second.id,"food",31)
	_make_cup()
	Drink.slot(sm,0)
	Drink.tick(sm,4)
	sm.data[Day.KEY].remaining = 123.0
	var snapshot := FileAccess.open("res://output/restaurant_cycle_20261031/resume_seed.json",FileAccess.WRITE)
	snapshot.store_string(JSON.stringify(sm.data))

func _resume_cycle() -> void:
	var snapshot := FileAccess.get_file_as_string("res://output/restaurant_cycle_20261031/resume_seed.json")
	var isolated := FileAccess.open("user://resume-cycle.json",FileAccess.WRITE)
	isolated.store_string(snapshot)
	isolated.close()
	sm._active_save_path = "user://resume-cycle.json"
	sm.load_data()
	_check(sm.restaurant_customer_order("service_1").stage=="drink" and sm.restaurant_customer_order("service_1").remaining==17,"独立进程恢复饮水阶段及17秒")
	_check(sm.restaurant_customer_order("service_2").stage=="food" and sm.restaurant_customer_order("service_2").remaining==31,"独立进程恢复料理阶段及31秒")
	_check(Day.snapshot(sm).remaining==123 and Day.snapshot(sm).arrived==2,"独立进程恢复营业123秒和已来人数")
	_check(Drink.snapshot(sm).slots[0].cold==4 and Drink.snapshot(sm).held.is_empty(),"独立进程保留冰柜杯子及冰镇进度")
	_check(Cycle.tick(sm,17).success and sm.restaurant_customer_order("service_1").stage=="food" and sm.restaurant_customer_order("service_2").remaining==14,"恢复后两阶段独立继续推进")

func _real_clock() -> void:
	_seed_cycle()
	var started := Time.get_ticks_msec()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(10).timeout
	_check(Day.snapshot(sm).remaining <= 291 and Day.snapshot(sm).remaining >= 287,"真实十秒后营业计时对应墙钟")
	await _shot("clock_ten_seconds")
	while Time.get_ticks_msec()-started < 200000 and int(Day.snapshot(sm).arrived)<10:
		await get_tree().create_timer(0.2).timeout
	_check(Day.snapshot(sm).day==1 and not sm.restaurant_customers().seated.is_empty() and not sm.ensure_restaurant_customer().get("created",false),"售罄停止来客但保留在座订单")
	await _shot("sold_out_with_guests")
	while Time.get_ticks_msec()-started < 250000 and int(Day.snapshot(sm).day)==1:
		await get_tree().create_timer(0.2).timeout
	var elapsed := (Time.get_ticks_msec()-started)/1000.0
	_check(Day.snapshot(sm).day==2 and elapsed<300,"真实场景售罄收尾后提前结束营业",{"elapsed_seconds":elapsed})
	_check(sm.restaurant_customers().seated.is_empty() and sm.gold_balance()==80 and sm.reputation()==90,"十位超时实际离场且各只扣一次")
	_check(sm.data.restaurant_order_receipts.size()==10,"真实营业不再限制三位客人")
	await _shot("clock_closed")
	scene.queue_free()
	await get_tree().process_frame

func _real_service() -> void:
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
	var order: Dictionary = sm.restaurant_customers().seated[0]
	_check(not sm.ensure_restaurant_customer().get("closed",false),"最后一份已点单但仍有顾客时保留服务")
	await _shot("sold_out_serving")
	_stage(order.id,"drink",20)
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
	_check(pour.finished and not pour.committed and pour.result_popup.visible,"松手显示结算，端起前不发杯")
	await _send_key(KEY_SPACE)
	_check(pour.amount==amount,"不能补倒")
	await get_tree().create_timer(0.3).timeout
	await _click(pour.result_popup._confirm_button)
	_check(not pour.visible and not player.input_locked,"端起恢复操作")
	player.position = _stand(scene.get_node("InteractPoints/Fridge"))
	player.last_valid = player.position
	await get_tree().process_frame
	var freezer_view = hud.ganlu.freezer_view
	var selected: int = freezer_view.nearest_slot()
	await _send_key(KEY_E)
	_check(not Drink.snapshot(sm).slots[selected].is_empty(),"真实E放入靠近的冰柜杯位")
	_check(freezer_view.selected_slot==selected and freezer_view.prompt.visible,"靠近格子高亮并显示挖掘点E")
	await get_tree().create_timer(3.1).timeout
	await _shot("freezer_selected_chilling")
	await _send_key(KEY_E)
	_check(Drink.grade(Drink.snapshot(sm).held)==1,"真实冰镇三秒后取出少冰")
	player.position = Layout.service_point(int(order.seat))
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
	player.position = Layout.service_point(int(order.seat))
	player.last_valid = player.position
	await _send_key(KEY_E)
	_check(sm.restaurant_customer_order(order.id).get("outcome")=="served","真实菜单到取料烹饪交付全链路")
	await get_tree().create_timer(3.0).timeout
	_check(sm.restaurant_customer_order(order.id).is_empty(),"正常顾客不弹阻塞对白并自动离场")
	_check(await _wait_until(func(): return Day.snapshot(sm).day==2 and Day.snapshot(sm).status=="preparing",180),"最后一份料理实际交付离场后立即打烊")
	await _shot("sold_out_next_day")
	for slot_index in range(3):
		var found := false
		for y in range(-180,181,15):
			if found: break
			for x in range(-180,181,15):
				var point: Vector2 = freezer_view.global_position + Vector2(x,y)
				if not player.is_walkable_footprint(point): continue
				player.global_position = point
				player.last_valid = point
				if hud.ganlu.can_use_freezer() and freezer_view.nearest_slot()==slot_index:
					found = true
					break
		_check(found,"杯位%d存在合法站位" % slot_index)
		if not found: continue
		await get_tree().create_timer(0.2).timeout
		_make_cup()
		await _send_key(KEY_E)
		_check(not Drink.snapshot(sm).slots[slot_index].is_empty(),"靠近杯位%d按E准确放入" % slot_index)
		await _shot("freezer_slot_%d" % slot_index)
		if slot_index==2:
			Drink.tick(sm,15.0)
			await _shot("freezer_full_green")
			Drink.tick(sm,3.0)
			await _shot("freezer_overcold_red")
		var before_slot: Dictionary = Drink.snapshot(sm)
		hud.ganlu.use_slot((slot_index+1)%3)
		_check(Drink.snapshot(sm)==before_slot,"不能操作未选中的杯位")
		await _send_key(KEY_E)
		_check(Drink.snapshot(sm).slots[slot_index].is_empty() and not Drink.snapshot(sm).held.is_empty(),"原位置E取出同一杯")
		if slot_index==2:
			_check(Drink.grade(Drink.snapshot(sm).held)==4,"过冰取出仍过冰")
			sm.save()
			sm.load_data()
			_check(Drink.grade(Drink.snapshot(sm).held)==4,"过冰读档保留")
			await _send_key(KEY_E)
			await _send_key(KEY_E)
			_check(Drink.grade(Drink.snapshot(sm).held)==4,"重新放入取出不恢复过冰")
		Drink.discard(sm)
	player.position = _stand(scene.get_node("InteractPoints/FoodCart"))
	player.last_valid = player.position
	await get_tree().create_timer(0.2).timeout
	_check(freezer_view.selected_slot==-1 and not freezer_view.prompt.visible,"远离冰柜隐藏选择与E")
	scene.queue_free()
	await get_tree().process_frame

func _tieshan_preserved() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://tieshan-preserved.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success,"铁山保留真实首单入口")
	sm.save()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.3).timeout
	tm.start()
	await get_tree().create_timer(0.5).timeout
	var guest = tm._parked_guest
	_check(is_instance_valid(guest),"铁山教程独立恢复人物")
	if is_instance_valid(guest):
		var bubble = guest.get_node("OrderBubble")
		_check(bubble.get_script().resource_path=="res://scripts/ui/components/tieshan_order_bubble.gd" and not "remaining" in bubble,"铁山料理气泡保留无倒计时")
		var before: Dictionary = sm.data.duplicate(true)
		Cycle.tick(sm,100)
		_check(sm.data==before,"普通营业计时不影响首单")
		_check(not Cycle.begin_day(sm).success and sm.restaurant_customers().seated.is_empty(),"首章不启动普通顾客")
		_check(sm.claim_first_order_ingredients().success and sm.cook_first_order().success and sm.deliver_first_order().success,"铁山原取料烹饪交付结算不变")
		await get_tree().create_timer(0.2).timeout
		_check(not bubble.visible,"铁山交付后原气泡隐藏")
		await _shot("tieshan_original")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame
