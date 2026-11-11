extends "res://tools/tests/restaurant_departure_fade.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离存档")
	for phase in ["eating","seating"]:
		_fresh()
		_open({A:2})
		var order := _order(phase=="eating")
		if phase=="eating":
			_cook(A)
			sm.deliver_restaurant_customer(order.id)
		else: sm.accept_restaurant_customer(order.id)
		var hud = await _open_restaurant()
		var flow = hud.customer_flow
		flow.set_process(false)
		flow._sync()
		var actor: Sprite2D = flow.actors[order.id]
		await get_tree().create_timer(0.1).timeout
		var origin := actor.position
		_check(Cycle.settle(sm,"time").success,"动画中到时无罚结算 "+phase)
		flow._sync()
		var gold: int = sm.gold_balance()
		await get_tree().create_timer(0.15).timeout
		_check(actor.position.distance_to(origin)<0.1 and actor.modulate.a>0 and actor.modulate.a<1,"中断旧动画原地渐隐 "+phase)
		for frame in 90:
			await get_tree().process_frame
			flow._sync()
			if is_instance_valid(actor): _check(actor.position.distance_to(origin)<0.1,"不继续旧位移动画 "+phase)
		_check(sm.restaurant_customer_order(order.id).is_empty() and sm.gold_balance()==gold,"无旧进食回调重复推进/奖惩 "+phase)
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
