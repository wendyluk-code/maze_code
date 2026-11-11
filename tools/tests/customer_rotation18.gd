extends "res://tools/tests/restaurant_rest05b.gd"
const People := preload("res://scripts/restaurant/customer_catalog.gd")
const Face := preload("res://scripts/ui/components/customer_expression.gd")
const Feedback := preload("res://scripts/ui/components/customer_feedback.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_fresh()
	_open({B:3})
	var seen: Array = []
	for i in range(20):
		if i==9:
			_check(Cycle.settle(sm,"manual").success,"跨日结算")
			_check(Cycle.acknowledge_settlement(sm).success,"进入次日")
			sm.data[Day.KEY].erase("preparation_lesson_pending")
			_open({B:1})
		var order := _order()
		_check(order.customer_id==People.ROTATION[i%18],"来客顺序 %d" % (i+1))
		seen.append(order.customer_id)
		_check(sm.save(),"保存当前顾客")
		sm.load_data()
		_check(sm.restaurant_customer_order(order.id).customer_id==order.customer_id,"读档保留人物身份")
		_stage(order.id,"food",0.01)
		_check(Cycle.tick(sm,0.02).success,"该角色超时事务可执行")
		_depart(order.id)
	_check(seen.slice(0,18).size()==18 and seen[18]==seen[0] and seen[19]==seen[1],"18人后循环")
	sm.data[Day.KEY].arrival_left = 0.0
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Cycle.arrive(sm).success and sm.data==before,"来客保存失败不跳号")
	sm._active_save_path = path
	_check(Cycle.arrive(sm).order.customer_id==People.ROTATION[2],"失败重试继续同一人")
	for old in ["mage","dingdang","half_elf"]:
		_check(not People.customer(old).is_empty(),"旧身份继续兼容："+old)
	await _visual_roster()
	await _tieshan_preserved()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)

func _visual_roster() -> void:
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		for batch in range(6):
			_fresh()
			_open({B:3})
			var orders := [_order(),_order(),_order()]
			for j in range(3): sm.data.restaurant_customers.seated[j].customer_id = People.ROTATION[batch*3+j]
			var hud = await _open_restaurant()
			var flow = hud.customer_flow
			flow.set_process(false)
			flow._sync()
			var camera := get_viewport().get_camera_2d()
			camera.set_process(false)
			camera.set_physics_process(false)
			camera.global_position = flow.actors[orders[1].id].global_position+Vector2(0,110)
			camera.reset_smoothing()
			await _shot("roster_%d" % batch)
			for j in range(3):
				var id: String = People.ROTATION[batch*3+j]
				var actor = flow.actors[orders[j].id]
				for row in range(4):
					for col in range(4):
						flow._frame(actor,id,row,col)
						_check(actor.texture.get_image().get_used_rect().has_area(),"动作帧有效 %s/%d/%d" % [id,row,col])
				flow._frame(actor,id,1,0)
				Feedback.show_on(actor,id,"question")
				actor.get_node("CustomerFeedback").remaining = 60
				_check(actor.has_node("CustomerExpression"),"共用表情适配："+id)
			await _shot("expressions_%d" % batch)
			await _close_restaurant()
