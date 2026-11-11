extends "res://tools/tests/restaurant_rest05a.gd"
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")

func click(control: Control) -> void:
	# 保存失败提示会使容器重新布局，等布局稳定后点击实际按钮位置。
	await get_tree().process_frame
	await get_tree().process_frame
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=control.get_global_rect().get_center()
	event.pressed=true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	evidence=_arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			_seed_cycle()
			sm.data[Lesson.KEY]={"phase":"done"}
			var recipe_ids := ["salt_grilled_rockmane","slime_candy","brick_snail_sashimi"]
			sm.data.unlocked_recipe_ids=recipe_ids.duplicate()
			for id in Recipes.INGREDIENTS: sm.data.warehouse_stock[id]=8
			for id in recipe_ids:
				var order := _arrive()
				_stage(order.id,"food",100)
				for customer in sm.data.restaurant_customers.seated:
					if customer.id==order.id: customer.item_id=id
			var hud=await _open_restaurant()
			hud.customer_flow.set_process(false)
			var w=get_tree().get_first_node_in_group("warehouse_modal")
			w.open_stock()
			await get_tree().process_frame
			_check(w._quick_ids.size()==3,"三个当前订单显示三个快捷料理")
			var before: Dictionary=sm.warehouse_snapshot()
			await click(w._quick_buttons[0])
			_check(w._selected==Recipes.get_recipe(recipe_ids[0]).ingredients,"真实左键选择一份配料")
			_check(sm.warehouse_snapshot()==before,"选择不扣库存")
			_check(w._slot_by_id.rock_salt.get_selected_quantity()==1 and w._slot_by_id.rockmane_meat._selected,"对应食材格选中")
			await _shot("quick_three_selected")
			await click(w._quick_buttons[1])
			_check(w._selected==Recipes.get_recipe(recipe_ids[1]).ingredients and not w._slot_by_id.rock_salt._selected,"切换替换配料并清除旧格选中")
			w._slot_by_id.slime_shell.set_selected_quantity(0,true)
			_check(not w._selected.has("slime_shell") and w._claim_button.disabled,"仍可手动减料，未配齐不可取")
			sm.data.warehouse_stock.moondew_honey=0
			sm.data.warehouse_stock.cooking_sake=0
			await get_tree().process_frame
			await get_tree().process_frame
			_check(w._quick_ids==[recipe_ids[0]],"缺任一材料隐藏相应料理")
			_check(absf(w._quick_buttons[0].get_global_rect().end.x-w._quick_panel.get_global_rect().end.x+6)<2,"仅一个料理时右对齐")
			await _shot("quick_one_right")
			sm.data.warehouse_stock.rock_salt=0
			await get_tree().process_frame
			await get_tree().process_frame
			_check(not w._quick_panel.visible,"无可选料理隐藏整栏")
			await _shot("quick_none_hidden")
			sm.data.warehouse_stock.rock_salt=8
			await get_tree().process_frame
			await get_tree().process_frame
			await click(w._quick_buttons[0])
			var path: String=sm._active_save_path
			sm._active_save_path=""
			await click(w._claim_button)
			_check(w.visible and sm.warehouse_snapshot()==before.merged({"moondew_honey":0,"cooking_sake":0},true),"取料保存失败保持窗口和库存")
			sm._active_save_path=path
			await click(w._claim_button)
			_check(not w.visible and sm.carried_ingredients()==Recipes.get_recipe(recipe_ids[0]).ingredients,"原取料按钮真实扣料并关闭")
			w.open_stock()
			_check(w._quick_buttons[0].disabled,"手持食材时禁用快捷选择")
			w.open_backpack()
			_check(not w._quick_panel.visible,"背包不显示快捷选择")
			w.open_for_order()
			_check(not w._quick_panel.visible,"首单教学保留原手动取料界面")
			w.close_modal()
			await _close_restaurant()
			sm.load_data()
			_check(sm.carried_ingredients()==Recipes.get_recipe(recipe_ids[0]).ingredients,"取料读档保持")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
