extends "res://tools/tests/restaurant_service_cycle.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离")
	_seed_cycle()
	var order := _arrive()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.customer_flow
	var actor: Sprite2D = flow.actors[order.id]
	var camera := get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.global_position = actor.global_position + Vector2(250,110)
	camera.reset_smoothing()
	for reason in ["front_timeout","drink_timeout","timeout","wrong_dish","bad_drink","question"]:
		flow.show_feedback(order.id,reason)
		flow._sync()
		await get_tree().create_timer(0.25).timeout
		_check(actor.has_node("CustomerFeedback") and actor.has_node("CustomerExpression"),"真实餐厅表情与动效："+reason)
		_check(not actor.get_node("OrderBubble").visible,"反馈替代订单气泡")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_arg("--output-dir=").path_join(reason+".png"))
	await get_tree().create_timer(2.5).timeout
	_check(not actor.has_node("CustomerFeedback") and actor.get_node("OrderBubble").visible,"反馈结束恢复订单")
	_stage(order.id,"food",0.01)
	await get_tree().create_timer(0.4).timeout
	_check(sm.restaurant_customer_order(order.id).phase=="leaving" and actor.has_node("CustomerFeedback"),"真实超时先展示反馈")
	await get_tree().create_timer(3.0).timeout
	_check(not flow.actors.has(order.id),"反馈后完成离场")
	scene.queue_free()
	await get_tree().process_frame
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
