extends "res://tools/tests/restaurant_rest05b.gd"
const Feedback := preload("res://scripts/ui/components/customer_feedback.gd")
const Head := preload("res://scripts/ui/components/customer_head_anchor.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		for customer in ["mage","dingdang","half_elf"]:
			for front in [true,false]: await _anchors(customer,front)
	await _tieshan_preserved()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _anchors(customer: String, front: bool) -> void:
	_fresh()
	_open({A:2})
	var order := _order(not front)
	if front: sm.data.restaurant_customers.front.customer_id = customer
	else: sm.data.restaurant_customers.seated[0].customer_id = customer
	var hud = await _open_restaurant()
	var flow = hud.customer_flow
	flow.set_process(false)
	flow._sync()
	var actor: Sprite2D = flow.actors[order.id]
	var bubble = actor.get_node("OrderBubble")
	var camera := get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.global_position = actor.global_position
	camera.reset_smoothing()
	await get_tree().process_frame
	bubble.follow(actor)
	var expected := actor.get_global_transform_with_canvas()*Head.local_point(actor)
	var tip: Vector2 = bubble.get_global_transform_with_canvas()*Vector2(0,-1)
	_check(absf(tip.x-expected.x)<0.01 and absf(tip.y-expected.y)<2,"点单等餐尖角对齐头顶 "+customer+str(front))
	var label := customer+("_front" if front else "_seat")
	await _shot("anchor_order_"+label)
	Feedback.show_on(actor,customer,"front_timeout" if front else "wrong_dish")
	var feedback = actor.get_node("CustomerFeedback")
	feedback.remaining = 60
	for shift in [Vector2.ZERO,Vector2(260,0),Vector2(-260,0)]:
		camera.global_position = actor.global_position+shift
		camera.reset_smoothing()
		await get_tree().process_frame
		feedback._layout_text()
		expected = actor.get_global_transform_with_canvas()*Head.local_point(actor)
		var feedback_tip: Vector2 = feedback.text_bubble.get_global_transform_with_canvas()*Vector2.ZERO
		_check(feedback_tip.distance_to(expected)<0.01,"避让后反馈尖角仍锁定头顶 "+label+str(shift))
		_check(feedback.text_bubble.position==Vector2.ZERO,"不移动整个反馈节点")
		if shift==Vector2.ZERO: await _shot("anchor_feedback_"+label)
	await _close_restaurant()
