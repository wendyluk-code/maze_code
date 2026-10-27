extends "res://tools/tests/npc_01_scene.gd"

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	sm.data.capture_first_visit_started = true
	for index in 3:
		check(sm.ensure_restaurant_customer().success, "按顺序生成唯一顾客")
		var order: Dictionary = sm.restaurant_customers().front
		check(sm.accept_restaurant_customer(order.id).success, "接单")
		check(sm.advance_restaurant_customer(order.id, "seating", "waiting").success, "入座")
		var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
		for ingredient in recipe.ingredients: sm.data.warehouse_stock[ingredient] = 1
		check(sm.take_warehouse_items(recipe.ingredients).success, "取料")
		check(sm.start_cooking(order.item_id).success and sm.finish_first_order_cooking(3).success, "制作")
		check(sm.deliver_restaurant_customer(order.id).success, "交单")
		for phases in [["eating","farewell"],["farewell","leaving"],["leaving","departed"]]:
			check(sm.advance_restaurant_customer(order.id,phases[0],phases[1]).success, "离场")
	await reopen()
	await pause(1.0)
	check(flow.actors.is_empty(), "读档实际餐厅无重复人物")
	check(sm.restaurant_customers().front.is_empty(), "前台不再出现一号")
	player.global_position = stand(restaurant.get_node("InteractPoints/Register"))
	player.last_valid = player.global_position
	await pause(0.4)
	await key(KEY_E)
	check(not flow._dialog.visible, "前台交互不重复接单")
	await shot("all_orders_completed_no_repeat")
	print("ONCE_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
