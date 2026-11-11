extends "res://tools/tests/restaurant_rest05a.gd"

func _first_customer() -> void:
	_seed_cycle()
	sm.data[Lesson.KEY] = {"phase":"done"}
	var hud = await _open_restaurant()
	await get_tree().create_timer(0.3).timeout
	var sign = hud.find_child("RestaurantDaySign",true,false)
	var stamina = get_tree().get_first_node_in_group("stamina_counter")
	var cooking = get_tree().get_first_node_in_group("cooking_modal")
	var warehouse = get_tree().get_first_node_in_group("warehouse_modal")
	for entry in [[cooking,"cooking"],[warehouse,"warehouse"],[hud.freezer,"freezer"],[hud.day_menu,"menu"],[sign.end_confirmation,"end_confirmation"]]:
		var modal: Control = entry[0]
		if modal==cooking: cooking.open_for_order()
		elif modal==warehouse: warehouse.open_stock()
		elif modal==sign.end_confirmation: modal.open_confirmation("确定结束今日营业？","结束营业","继续营业")
		else: modal.open()
		await get_tree().process_frame
		_check(sign.get_canvas_layer_node().layer < modal.get_canvas_layer_node().layer,"营业牌低于蒙层："+entry[1])
		_check(stamina.get_canvas_layer_node().layer < modal.get_canvas_layer_node().layer,"体力显示低于蒙层："+entry[1])
		_check(sign.visible and stamina.visible,"常驻信息保持显示，由蒙层压暗："+entry[1])
		await _shot("hud_below_"+entry[1])
		if modal==cooking or modal==warehouse: modal.close_modal()
		else: modal.hide()
	await _close_restaurant()
	await super._first_customer()
