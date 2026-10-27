extends "res://tools/tests/npc_01_scene.gd"
func run() -> void:
	sm = get_node("/root/SaveManager")
	sm.data = sm._defaults()
	sm._active_save_path = "res://output/day1_03/tieshan_bubble.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	check(sm.accept_first_order().success, "铁山真实接单")
	await reopen()
	var tm = get_node("/root/TutorialManager")
	tm.start()
	await pause(0.5)
	var guest = tm._parked_guest
	check(is_instance_valid(guest), "教程恢复铁山")
	if not is_instance_valid(guest):
		get_tree().quit(1)
		return
	check(guest.get_node("OrderBubble").visible, "读档等餐显示气泡")
	check(guest.get_node("OrderBubble").item_id == "salt_grilled_rockmane", "显示盐烤岩鬃肉")
	# 收起当前说明仅用于全景证据，经营与人物状态不变。
	tm.guide.hide_box()
	var camera = get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.global_position = Vector2(780,380)
	camera.zoom = Vector2(0.85,0.85)
	camera.reset_smoothing()
	await shot("tieshan_order_bubble")
	guest.settle_prone()
	check(not guest.get_node("OrderBubble").visible, "倒地不显示")
	guest.play_seating()
	await pause(5.0)
	check(guest.seating_completed and guest.get_node("OrderBubble").visible, "真实入座动画后显示")
	check(not sm.deliver_first_order().success, "缺少成品拒绝交单")
	await pause(0.1)
	check(guest.get_node("OrderBubble").visible, "交单失败气泡保留")
	check(sm.claim_first_order_ingredients().success and sm.cook_first_order().success, "真实取料制作")
	check(sm.deliver_first_order().success, "真实交单结算")
	await pause(0.1)
	check(not guest.get_node("OrderBubble").visible, "结算后自动隐藏")
	guest.on_order_served()
	await pause(1.6)
	check(guest.satisfied_completed and not guest.get_node("OrderBubble").visible, "餐后动画不再显示")
	await reopen()
	tm.start()
	await pause(0.5)
	guest = tm._parked_guest
	check(is_instance_valid(guest) and not guest.get_node("OrderBubble").visible, "完成后读档不恢复气泡")
	print("TIESHAN_BUBBLE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)

