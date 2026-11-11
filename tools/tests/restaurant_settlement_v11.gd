extends "res://tools/tests/restaurant_rest04.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			for count in [0,1,2,6]: await _history_scene(count)
			await _history_scene(2,true)
			await _history_scene(1,false,true)
		_loss_transactions()
		await _tieshan_preserved()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("REST04_V11 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _make_dish(id: String) -> void:
	var prepared: Dictionary = sm.prepared_dishes_snapshot()
	prepared[id]["3"] = int(prepared[id].get("3",0))+1
	sm.data.prepared_dishes = prepared
	sm.data.inventory[id] = sm.inventory_quantity(id)+1

func _loss_transactions() -> void:
	_seed_cycle()
	_make_dish("salt_grilled_rockmane")
	var items: Dictionary = sm.discardable_carried_items()
	_rollback(func(): return sm.discard_carried_food(items),"丢弃保存失败损耗与物品一起回滚")
	_check(sm.discard_carried_food(items).success,"真实丢弃成品")
	_check(Day.snapshot(sm).dish_losses.get("salt_grilled_rockmane",0)==1,"成品丢弃只记录一次")
	_check(not sm.discard_carried_food(items).success and Day.snapshot(sm).dish_losses.get("salt_grilled_rockmane",0)==1,"重复丢弃不重复记损耗")
	var original: Dictionary = Day.snapshot(sm).dish_losses.duplicate(true)
	Day.record_dish_loss(sm.data,{"rock_salt":3,"water":1})
	_check(Day.snapshot(sm).dish_losses==original,"原料及水不计料理损耗")
	_make_dish("salt_grilled_rockmane")
	_check(sm.freezer_action("store",0,"salt_grilled_rockmane",3).success,"冷藏原事务仍可存入")
	_check(Day.snapshot(sm).dish_losses==original,"存入不是销毁不记损耗")
	var unit: Dictionary = sm.freezer_snapshot().stored[0]
	var ledger: Dictionary = sm.freezer_snapshot()
	ledger.stored[0].expires_at = 1
	sm.data[sm.Freezer.KEY] = ledger
	sm.freezer_snapshot()
	_check(sm.freezer_snapshot().stored.size()==1 and Day.snapshot(sm).dish_losses==original,"过期读取不自动销毁也不虚记损耗")
	_rollback(func(): return sm.freezer_action("discard",int(unit.id)),"冷藏成品丢弃保存失败回滚")
	_check(sm.freezer_action("discard",int(unit.id)).success and Day.snapshot(sm).dish_losses.salt_grilled_rockmane==2,"真正丢弃过期料理才记损耗")
	_make_dish("slime_candy")
	_check(sm.freezer_action("discard_carried",0,"slime_candy",3).success and Day.snapshot(sm).dish_losses.slime_candy==1,"逐份手持丢弃真实记账")
	var order := _arrive()
	_stage(order.id,"food",100)
	_make_dish("slime_candy")
	_check(sm.deliver_restaurant_customer(order.id).success,"误送消耗真实成品")
	Cycle.settle(sm,"time")
	_check(Day.snapshot(sm).settlement.losses.slime_candy==2,"结算汇总丢弃及误送不计未做菜单")
	var before: Dictionary = sm.data.duplicate(true)
	Cycle.settle(sm,"time")
	_check(sm.data==before,"重复结算不重复加历史或损耗")
	_rollback(func(): return Cycle.acknowledge_settlement(sm),"跨天保存失败历史及损耗全量回滚")
	Cycle.acknowledge_settlement(sm)
	_check(Day.snapshot(sm).dish_losses.is_empty() and Day.snapshot(sm).history.size()==1,"跨天保留凭证重置当日损耗")
	# 超过六天及缺失日期：只显示含当天最近六个日历日中可证明的记录。
	sm.data[Day.KEY].day = 9
	sm.data[Day.KEY].history = [{"day":1,"income":3,"reputation":1},{"day":4,"income":5,"reputation":-1},{"day":8,"income":8,"reputation":2}]
	sm.data[Day.KEY].erase("last_settlement")
	_check(Day.settlement_history(sm).map(func(e): return int(e.day))==[4,8],"不补未来及缺失日期，裁掉六天之外")

func _history_scene(count: int, loss := false, legacy := false) -> void:
	_seed_cycle()
	_check(Day.settlement_history(sm).is_empty(),"新档没有虚构历史")
	for n in count:
		if n>0: _check(Cycle.open_with_menu(sm,{"salt_grilled_rockmane":1}).success,"次日正常开业")
		var order := _arrive()
		_stage(order.id,"food",100)
		if loss:
			_stage(order.id,"food",0.01)
			Cycle.tick(sm,0.02)
			for id in ["salt_grilled_rockmane","slime_candy","brick_snail_sashimi","lizard_tail_skewer","bird_nest_crab"]:
				if not sm.prepared_dishes_snapshot().has(id): continue
				_make_dish(id)
				sm.discard_carried_food(sm.discardable_carried_items())
		else:
			_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).success,"真实领取一份料理原料")
			_check(sm.start_cooking("salt_grilled_rockmane").success and sm.finish_first_order_cooking(3).success,"真实烹饪成品")
			_check(sm.deliver_restaurant_customer(order.id).success,"真实交付产生本日回执")
		_check(Cycle.settle(sm,"time").success,"结算保存实际每日凭证")
		if n<count-1: _check(Cycle.acknowledge_settlement(sm).success,"确认跨天保存历史")
	if legacy:
		sm.data[Day.KEY].erase("history")
		sm.data[Day.KEY].settlement.erase("losses")
		sm.data[Day.KEY].settlement.erase("losses_known")
		sm.data[Day.KEY].settlement.legacy = true
	sm.save()
	sm.load_data()
	_check(Day.settlement_history(sm).size()==count,"跨读档只保留真实日数%d"%count)
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.4).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var modal: Control
	if count==0:
		modal = preload("res://scripts/ui/components/restaurant_day_settlement.gd").new()
		hud.add_child(modal)
		modal.open({})
	else: modal = hud.day_settlement
	_check(is_instance_valid(modal) and modal.visible,"实际场景显示v11结算")
	if not is_instance_valid(modal): return
	_check(modal.history.size()==count and modal.chart.gold_points.size()==count,"图表无未来占位，节点数匹配真实历史")
	_check(modal._confirm_button.text=="明日准备","复用底部明日准备按钮")
	var rect: Rect2 = modal._panel.get_global_rect()
	_check(rect.position.x>=0 and rect.end.x<=get_viewport().get_visible_rect().size.x and rect.end.y<=get_viewport().get_visible_rect().size.y,"双尺寸结算完整在视口")
	if loss:
		_check(modal.chart.axis_min<0,"负声望共用坐标轴不截断")
		_check(is_instance_valid(modal.loss_scroll),"实际损耗显示独立滚动列表")
		var review_rect: Rect2 = modal.review.get_global_rect()
		modal.loss_scroll.scroll_vertical = 999
		await get_tree().process_frame
		_check(modal.review.get_global_rect()==review_rect,"滚动损耗不移动评价")
	elif legacy:
		_check(modal.review.text.contains("旧存档"),"旧档不假称无损耗或全部售出")
	else:
		_check(not is_instance_valid(modal.loss_scroll),"无损耗隐藏标题列表与分隔，评价居中")
	await _shot("v11_%ddays%s%s" % [count,"_loss" if loss else "","_legacy" if legacy else ""])
	if count>0:
		var gold: int = sm.gold_balance()
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		await _click(modal._confirm_button)
		_check(modal.visible and scene.get_node("Player").input_locked,"v11点击确认保存失败仍锁输入且可重试")
		sm._active_save_path = path
		await _click(modal._confirm_button)
		_check(not modal.visible and not scene.get_node("Player").input_locked,"v11真实点击明日准备跨天恢复输入")
		_check(sm.gold_balance()==gold and not Cycle.acknowledge_settlement(sm).success,"确认不重发钱、不重复跨天")
	scene.queue_free()
	await get_tree().process_frame
