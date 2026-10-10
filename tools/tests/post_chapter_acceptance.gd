extends "res://tools/tests/chapter_ending_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_data_cases()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _reputation_reveal()
			await _interactions()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("POST_CHAPTER ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _completed() -> void:
	_seed()
	for checkpoint in ["party","home","maze","title"]:
		_check(sm.advance_chapter_1_outro(checkpoint).success,"完章前置："+checkpoint)

func _data_cases() -> void:
	for quality in [1,2,3]:
		sm.data = sm._defaults()
		sm._active_save_path = "user://post-chapter.json"
		_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success,"首单接单取货")
		_check(sm.start_first_order_cooking().success and sm.finish_first_order_cooking(quality).success,"制作实际星级")
		sm.data.reputation = 123
		var before: Dictionary = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check(not sm.deliver_first_order().success and sm.data == before,"上菜写盘失败完整回滚")
		sm._active_save_path = "user://post-chapter.json"
		var reward: int = {1:60,2:80,3:100}[quality]
		_check(sm.deliver_first_order().success and sm.reputation() == 123 + reward,"实际星级奖励累计：%d" % quality)
		_check(not sm.deliver_first_order().success and sm.reputation() == 123 + reward,"重复上菜不重奖")
		sm.load_data()
		_check(sm.has_first_order_settlement() and sm.reputation() == 123 + reward,"JSON重载保留星级凭证")
		sm.data.first_order_settlement.reputation_awarded = {1:10,2:12,3:15}[quality]
		sm.data.reputation = {1:10,2:12,3:15}[quality]
		_check(sm.save(),"保存旧星级凭证")
		sm.load_data()
		_check(sm.has_first_order_settlement() and sm.reputation() == int({1:10,2:12,3:15}[quality]),"旧星级凭证不补发：%d" % quality)
	_completed()
	sm.data.erase("warehouse_stock")
	sm.data.first_order_settlement.reputation_awarded = 10
	sm.data.reputation = 10
	_check(sm.save(),"写入历史旧奖励/无仓库字段样例")
	sm.load_data()
	_check(sm.warehouse_snapshot().rockmane_meat == 0 and sm.warehouse_snapshot().rock_salt == 0,"已取货旧档不凭空补货")
	_check(sm.has_first_order_settlement() and sm.reputation() == 10 and sm.is_chapter_1_complete(),"旧奖励凭证不失效不补奖")
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.register_customer_order("fail",sm.FIRST_ORDER_ITEM_ID).success and sm.data == before,"顾客登记失败回滚")
	sm._active_save_path = "user://post-chapter.json"
	sm.data.waiting_customer_orders = [null,{"id":7},{"id":"bad","item_id":sm.FIRST_ORDER_ITEM_ID}]
	_check(sm.waiting_customer_orders().is_empty(),"损坏候单记录不接受")
	sm.data.warehouse_stock = {"rockmane_meat":3,"rock_salt":4}
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.take_warehouse_items({"rockmane_meat":2}).success and sm.data == before,"取货写盘失败完整回滚")
	sm._active_save_path = "user://post-chapter.json"
	_check(not sm.take_warehouse_items({"rockmane_meat":4}).success,"超库存取货拒绝")
	_check(sm.take_warehouse_items({"rockmane_meat":2,"rock_salt":2}).success,"多种多份转移成功")
	sm.load_data()
	_check(sm.warehouse_snapshot().rockmane_meat == 1 and sm.inventory_quantity("rockmane_meat") == 2 and sm.is_chapter_1_complete(),"转移持久化且完章不倒退")
	_check(sm.register_customer_order("follow-1",sm.FIRST_ORDER_ITEM_ID).success and sm.accept_waiting_customer_order().success,"真实候单登记与接受")
	_check(not sm.register_customer_order("follow-1",sm.FIRST_ORDER_ITEM_ID).success,"订单ID不重复登记")
	_check(sm.quest_snapshot().active.any(func(q): return q.id == "customer_order:follow-1" and q.unread),"后续订单任务与红点")
	_check(sm.start_cooking(sm.FIRST_ORDER_ITEM_ID).success,"后续订单烹饪可开始")
	sm.load_data()
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1 and sm.cooking_state().quality == 1,"中断烹饪恢复一份一星成品")
	_check(sm.first_order_progress().next_step == "chapter_wrap_up", "后续烹饪恢复不覆盖首章完成进度")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.deliver_customer_order().success and sm.data == before,"后续交付写盘失败全量回滚")
	sm._active_save_path = "user://post-chapter.json"
	_check(sm.deliver_customer_order().success and sm.reputation() == 70,"后续上菜累计声望")
	_check(not sm.deliver_customer_order().success and sm.reputation() == 70,"后续重复上菜不重奖")
	sm.load_data()
	_check(sm.is_chapter_1_complete() and sm.chapter_1_outro_state() == "done", "新订单读档不重播第一章")
	_check(sm.quest_snapshot().archived.any(func(q): return q.id == "customer_order:follow-1"),"后续任务只本地归档")
	_check(sm.register_customer_order("follow-2",sm.FIRST_ORDER_ITEM_ID).success,"第二位顾客登记")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.accept_waiting_customer_order().success and sm.data == before,"后续接单失败不丢候单")
	sm._active_save_path = "user://post-chapter.json"
	_check(sm.accept_waiting_customer_order().success,"接单失败可重试")

