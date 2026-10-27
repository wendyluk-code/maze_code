extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _dish_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("CARRIED_DISHES ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _dish_flow() -> void:
	_completed()
	sm.ensure_restaurant_customer()
	var order: Dictionary = sm.restaurant_customers().front
	_check(sm.accept_restaurant_customer(order.id).success, "真实接单")
	sm.data["ch2_guide_01"] = {"revision":2,"step":"done","seen":{},"banked":{}}
	var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
	sm.data.warehouse_stock = recipe.ingredients.duplicate()
	_check(sm.take_warehouse_items(recipe.ingredients).success, "真实配方取料")
	await _open_scene()
	await get_tree().create_timer(0.9).timeout
	var player = scene.get_node("Player")
	var icons = player.get_node("CarriedMaterialIcons")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	await _shot("ingredients_circle_backing")
	player.global_position = _stand(scene.get_node("InteractPoints/Cauldron"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	var cooking = get_tree().get_first_node_in_group("cooking_modal")
	_check(cooking.visible, "真实E打开料理台")
	if cooking._lesson_paused: await _send_key(KEY_E)
	await _click(cooking._start_button)
	await get_tree().create_timer(5.9).timeout
	_check(sm.inventory_quantity(order.item_id) == 1, "真实料理倒计时完成生成成品")
	for i in range(4):
		if not cooking.visible: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	await get_tree().process_frame
	_check(not cooking.visible and not player.input_locked, "确认结果关闭料理台恢复移动")
	_check(sm.inventory_quantity(order.item_id) == 1 and icons.has_node(order.item_id), "确认结果不自动交单且显示对应料理")
	player.facing = Vector2.RIGHT
	await get_tree().create_timer(0.3).timeout
	await _shot("cooked_carrying_dish")
	player.facing = Vector2.LEFT
	await get_tree().process_frame
	await get_tree().process_frame
	_check(icons.side == 1, "成品沿用朝向切换")
	await _shot("cooked_facing_left")
	_check(sm.save(), "保存携带成品")
	sm.load_data()
	await get_tree().process_frame
	_check(icons.has_node(order.item_id) and sm.inventory_quantity(order.item_id) == 1, "读档保留成品")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _send_key(KEY_E)
	_check(sm.inventory_quantity(order.item_id) == 1 and icons.has_node(order.item_id), "交单保存失败保留料理及图标")
	sm._active_save_path = path
	await _send_key(KEY_E)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(sm.inventory_quantity(order.item_id) == 0 and not icons.has_node(order.item_id), "吧台真实E成功交单后图标消失")
	await _shot("delivered_dish_gone")
	await _close_scene()
