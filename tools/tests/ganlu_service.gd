extends "res://tools/tests/maze_capture.gd"
const Drink := preload("res://scripts/restaurant/ganlu_service.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		_state_checks_drink()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _game_flow()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _prepare_drink(unlock := true) -> void:
	_completed()
	tm.active = false
	sm.data.ch2_guide_01 = {"step":"done", "seen":{}, "banked":{}, "recipe":"", "revision":2}
	if unlock:
		_check(sm.set_yufeng_salia_state("done").success, "冰柜解锁前置")
		sm.acknowledge_freezer_notice()
	var order := {"id":"restaurant_1", "customer_id":"mage", "item_id":"slime_candy", "item_name":"史莱姆糖块", "quantity":1, "phase":"front", "seat":-1}
	sm.data.restaurant_customers = {"serial":1, "front":order, "seated":[], "queue":[], "daily_key":"", "daily_orders":0, "arrival_notice":false}
	_check(sm.accept_restaurant_customer(order.id).success, "真实接单双需求")
	_check(sm.advance_restaurant_customer(order.id,"seating","waiting").success, "入座等餐")
	sm.save()

func _food() -> void:
	var prepared: Dictionary = sm.prepared_dishes_snapshot()
	prepared.slime_candy["3"] += 1
	sm.data.prepared_dishes = prepared
	sm.data.inventory.slime_candy = sm.inventory_quantity("slime_candy") + 1

func _make_cup(amount := 0.65) -> void:
	_check(Drink.begin(sm).success and Drink.finish(sm, amount).success, "倒水事务")

func _state_checks_drink() -> void:
	_prepare_drink(false)
	_check(sm.restaurant_customer_order("restaurant_1").drink_ice == 0, "未解锁冰柜只点不加冰")
	for amount in [0.60,0.70]: _check(Drink.pour_factor(amount) == 1, "倒量5%边界："+str(amount))
	for amount in [0.50,0.80]: _check(Drink.pour_factor(amount) == 0.5, "倒量15%边界："+str(amount))
	for amount in [0.49,0.81,1.01]: _check(Drink.pour_factor(amount) == 0, "严重偏差或溢出："+str(amount))
	for cold in [0.0,2.999,3.0,5.999,6.0,8.999,9.0]:
		_check(Drink.grade({"cold":cold}) == mini(3,int(cold/3)), "冰度边界："+str(cold))
	_make_cup()
	_check(not Drink.finish(sm,0.9).success and Drink.snapshot(sm).held.amount == 0.65, "结束不能补倒")
	_food()
	_check(sm.deliver_restaurant_customer("restaurant_1").success, "先上料理")
	_check(sm.restaurant_customer_order("restaurant_1").phase == "waiting", "只交料理不能离场")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Drink.deliver(sm,"restaurant_1").success and sm.data == before, "饮料交付保存失败全量回滚")
	sm._active_save_path = path
	var gold: int = sm.gold_balance()
	_check(Drink.deliver(sm,"restaurant_1").gold == 7 and sm.gold_balance() == gold+7, "基础5金币与最高2金币小费")
	_check(sm.restaurant_customer_order("restaurant_1").phase == "eating", "两项完成才开始进食")
	sm.load_data()
	_check(sm.restaurant_customer_order("restaurant_1").drink_done and Drink.snapshot(sm).held.is_empty(), "重载保留完成与空手")
	_make_cup()
	gold = sm.gold_balance()
	_check(not Drink.deliver(sm,"restaurant_1").success and sm.gold_balance() == gold, "重复交付不发奖")
	_prepare_drink()
	_make_cup(0.76)
	_check(Drink.slot(sm,0).success, "放入杯位")
	Drink.tick(sm,6.0)
	_check(Drink.slot(sm,0).success and Drink.grade(Drink.snapshot(sm).held) == 2, "取出锁定中冰")
	Drink.tick(sm,20)
	_check(Drink.grade(Drink.snapshot(sm).held) == 2, "手持冰度不再变化")
	var result := Drink.deliver(sm,"restaurant_1")
	_check(result.success and result.gold == 6, "倒量半档与冰度半档取较差，不相乘")
	_check(sm.restaurant_customer_order("restaurant_1").phase == "waiting", "先交饮料保留料理需求")
	_food()
	_check(sm.deliver_restaurant_customer("restaurant_1").success and sm.restaurant_customer_order("restaurant_1").phase == "eating", "反向交付也正确完成")
	_prepare_drink()
	_make_cup(1.1)
	var rep: int = sm.reputation()
	_check(Drink.deliver(sm,"restaurant_1").gold == 5 and sm.reputation() == rep, "溢出只失去小费，不扣声望")
	_make_cup(0)
	_check(not Drink.deliver(sm,"restaurant_1").success, "空杯禁止交付")
	_check(Drink.discard(sm).success, "空杯可以丢弃")
	for i in 3:
		_make_cup()
		_check(Drink.slot(sm,i).success,"三个杯位独立放入")
	Drink.tick(sm,25)
	_check(Drink.snapshot(sm).slots.all(func(cup): return Drink.grade(cup)==3),"最多三格")
	sm.save()
	sm.load_data()
	_check(Drink.snapshot(sm).slots.all(func(cup): return Drink.grade(cup)==3),"重载恢复三个杯位")
	var state := Drink.snapshot(sm)
	state.slots[0].cold = -1
	_check(not Drink.commit(sm,state).success,"拒绝损坏冰度")
	# 事务失败与重载不能复制杯子、清空占位或改变锁定的倒量。
	_prepare_drink()
	before = sm.data.duplicate(true)
	path = sm._active_save_path
	sm._active_save_path = ""
	_check(not Drink.begin(sm).success and sm.data == before,"准备杯子保存失败回滚")
	sm._active_save_path = path
	_check(Drink.begin(sm).success,"准备空杯")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Drink.finish(sm,0.65).success and sm.data == before,"结束倒水保存失败回滚")
	sm._active_save_path = path
	_check(Drink.finish(sm,0.65).success,"仅重试保存原结果")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Drink.slot(sm,0).success and sm.data == before,"放杯保存失败回滚")
	sm._active_save_path = path
	_check(Drink.slot(sm,0).success,"失败后仍可放同一杯")
	Drink.tick(sm,4.0)
	sm.save()
	sm.load_data()
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==1,"冰镇中重载恢复已到冰度")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Drink.slot(sm,0).success and sm.data == before,"取杯保存失败回滚")
	sm._active_save_path = path
	_check(Drink.slot(sm,0).success,"恢复后取出")
	sm.load_data()
	_check(Drink.grade(Drink.snapshot(sm).held)==1 and Drink.snapshot(sm).slots[0].is_empty(),"持杯重载不会复制")
	# 与原料理保鲜独立，继续由已有经营事务处理。
	_food()
	_check(sm.freezer_action("store",0,"slime_candy",3).success,"原料理保鲜仍可存入")
	var batch: Dictionary = sm.freezer_snapshot().stored[0]
	_check(sm.freezer_action("withdraw",int(batch.id)).success,"原料理保鲜仍可取出")
	# 旧顾客没有饮料字段，仍按原交付完成。
	_prepare_drink()
	for field in ["drink_ice","drink_done","food_done"]: sm.data.restaurant_customers.seated[0].erase(field)
	_food()
	_check(sm.deliver_restaurant_customer("restaurant_1").success and sm.restaurant_customer_order("restaurant_1").phase=="eating","旧订单不补需求")