func _use(node_path: String) -> void:
	var target: Node2D = scene.get_node(node_path)
	var player: Node2D = scene.get_node("Player")
	player.global_position = _stand(target)
	await get_tree().physics_frame
	_check(player.nearest_interactable() == target, "最近交互目标："+node_path)
	await _send_key(KEY_E)
	await get_tree().process_frame

func _reputation_reveal() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://reputation-reveal.json"
	_check(sm.save(), "声望展示初始化隔离存档")
	await _open_scene()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.reputation_label.visible, "第一章苏醒时隐藏声望")
	await _shot("reputation_hidden_opening")
	sm.data.reputation = 123
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not hud.reputation_label.visible, "未给铁山上菜即使有声望也不展示")
	await _close_scene()
	sm.data.reputation = 0
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success, "准备真实首单待上菜")
	await _open_scene()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.reputation_label.visible, "料理完成未上菜仍隐藏声望")
	sm._active_save_path = ""
	await _use("InteractPoints/BarCounter")
	_check(not hud.reputation_label.visible and not sm.has_first_order_settlement(), "上菜保存失败不会提前显示声望")
	sm._active_save_path = "user://reputation-reveal.json"
	await _use("InteractPoints/BarCounter")
	await get_tree().process_frame
	_check(sm.has_first_order_settlement() and hud.reputation_label.visible and hud.reputation_label.text == "声望：60", "真实E首次上菜后显示实际声望")
	await _shot("reputation_first_served")
	await _close_scene()
	sm.load_data()
	await _open_scene()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.reputation_label.visible and hud.reputation_label.text == "声望：60", "上菜后读档恢复声望展示")
	await _close_scene()

