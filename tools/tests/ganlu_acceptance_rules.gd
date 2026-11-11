extends "res://tools/tests/ganlu_lessons.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"正式存档隔离")
	await _accepted_water()
	await _retry_lessons()
	# 复用真实落座、两段顾客教学、冰柜教学及保存失败回归。
	await super._run()

func _accepted_water() -> void:
	for amount in [0.50,0.59,0.60,0.65,0.70,0.71,0.80]:
		_fresh()
		sm.data["ganlu_lessons_v1"] = {"warm":true,"iced":true,"ready":true,"spoiled":true}
		_open({A:3})
		var order := _order()
		_stage(order.id,"drink",100)
		sm.data.restaurant_customers.seated[0].drink_ice = 0
		var hud = await _open_restaurant()
		hud.customer_flow.set_process(false)
		hud.customer_flow._sync()
		_check(Water.begin(sm).success and Water.finish(sm,amount).success,"可端走倒量："+str(amount))
		var before: Dictionary = sm.data.duplicate(true)
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not Water.deliver(sm,order.id).success and sm.data==before,"交水保存失败完整回滚")
		sm._active_save_path = path
		var balance := Vector2i(sm.gold_balance(),sm.reputation())
		_check(hud.ganlu.serve(order.id),"真实交水控制器")
		await get_tree().process_frame
		_check(Vector2i(sm.gold_balance(),sm.reputation())==balance+Vector2i(7,5),"可端走水量统一合格奖励："+str(amount))
		_check(not hud.customer_flow.actors[order.id].has_node("CustomerFeedback"),"无水不对反馈："+str(amount))
		_check(sm.restaurant_customer_order(order.id).stage=="food","交水后继续料理")
		if amount in [0.50,0.80]: await _shot("accepted_amount_"+str(amount))
		await _close_restaurant()
	_fresh()
	_open({A:3})
	var order := _order()
	_stage(order.id,"drink",100)
	Water.begin(sm)
	Water.finish(sm,0.50)
	var wrong := Water.deliver(sm,order.id)
	_check(wrong.success and wrong.factor<1 and wrong.gold==-1,"温度错误仍不合格")
	_check(Water.pour_factor(0.49)==0 and Water.pour_factor(0.81)==0,"弹窗不可端走范围不放宽")

func _timeout_front(order: Dictionary) -> void:
	sm.data.restaurant_customers.front.remaining = 0.01
	_check(Cycle.tick(sm,0.02).success,"候客超时实际事务")
	_depart(order.id)

func _retry_lessons() -> void:
	_fresh()
	_open({A:3})
	_timeout_front(_order(false))
	var warm := _order(false)
	_check(warm.drink_ice==0,"第2位常温")
	_timeout_front(warm)
	_check(not sm.data.get("ganlu_demand_seated_v1",{}).get("warm",false),"未接单不消耗常温")
	sm.save()
	sm.load_data()
	warm = _order(false)
	_check(warm.drink_ice==0,"第3位顺延常温且读档保留")
	sm.accept_restaurant_customer(warm.id)
	_check(not sm.data.get("ganlu_demand_seated_v1",{}).get("warm",false),"仅接单尚未落座不记完成")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not sm.advance_restaurant_customer(warm.id,"seating","waiting").success and sm.data==before,"落座保存失败不消费机会")
	sm._active_save_path = path
	_check(sm.advance_restaurant_customer(warm.id,"seating","waiting").success,"重试落座")
	_check(sm.data.ganlu_demand_seated_v1.warm,"落座才记录常温完成")
	var iced := _order(false)
	_check(iced.drink_ice==1,"后续安排加冰")
	_timeout_front(iced)
	Cycle.settle(sm,"manual")
	Cycle.acknowledge_settlement(sm)
	sm.data[Day.KEY].erase("preparation_lesson_pending")
	_open({A:3})
	sm.save()
	sm.load_data()
	iced = _order(false)
	_check(iced.drink_ice==1,"加冰未接单跨日读档仍顺延")
	sm.accept_restaurant_customer(iced.id)
	sm.advance_restaurant_customer(iced.id,"seating","waiting")
	_check(sm.data.ganlu_demand_seated_v1.iced,"加冰落座记录完成")
	_check(Cycle.pending_drink_lesson(sm,sm.restaurant_customers()).is_empty(),"两类完成后恢复普通分配")
	var hud = await _open_restaurant()
	await finish_lesson(hud,"iced")
	await _close_restaurant()
