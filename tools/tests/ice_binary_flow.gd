extends "res://tools/tests/restaurant_service_cycle.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	_seed_cycle()
	var order := _arrive()
	_stage(order.id,"drink",20)
	_check(Drink.begin(sm).success and Drink.finish(sm,0.65).success,"倒水达标")
	_check(Drink.slot(sm,0).success,"放入冰柜")
	var before: Dictionary = sm.data.duplicate(true)
	_check(Drink.slot(sm,0).get("reason")=="chilling" and sm.data==before,"冰镇中不能取出且不改状态")
	Drink.tick(sm,3)
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==1,"3秒达标")
	Drink.tick(sm,5)
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==1,"绿线保持完整5秒")
	_check(Drink.slot(sm,0).success,"窗口末端允许取出")
	Drink.tick(sm,20)
	_check(Drink.grade(Drink.snapshot(sm).held)==1,"携带时停止计时")
	_check(Drink.slot(sm,0).success,"重放保留进度")
	Drink.tick(sm,0.01)
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==4,"超过窗口变损坏")
	sm.save()
	sm.load_data()
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==4 and Drink.slot(sm,0).success,"读档损坏保留且能取出")
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	before = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Drink.deliver(sm,order.id).success and sm.data==before,"损坏交付保存失败完整回滚")
	sm._active_save_path = path
	_check(Drink.deliver(sm,order.id).get("angry",false),"损坏水触发顾客生气")
	_check(sm.gold_balance()==gold-2 and sm.reputation()==rep-1 and sm.restaurant_customer_order(order.id).phase=="leaving","扣钱声望并取消后续料理")
	Cycle.tick(sm,60)
	_check(sm.gold_balance()==gold-2 and sm.reputation()==rep-1 and not Drink.deliver(sm,order.id).success,"离场后不重复扣款")
	for old in [0.0,2.0,3.0,9.0,15.0,18.0]:
		sm.data[Drink.KEY] = {"held":{"amount":0.65,"cold":old,"phase":"ready","chill_revision":2},"slots":[{},{},{}],"receipts":{}}
		_check(Drink.grade(Drink.snapshot(sm).held)==(4 if old==18 else (1 if old>=3 else 0)),"旧冰度安全迁移"+str(old))
	for actual in [0,1]:
		_seed_cycle()
		order = _arrive()
		_stage(order.id,"drink",20)
		Drink.begin(sm)
		Drink.finish(sm,0.65)
		if actual==1:
			Drink.slot(sm,0)
			Drink.tick(sm,3)
			Drink.slot(sm,0)
		var served: Dictionary = Drink.deliver(sm,order.id)
		_check(served.success and sm.restaurant_customer_order(order.id).stage=="food" and served.gold==(7 if actual==1 else 3),"正常和错温交付进入料理阶段"+str(actual))
	_seed_cycle()
	scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var player = get_tree().get_first_node_in_group("player")
	player.position = _stand(scene.get_node("InteractPoints/Fridge"))
	player.last_valid = player.position
	await get_tree().create_timer(0.1).timeout
	var view = hud.ganlu.freezer_view
	var selected: int = view.nearest_slot()
	hud.ganlu.set_process(false)
	for cold in [0.0,3.0,8.001]:
		var state := Drink.snapshot(sm)
		state.slots[selected] = {"amount":0.65,"phase":"ready","cold":cold,"chill_revision":3}
		Drink.commit(sm,state)
		await get_tree().create_timer(0.15).timeout
		_check(view.buttons[selected].disabled==(cold<3),"按钮与事务禁用状态一致"+str(cold))
		if cold<3:
			before = sm.data[Drink.KEY].duplicate(true)
			await _send_key(KEY_E)
			await _click(view.buttons[selected])
			_check(sm.data[Drink.KEY]==before,"按E路径无法取出冰镇中杯子")
		await _shot_gate("freezer_"+str(int(cold)))
		if cold>=3:
			await _send_key(KEY_E)
			await get_tree().create_timer(0.15).timeout
			_check(not Drink.snapshot(sm).held.is_empty(),"达标及损坏杯可通过交互取出")
			await _shot_gate("held_"+str(int(cold)))
			Drink.discard(sm)
	# 两种订单气泡直接复用实际组件。
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	for ice in [0,1]:
		var bubble := preload("res://scripts/ui/components/service_order_bubble.gd").new()
		layer.add_child(bubble)
		bubble.position = Vector2(560+ice*140,220)
		bubble.head_world = bubble.position
		bubble.setup_order({"item_id":"slime_candy","stage":"drink","drink_ice":ice,"remaining":15})
	await get_tree().create_timer(0.2).timeout
	await _shot_gate("order_bubbles")
	layer.queue_free()
	order = sm.restaurant_customers().seated[0]
	_stage(order.id,"drink",20)
	var damaged := Drink.snapshot(sm)
	damaged.held = {"amount":0.65,"cold":8.001,"phase":"ready","chill_revision":3}
	Drink.commit(sm,damaged)
	player.position = Layout.service_point(int(order.seat))
	player.last_valid = player.position
	await get_tree().create_timer(0.1).timeout
	await _send_key(KEY_E)
	await _shot_gate("angry_customer")
	_check(sm.restaurant_customer_order(order.id).get("outcome","")=="spoiled_drink","真实E交付损坏水触发生气离场")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _shot_gate(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_arg("--output-dir=").path_join(label+".png"))
