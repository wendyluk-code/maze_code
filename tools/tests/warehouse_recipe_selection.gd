extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_completed()
		_seed_stock()
		var before: Dictionary = sm.data.duplicate(true)
		for selection in [{"rockmane_meat":1}, {"rockmane_meat":2,"rock_salt":1}, {"rockmane_meat":1,"moondew_honey":1}, {"wood":1}]:
			_check(sm.take_warehouse_items(selection).reason == "recipe_mismatch" and sm.data == before, "事务拒绝缺料、超量、混配或非配方物品："+str(selection))
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).reason == "save_failed" and sm.data == before, "合法配方保存失败完整回滚")
		sm._active_save_path = path
		sm.data.unlocked_recipe_ids = ["salt_grilled_rockmane"]
		_check(sm.warehouse_recipe_candidates({"slime_gel":1}).is_empty(), "未收录配方不能作为取货依据")
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _flow_recipe()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("WAREHOUSE_RECIPE ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _seed_stock() -> void:
	sm.data.inventory = {"wood":12}
	sm.data.unlocked_recipe_ids = sm.RecipeCatalog.recipe_ids()
	sm.data.warehouse_stock = {"wood":12}
	for id in sm.RecipeCatalog.INGREDIENTS:
		sm.data.warehouse_stock[id] = 5

func _flow_recipe() -> void:
	_completed()
	_seed_stock()
	sm.ensure_restaurant_customer()
	await _open_scene()
	await get_tree().create_timer(0.4).timeout
	var player = scene.get_node("Player")
	var modal = scene.get_node("UIOverlay/WarehouseModal")
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	player.last_valid = player.global_position
	await _send_key(KEY_E)
	_check(modal.visible and player.input_locked, "真实E打开取料仓库")
	await _click(modal._slot_by_id.rockmane_meat._icon_button)
	_check(modal._selected == {"rockmane_meat":1} and not modal._salt_slot.disabled and modal._claim_button.disabled, "选肉后仅匹配岩盐且未齐不能取")
	for id in ["slime_gel","moondew_honey","brick_snail_meat","cooking_sake","wood"]:
		_check(modal._slot_by_id[id].disabled and modal._slot_by_id[id].modulate.r < 0.6, "不相容材料灰显不可点："+id)
	await _click(modal._slot_by_id.slime_gel._icon_button)
	modal._on_claim_pressed()
	_check(modal._selected == {"rockmane_meat":1} and sm.carried_ingredients().is_empty() and not modal._message.visible, "灰格点击和未齐取出均静默无副作用")
	modal._change_selected_quantity("rockmane_meat", 1)
	_check(modal._selected.rockmane_meat == 1 and modal._selected_rows.rockmane_meat.get_child(0).get_node("Plus").disabled, "配方数量上限同时限制加号与回调")
	await _shot("meat_only_salt_enabled")
	await _click(modal._selected_rows.rockmane_meat.get_child(0).get_node("Minus"))
	_check(modal._selected.is_empty() and not modal._slot_by_id.slime_gel.disabled and modal._slot_by_id.slime_gel.modulate == Color.WHITE, "取消首料恢复所有兼容食谱材料")
	await _click(modal._salt_slot._icon_button)
	_check(not modal._meat_slot.disabled and modal._slot_by_id.slime_gel.disabled, "反向先选岩盐仍匹配岩鬃肉")
	await _click(modal._meat_slot._icon_button)
	_check(not modal._claim_button.disabled, "准确配方一份才启用取出")
	await _shot("recipe_complete")
	await _click(modal._claim_button)
	await get_tree().process_frame
	_check(not modal.visible and not player.input_locked and sm.carried_ingredients() == {"rockmane_meat":1,"rock_salt":1}, "真实取出恰好一份且恢复输入")
	var icons = player.get_node("CarriedMaterialIcons")
	_check(icons.get_child_count() == 2, "材料图标显示配方两种原料")
	await _send_key(KEY_E)
	_check(modal._claim_button.disabled and modal._slot_by_id.slime_gel.disabled, "携带配方材料期间保持禁止再取")
	await _send_key(KEY_ESCAPE)
	_check(not player.input_locked, "Esc恢复输入")
	_check(sm.save(), "保存配方携料")
	sm.load_data()
	_check(sm.carried_ingredients() == {"rockmane_meat":1,"rock_salt":1}, "读档数量种类一致")
	# 经营事务消耗一份配方，随后可选择另一份配方。
	sm.accept_restaurant_customer(sm.restaurant_customers().front.id)
	# 接单后的食谱教学沿用真实确认输入，完成后再继续仓库交互。
	await get_tree().create_timer(0.5).timeout
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await get_tree().create_timer(0.3).timeout
	_check(sm.start_cooking("salt_grilled_rockmane").success, "真实烹饪消耗恰好配方")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(icons.get_child_count() == 0, "材料消耗后图标清除")
	_check(sm.finish_first_order_cooking(1).success, "真实产生料理成品")
	await _send_key(KEY_E)
	await _click(modal._slot_by_id.slime_gel._icon_button)
	_check(not modal._slot_by_id.moondew_honey.disabled and modal._meat_slot.disabled, "凝胶匹配月露蜜而非岩鬃肉")
	await _shot("gel_only_honey_enabled")
	await _click(modal._slot_by_id.moondew_honey._icon_button)
	await _click(modal._claim_button)
	_check(sm.carried_ingredients() == {"slime_gel":1,"moondew_honey":1}, "成品木材不阻止取出另一完整配方")
	await _close_scene()
