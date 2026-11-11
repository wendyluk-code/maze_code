extends "res://tools/tests/restaurant_rest05b.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_fresh()
		_open({A:2})
		var order := _order()
		_cook(A,false)
		_rollback(func(): return sm.finish_first_order_cooking(3),"出锅实物与归属保存失败回滚")
		_check(sm.finish_first_order_cooking(3).success,"出锅失败后可重试")
		_rollback(func(): return sm.deliver_restaurant_customer(order.id),"上菜扣物奖励订单份额全量回滚")
		_rollback(func(): return sm.discard_carried_food(sm.discardable_carried_items()),"手持丢弃损耗与份额全量回滚")
		_check(sm.freezer_action("store",0,A,3).success,"冷藏保存成功")
		var id: int = sm.freezer_snapshot().stored[0].id
		_rollback(func(): return sm.freezer_action("withdraw",id),"冷藏取出来源迁移全量回滚")
		_rollback(func(): return sm.freezer_action("discard",id),"冷藏丢弃损耗来源全量回滚")
		_check(sm.freezer_action("withdraw",id).success and sm.deliver_restaurant_customer(order.id).success,"失败后取出上菜可重试")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
