extends "res://tools/tests/restaurant_rest05b.gd"
const People := preload("res://scripts/restaurant/customer_catalog.gd")
const Feedback := preload("res://scripts/ui/components/customer_feedback.gd")
const Faces := preload("res://scripts/ui/components/customer_expression.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"正式存档隔离")
	var start := int(_arg("--mode="))*9
	for index in range(start,start+9):
		for reason in Feedback.ROWS:
			await _case(index,reason)
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _case(index: int, reason: String) -> void:
	_fresh()
	sm.data.restaurant_customers.serial = index
	sm.data["ganlu_lessons_v1"] = {"warm":true,"iced":true,"ready":true,"spoiled":true}
	_open({A:3})
	var order := _order(reason!="front_timeout")
	var id: String = order.id
	var tag: String = People.ROTATION[index]+"/"+reason
	_check(order.customer_id==People.ROTATION[index],tag+" 身份")
	var hud = await _open_restaurant()
	var flow = hud.customer_flow
	flow.set_process(false)
	flow._sync()
	var actor: Sprite2D = flow.actors[id]
	await get_tree().create_timer(0.4).timeout
	var origin := actor.position
	var camera := get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.global_position = actor.global_position+Vector2(0,110)
	camera.reset_smoothing()
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	if reason in ["question","bad_drink","spoiled_drink"]:
		if reason!="question": _stage(id,"drink",100)
		_check(Drink.begin(sm).success and Drink.finish(sm,0.65).success,tag+" 倒水事务")
		if reason=="spoiled_drink":
			_check(Drink.slot(sm,0).success,tag+" 放入冰柜")
			Drink.tick(sm,9.0)
			_check(Drink.slot(sm,0).success,tag+" 取出过冰水")
		_check(hud.ganlu.serve(id),tag+" 实际交水控制器")
	elif reason=="wrong_dish":
		_cook(B)
		_check(sm.deliver_restaurant_customer(id).get("outcome")==reason,tag+" 实际错菜事务")
	else:
		if reason=="front_timeout": sm.data.restaurant_customers.front.remaining = 0.01
		else: _stage(id,"drink" if reason=="drink_timeout" else "food",0.01)
		_check(Cycle.tick(sm,0.02).success,tag+" 实际计时超时")
	flow._sync()
	await get_tree().process_frame
	var node = actor.get_node_or_null("CustomerFeedback")
	var face = actor.get_node_or_null("CustomerExpression")
	_check(node!=null and face!=null,tag+" 表情和反馈已出现")
	if node==null or face==null:
		await _close_restaurant()
		return
	_check(face.emotion==Faces.NAMES.find(Feedback.ROWS[reason][1]),tag+" 眉嘴状态")
	_check(node.text_bubble.message==Feedback.ROWS[reason][0],tag+" 文案")
	var mark = node.get_child(1)
	_check(mark.kind==Feedback.ROWS[reason][2],tag+" 头顶动效类别")
	_check(node.text_bubble.z_index>actor.get_node("OrderBubble").z_index,tag+" 评价层级")
	_check(not actor.get_node("OrderBubble").visible,tag+" 隐藏自身订单气泡")
	var elapsed: float = mark.elapsed
	await _emotion_capture(tag.replace("/","_")+"_a")
	await get_tree().create_timer(0.18).timeout
	_check(mark.elapsed>elapsed,tag+" 动画时间推进")
	await _emotion_capture(tag.replace("/","_")+"_b")
	var expected := Vector2i(-2,-1)
	if reason=="question": expected = Vector2i.ZERO
	elif reason=="bad_drink": expected = Vector2i(-1,0)
	elif reason=="wrong_dish": expected = Vector2i(-2,0)
	elif reason=="front_timeout": expected = Vector2i(-1,-1)
	_check(Vector2i(sm.gold_balance()-gold,sm.reputation()-rep)==expected,tag+" 奖惩仅一次")
	var leaving: bool = reason not in ["question","bad_drink"]
	_check(sm.restaurant_customer_order(id).phase==("leaving" if leaving else "waiting"),tag+" 业务阶段")
	var faded := false
	var stationary := true
	for frame in range(180):
		await get_tree().process_frame
		flow._sync()
		if not is_instance_valid(actor): break
		stationary = stationary and actor.position.distance_to(origin)<0.1
		if actor.modulate.a>0.05 and actor.modulate.a<0.95: faded = true
		if not leaving and not actor.has_node("CustomerFeedback"): break
	if leaving:
		_check(faded and stationary and not flow.actors.has(id),tag+" 原地渐隐离场")
	else:
		_check(not actor.has_node("CustomerFeedback") and not actor.has_node("CustomerExpression") and actor.get_node("OrderBubble").visible,tag+" 表情清理及订单恢复")
	_check(Vector2i(sm.gold_balance()-gold,sm.reputation()-rep)==expected,tag+" 动画后不重复奖惩")
	await _close_restaurant()

func _emotion_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(evidence.path_join(label+".png"))

