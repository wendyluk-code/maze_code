extends "res://tools/tests/restaurant_rest05b.gd"
const People := preload("res://scripts/restaurant/customer_catalog.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	for index in range(18):
		_fresh()
		sm.data.restaurant_customers.serial = index
		sm.data["ganlu_lessons_v1"] = {"warm":true,"iced":true,"ready":true,"spoiled":true}
		_open({A:2})
		var hud = await _open_restaurant()
		var player = hud._player
		sm.data[Day.KEY].arrival_left = 0.0
		await _wait_until(func(): return sm.restaurant_customers().front.get("phase")=="front",150)
		var order: Dictionary = sm.restaurant_customers().front
		_check(order.get("customer_id")==People.ROTATION[index],"实际到店身份 "+People.ROTATION[index])
		if order.is_empty():
			await _close_restaurant()
			continue
		var id: String = order.id
		player.position = _stand(scene.get_node("InteractPoints/Register"))
		player.last_valid = player.position
		await _send_key(KEY_E)
		await _wait_until(func(): return sm.restaurant_customer_order(id).get("phase")=="waiting",150)
		_check(sm.restaurant_customer_order(id).get("phase")=="waiting","真实E接单落座 "+order.customer_id)
		_stage(id,"food",100)
		_cook(A)
		player.position = Three.service_point(int(sm.restaurant_customer_order(id).seat))
		player.last_valid = player.position
		await _send_key(KEY_E)
		_check(sm.restaurant_customer_order(id).get("outcome")=="served","真实E交菜 "+order.customer_id)
		await _wait_until(func(): return sm.restaurant_customer_order(id).is_empty(),240)
		_check(sm.restaurant_customer_order(id).is_empty(),"进食后渐隐离场 "+order.customer_id)
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
