extends "res://tools/tests/restaurant_rest05b.gd"
const Guests := preload("res://scripts/restaurant/customer_catalog.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			for reason in ["served","wrong_dish","front_timeout","drink_timeout","timeout","manual","time","legacy"]:
				await _departure(reason)
			await _departure("wrong_dish",true)
			await _seating_fades()
		await _tieshan_preserved()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _departure(reason: String, resume := false) -> void:
	_fresh()
	_open({A:2})
	var order := _order(reason != "front_timeout")
	if reason in ["served","legacy","wrong_dish"]:
		_cook(B if reason=="wrong_dish" else A)
		_check(sm.deliver_restaurant_customer(order.id).success,"实际交付 "+reason)
		if reason=="legacy":
			for customer in sm.data.restaurant_customers.seated:
				customer.erase("cycle")
				customer.erase("outcome")
	elif reason in ["manual","time"]:
		_check(Cycle.settle(sm,reason).success,"实际打烊 "+reason)
	else:
		if reason=="front_timeout": sm.data.restaurant_customers.front.remaining = 0.01
		else: _stage(order.id,"drink" if reason=="drink_timeout" else "food",0.01)
		_check(Cycle.tick(sm,0.02).success,"实际耐心超时 "+reason)
	if resume:
		sm.save()
		sm.load_data()
	if reason=="legacy":
		_check(Cycle.migrate_customers(sm).success,"旧订单经生产迁移进入经营流程")
	var hud = await _open_restaurant()
	var flow = hud.customer_flow
	# 暂停新增业务，但保持真实人物状态/动画同步，避免下一客干扰截图。
	flow.set_process(false)
	flow._sync()
	var actor: Sprite2D = flow.actors[order.id]
	var origin := actor.position
	var camera := get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.global_position = origin + Vector2(0,140)
	camera.reset_smoothing()
	if reason in ["manual","time"] and is_instance_valid(hud.day_settlement): hud.day_settlement.hide()
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	var path: String = sm._active_save_path
	if resume: sm._active_save_path = ""
	await _shot("departure_"+reason+("_resume" if resume else "")+"_before")
	var faded := false
	var stayed := true
	for frame in 310:
		await get_tree().process_frame
		flow._sync()
		if not is_instance_valid(actor): break
		stayed = stayed and actor.position.distance_to(origin)<0.1
		if actor.modulate.a>0.1 and actor.modulate.a<0.8:
			faded = true
			await _shot("departure_"+reason+("_resume" if resume else "")+"_mid")
			break
	_check(faded and stayed,"离场原地出现中间透明度 "+reason+str(resume))
	if resume:
		await get_tree().create_timer(0.8).timeout
		flow._sync()
		_check(is_instance_valid(actor) and actor.modulate.a==0 and actor.position.distance_to(origin)<0.1,"保存失败保持原地透明不重新显现")
		_check(not sm.restaurant_customer_order(order.id).is_empty(),"保存失败不提前释放持久订单")
		sm._active_save_path = path
	for frame in 360:
		await get_tree().process_frame
		flow._sync()
		if not is_instance_valid(actor): break
		stayed = stayed and actor.position.distance_to(origin)<0.1
	_check(stayed and sm.restaurant_customer_order(order.id).is_empty(),"全程不向右走且离场完成 "+reason)
	_check(sm.gold_balance()==gold and sm.reputation()==rep,"动画和重试不重复奖惩 "+reason)
	await _shot("departure_"+reason+("_resume" if resume else "")+"_after")
	await _close_restaurant()

func _seating_fades() -> void:
	_fresh()
	_open({A:2})
	var order := _order(false)
	var hud = await _open_restaurant()
	var flow = hud.customer_flow
	flow.set_process(false)
	flow._sync()
	var actor: Sprite2D = flow.actors[order.id]
	var counter := actor.position
	_check(sm.accept_restaurant_customer(order.id).success,"接单真实事务")
	flow._sync()
	await get_tree().create_timer(0.15).timeout
	_check(actor.position.distance_to(counter)<0.1 and actor.modulate.a>0 and actor.modulate.a<1,"接单前台原地渐隐")
	await _shot("departure_accept_counter_mid")
	await get_tree().create_timer(0.35).timeout
	_check(actor.position.distance_to(Guests.SEATS[int(sm.restaurant_customer_order(order.id).seat)]+Vector2(0,24))<0.1 and actor.modulate.a>0 and actor.modulate.a<1,"接单座位原地渐显")
	await _shot("departure_accept_seat_mid")
	await get_tree().create_timer(0.3).timeout
	_check(sm.restaurant_customer_order(order.id).phase=="waiting","渐显后正常等待")
	await _close_restaurant()