func _interactions() -> void:
	_completed()
	await _open_scene()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var player = scene.get_node("Player")
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	var tracker = scene.get_node("UIOverlay/OrderTracking")
	_check(not tm.active,"完章后不重启教学")
	_check(hud.reputation_label.visible and hud.reputation_label.text == "声望：60","HUD显示实际累计值")
	_check(hud.reputation_label.get_global_rect().position.x < 50 and hud.reputation_label.get_global_rect().position.y < 50,"声望固定左上角")
	await _use("InteractPoints/Register")
	_check(hud.toast_label.visible and hud.toast_label.text == "当前暂无订单，请等待顾客上门","无顾客E点单反馈")
	_shot("no_order")
	await _use("InteractPoints/BarCounter")
	_check(hud.toast_label.text == "当前暂无用餐需求，请先接单","无需求E上菜反馈")
	await _use("InteractPoints/Store")
	_check(warehouse.visible and warehouse._message.text == "没有任何食物" and player.input_locked,"E打开空仓库且锁住移动")
	_shot("empty_warehouse")
	await _click(warehouse._cancel_button)
	_check(not warehouse.visible and not player.input_locked,"空仓库确认释放输入")
	sm.data.warehouse_stock = {"rockmane_meat":4,"rock_salt":3}
	await _use("InteractPoints/Store")
	_check(warehouse._meat_slot._quantity == 4 and warehouse._salt_slot._quantity == 3,"真实仓库数量")
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._salt_slot._icon_button)
	_shot("warehouse_selection")
	await _click(warehouse._claim_button)
	_check(sm.inventory_quantity("rockmane_meat") == 2 and sm.inventory_quantity("rock_salt") == 1 and sm.warehouse_snapshot().rockmane_meat == 2,"鼠标多种多份取货")
	_check(not player.input_locked,"取货完成释放输入")
	var card_panel = get_tree().get_first_node_in_group("departure_panel")
	card_panel.open_task_cards()
	_check(card_panel._cards_open(),"章后有携带物品仍可查看卡组")
	card_panel._close_cards()
	for display in ["冰柜","小餐车"]:
		var target = get_tree().get_nodes_in_group("interactable").filter(func(n): return str(n.get("display_name")) == display)[0]
		var threshold: int = 2000 if display == "冰柜" else 5000
		sm.data.reputation = threshold - 1
		await _use(str(scene.get_path_to(target)))
		_check("暂未解锁" in hud.toast_label.text,"待设计功能门槛前仍锁定："+display)
		sm.data.reputation = threshold
		await _use(str(scene.get_path_to(target)))
		_check("暂未解锁" in hud.toast_label.text,"待设计功能达到旧门槛仍锁定："+display)
	sm.data.reputation = 60
	for dest in ["InteractPoints/AdventurerHomeDoor","DepartureEntrance"]:
		await _use(dest)
		_check(hud.confirmation.visible and player.input_locked,"一次E只打开二次确认："+dest)
		var repeat := InputEventKey.new()
		repeat.keycode = KEY_E
		repeat.pressed = true
		repeat.echo = true
		get_viewport().push_input(repeat)
		await get_tree().process_frame
		_check(hud.confirmation.visible,"E重复事件不能确认")
		await _send_key(KEY_E)
		if dest == "DepartureEntrance":
			var departure = get_tree().get_first_node_in_group("departure_panel")
			_check(departure._open and player.input_locked,"新E确认打开地图且锁定")
			departure.close_map()
		else:
			_check(not hud.confirmation.visible and not player.input_locked and "暂未开放" in hud.toast_label.text,"确认未开放入口不假跳场景")
		await _use(dest)
		_shot("confirm_"+dest.get_file())
		await _send_key(KEY_ESCAPE)
		_check(not hud.confirmation.visible and not player.input_locked,"取消确认恢复输入")
		await _use(dest)
		await _send_key(KEY_ENTER)
		_check(not hud.confirmation.visible and not player.input_locked,"Enter尊重默认取消焦点")
	_check(sm.register_customer_order("gui"+suffix,sm.FIRST_ORDER_ITEM_ID).success,"登记可接待顾客")
	await _use("InteractPoints/Register")
	_check(sm.has_active_order(),"真实E接受新订单")
	await _click(tracker._task_button)
	_check(tracker._order_main.visible and not sm.has_unread_quests(),"进行中订单可查看并清红点")
	await get_tree().create_timer(0.5).timeout
	_shot("active_order")
	await _use("InteractPoints/Cauldron")
	var cooking = scene.get_node("HUD/CookingModal")
	_check(cooking.visible and player.input_locked,"章后E开锅")
	await _click(cooking._start_button)
	_check(sm.cooking_state().status == "active","鼠标开始QTE扣料")
	await _click(cooking._finish_button)
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1,"章后QTE生成料理")
	await get_tree().create_timer(1.4).timeout
	await _send_key(KEY_E)
	_check(not player.input_locked,"料理结果确认恢复移动")
	var stars: int = sm.cooked_quality()
	await _use("InteractPoints/BarCounter")
	_check(sm.reputation() == 60 + int({1:60,2:80,3:100}[stars]),"真实E交付后累计")
	await get_tree().process_frame
	_check(hud.reputation_label.text == "声望：%d" % sm.reputation(),"HUD立即同步交付奖励")
	_shot("reputation_after_delivery")
	await _close_scene()
