extends "res://tools/tests/restaurant_rest05b.gd"
const Feedback := preload("res://scripts/ui/components/customer_feedback.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_fresh()
	_open({B:3})
	var orders := [_order(),_order(),_order()]
	var hud = await _open_restaurant()
	var flow = hud.customer_flow
	flow.set_process(false)
	flow._sync()
	var camera := get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.global_position = flow.actors[orders[1].id].global_position+Vector2(0,110)
	camera.reset_smoothing()
	for reason in ["question","timeout","wrong_dish"]:
		var actor = flow.actors[orders[0].id]
		Feedback.show_on(actor,orders[0].customer_id,reason)
		var feedback = actor.get_node("CustomerFeedback")
		feedback.remaining = 60
		for order in orders.slice(1):
			var other = flow.actors[order.id].get_node("OrderBubble")
			_check(not feedback.text_bubble.z_as_relative and feedback.text_bubble.z_index>other.z_index,"评价气泡优先于其他顾客订单："+reason)
		await _shot("feedback_priority_"+reason)
		Feedback.clear(actor)
		flow._sync()
		_check(actor.get_node("OrderBubble").visible,"反馈结束恢复订单")
	await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