func _game_flow() -> void:
	_prepare_drink()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var player = scene.get_node("Player")
	var cart = scene.get_node("InteractPoints/FoodCart")
	var fridge = scene.get_node("InteractPoints/Fridge")
	var bar = scene.get_node("InteractPoints/BarCounter")
	var flow = hud.customer_flow
	flow._sync()
	var bubble = flow.actors["restaurant_1"].get_node("OrderBubble")
	_check(bubble.drink and bubble.food and bubble.ice == 1, "真实顾客上饮料下料理双气泡")
	player.global_position = _stand(bar)
	await get_tree().create_timer(0.8).timeout
	await _capture_image("two_bubbles")
	player.global_position = _stand(cart)
	await _send_key(KEY_E)
	var modal = hud.ganlu.modal
	_check(modal.visible and player.input_locked, "真实E打开倒水窗并锁移动")
	await _key_hold(KEY_SPACE,true)
	await get_tree().create_timer(2.9).timeout
	await _capture_image("pouring")
	await _key_hold(KEY_SPACE,false)
	var amount: float = modal.amount
	_check(modal.finished and modal.committed, "松手立即判定并保存")
	await _send_key(KEY_SPACE)
	_check(modal.amount == amount and not modal.hold.visible, "再按空格不能续倒")
	await _click(modal.take)
	_check(not modal.visible and not player.input_locked, "端起恢复移动")
	player.global_position = _stand(fridge)
	await _send_key(KEY_E)
	_check(not Drink.snapshot(sm).slots[0].is_empty() and not hud.freezer.visible, "真实E直接放杯，无冰镇弹窗")
	await get_tree().create_timer(3.1).timeout
	await _capture_image("chilling")
	await _send_key(KEY_E)
	_check(Drink.grade(Drink.snapshot(sm).held)==1,"真实等待后取出少冰")
	player.global_position = _stand(bar)
	await _send_key(KEY_E)
	_check(sm.restaurant_customer_order("restaurant_1").drink_done and not bubble.drink and bubble.food,"真实交付饮料，仅移除上方气泡")
	await _capture_image("food_remaining")
	player.global_position = _stand(cart)
	await _send_key(KEY_E)
	await _send_key(KEY_ESCAPE)
	_check(not player.input_locked and Drink.snapshot(sm).held.is_empty(),"未倒水关闭不生成杯子")
	await _send_key(KEY_E)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = modal.hold.get_global_rect().get_center()
	get_viewport().push_input(mouse)
	await get_tree().create_timer(0.25).timeout
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = false
	mouse.position = Vector2(10,10)
	get_viewport().push_input(mouse)
	await get_tree().process_frame
	_check(modal.finished and modal.committed,"鼠标移出按钮后松手也结束")
	await _click(modal.take)
	var trash = scene.get_node("InteractPoints/TrashBin")
	player.global_position = _stand(trash)
	await _send_key(KEY_E)
	_check(hud.ganlu.discard_modal.visible,"甘露水复用垃圾桶确认框")
	await _click(hud.ganlu.discard_modal.confirm_button)
	_check(Drink.snapshot(sm).held.is_empty() and not player.input_locked,"丢弃后恢复输入")
	player.global_position = _stand(fridge)
	_make_cup()
	await get_tree().create_timer(0.5).timeout
	await _world_click(hud.ganlu.freezer_view.buttons[1])
	_check(not Drink.snapshot(sm).slots[1].is_empty(),"鼠标可指定第二杯位放入")
	player.global_position = _stand(cart)
	var snapshot: Dictionary = Drink.snapshot(sm)
	hud.ganlu.use_slot(1)
	_check(Drink.snapshot(sm).held.is_empty() and not snapshot.slots[1].is_empty(),"远处不能取冰柜杯子")
	player.global_position = _stand(fridge)
	await get_tree().create_timer(0.5).timeout
	await _world_click(hud.ganlu.freezer_view.buttons[1])
	_check(not Drink.snapshot(sm).held.is_empty(),"鼠标可取指定杯位")
	Drink.discard(sm)
	player.global_position = _stand(bar)
	_food()
	await _send_key(KEY_E)
	_check(sm.restaurant_customer_order("restaurant_1").phase=="eating", "真实吧台交菜后进入进食")
	# 料理冰柜保留可操作入口与确认/关闭恢复。
	player.global_position = _stand(fridge)
	await get_tree().create_timer(0.8).timeout
	await _world_click(hud.ganlu.freezer_view.food_button)
	_check(hud.freezer.visible and player.input_locked,"料理保鲜入口仍可打开")
	hud.freezer.dismiss()
	_check(not player.input_locked,"料理冰柜关闭恢复输入")
	await _capture_image("freezer_slots")
	scene.queue_free()
	await get_tree().process_frame

func _key_hold(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	get_viewport().push_input(event)
	await get_tree().process_frame

func _world_click(button: Control) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
