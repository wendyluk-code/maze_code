extends "res://tools/tests/npc_01_scene.gd"

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	sm.data.capture_first_visit_started = true
	# 三席兼容存档夹具；不改变生产来客门槛。
	for i in 3:
		var row: Dictionary = sm.CustomerCatalog.CUSTOMERS[i]
		sm.data.restaurant_customers.serial = i + 1
		sm.data.restaurant_customers.front = {"id":"restaurant_%d" % (i+1), "customer_id":row.id, "item_id":row.recipe, "item_name":sm.RecipeCatalog.get_recipe(row.recipe).name, "quantity":1, "phase":"front", "seat":-1}
		check(sm.accept_restaurant_customer("restaurant_%d" % (i+1)).success, "接单夹具")
	sm.save()
	await reopen()
	await pause(0.6)
	for i in 3:
		var bubble = flow.actors["restaurant_%d" % (i+1)].get_node("OrderBubble")
		check(bubble.visible and bubble.item_id == sm.CustomerCatalog.CUSTOMERS[i].recipe, "入座显示对应料理")
	var camera := get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.global_position = Vector2(780,380)
	camera.zoom = Vector2(0.85,0.85)
	camera.reset_smoothing()
	await shot("order_bubbles_waiting")
	await reopen()
	check(flow.actors.restaurant_1.get_node("OrderBubble").visible, "读档恢复等餐气泡")
	var order: Dictionary = sm.restaurant_customer_order("restaurant_1")
	check(not sm.deliver_restaurant_customer(order.id).success, "无成品交付失败")
	flow._sync()
	check(flow.actors.restaurant_1.get_node("OrderBubble").visible, "交付失败气泡保留")
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
	for ingredient in recipe.ingredients: sm.data.warehouse_stock[ingredient] = 1
	check(sm.take_warehouse_items(recipe.ingredients).success, "取料")
	check(sm.start_cooking(order.item_id).success and sm.finish_first_order_cooking(3).success, "制作")
	flow._deliver(order.id)
	check(not flow.actors.restaurant_1.get_node("OrderBubble").visible, "上菜立即隐藏")
	await pause(2.1)
	check(flow._dialog.visible and flow._shade.visible, "餐后对白和蒙层保留")
	for i in 3: await key(KEY_E)
	await pause(1.1)
	check(not flow.actors.has(order.id) and not player.input_locked, "离场移除并恢复输入")
	print("BUBBLE_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)

