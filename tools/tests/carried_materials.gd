extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离用户存档")
	if failures == 0:
		_state_checks()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _scene_checks()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("CARRIED_MATERIALS ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _stock() -> void:
	sm.data.inventory = {"wood": 12, "salt_grilled_rockmane": 1}
	sm.data.warehouse_stock = {"rockmane_meat": 5, "rock_salt": 5, "slime_gel": 5, "moondew_honey": 5}

func _state_checks() -> void:
	_completed()
	_stock()
	var before: Dictionary = sm.data.duplicate(true)
	_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1,"slime_gel":1,"moondew_honey":1}).reason == "too_many_kinds" and sm.data == before, "四种事务拒绝且状态不变")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(sm.take_warehouse_items({"rock_salt":1}).reason == "save_failed" and sm.data == before, "取货保存失败原子回滚")
	sm._active_save_path = path
	_check(sm.take_warehouse_items({"rockmane_meat":2,"rock_salt":1,"slime_gel":1}).success, "三种多份允许且木材成品不阻止")
	before = sm.data.duplicate(true)
	_check(sm.take_warehouse_items({"moondew_honey":1}).reason == "hands_full" and sm.data == before, "有料时不能追加不同种")
	_check(sm.take_warehouse_items({"rock_salt":1}).reason == "hands_full" and sm.data == before, "有料时不能追加同种")
	sm.load_data()
	_check(sm.carried_ingredients().size() == 3 and sm.take_warehouse_items({"rock_salt":1}).reason == "hands_full", "读档后仍保留材料与限制")
	sm.data = sm._defaults()
	sm.accept_first_order()
	sm.data.inventory = {"slime_gel": 1}
	before = sm.data.duplicate(true)
	_check(sm.claim_first_order_ingredients().reason == "hands_full" and sm.data == before, "首单入口不能绕过携料限制")
	sm.data.inventory = {}
	_check(sm.claim_first_order_ingredients().success, "首单空手正常取料")
	before = sm.data.duplicate(true)
	_check(not sm.claim_first_order_ingredients().created and sm.data == before, "首单重复回执不叠加")

func _scene_checks() -> void:
	_completed()
	_stock()
	# 先建立已有候客的存档，避免首次来客教学截走本项仓库输入。
	sm.ensure_restaurant_customer()
	await _open_scene()
	await get_tree().create_timer(0.6).timeout
	var player = scene.get_node("Player")
	var icons = player.get_node("CarriedMaterialIcons")
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	var store = scene.get_node("InteractPoints/Store")
	player.global_position = _stand(store)
	player.last_valid = player.global_position
	await get_tree().create_timer(0.3).timeout
	_check(icons.get_child_count() == 0, "木材成品不显示为材料" + suffix)
	await _send_key(KEY_E)
	_check(warehouse.visible and player.input_locked, "真实E打开仓库并锁定输入")
	_check(get_viewport().get_visible_rect().encloses(warehouse._claim_button.get_global_rect()), "取货按钮完整位于窗口内")
	for id in ["rockmane_meat","rock_salt","slime_gel","moondew_honey"]:
		await _click(warehouse._slot_by_id[id]._icon_button)
	_check(warehouse._selected.size() == 3 and not warehouse._selected.has("moondew_honey"), "实际点击第四种静默拒绝")
	warehouse._change_selected_quantity("slime_gel", -1)
	await _click(warehouse._slot_by_id.moondew_honey._icon_button)
	_check(warehouse._selected.size() == 3 and warehouse._selected.has("moondew_honey"), "减至零后允许改选第三种")
	await _shot("selection_three")
	await _click(warehouse._claim_button)
	await get_tree().process_frame
	_check(not warehouse.visible and not player.input_locked and icons.get_child_count() == 3, "真实取货后显示三个图标并恢复输入")
	var expected_side: int = -1
	for direction in [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var action: String = {Vector2.LEFT:"ui_left", Vector2.RIGHT:"ui_right", Vector2.UP:"ui_up", Vector2.DOWN:"ui_down"}[direction]
		Input.action_press(action)
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release(action)
		await get_tree().process_frame
		await get_tree().process_frame
		if direction == Vector2.LEFT: expected_side = 1
		if direction == Vector2.RIGHT: expected_side = -1
		_check(player.facing == direction and icons.side == expected_side, "真实移动侧向切换或正背面保留：" + str(direction))
		_check(icons.global_position == player.global_position + icons.position, "移动后材料跟随人物")
		await _shot("side_%d_%s" % [icons.side, str(direction)])
	var before: Dictionary = sm.data.duplicate(true)
	await _send_key(KEY_E)
	await _click(warehouse._slot_by_id.slime_gel._icon_button)
	warehouse._on_claim_pressed()
	_check(warehouse._selected.is_empty() and warehouse._claim_button.disabled and sm.data == before and not warehouse._message.visible, "携料再打开仓库无法选取或领取且无文案")
	await _send_key(KEY_ESCAPE)
	_check(not player.input_locked, "受限仓库Esc恢复输入")
	_check(sm.save(), "保存携料状态")
	await _close_scene()
	sm.load_data()
	await _open_scene()
	await get_tree().create_timer(0.4).timeout
	player = scene.get_node("Player")
	icons = player.get_node("CarriedMaterialIcons")
	_check(icons.get_child_count() == 3, "场景重建从真实库存恢复三个图标")
	var before_inventory: Dictionary = sm.inventory_snapshot()
	for icon in icons.get_children():
		_check(before_inventory.get(str(icon.name), 0) > 0 and icon.texture != null, "每个图标对应实际材料：" + str(icon.name))
	# 使用真实烹饪事务验证消耗后自动消失及重新取货，不凭显示回调改库存。
	sm.data.inventory = {"rockmane_meat":1,"rock_salt":1,"wood":12}
	var customer: Dictionary = sm.restaurant_customers().front
	if not customer.is_empty(): sm.accept_restaurant_customer(customer.id)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(icons.get_child_count() == 2, "库存变化同步两个图标")
	_check(sm.start_cooking("salt_grilled_rockmane").success, "真实开始烹饪扣料")
	await get_tree().process_frame
	_check(icons.get_child_count() == 0 and sm.carried_ingredients().is_empty(), "烹饪消耗完成清除图标")
	_check(sm.take_warehouse_items({"slime_gel":1}).success, "材料用尽后允许再次取料")
	await get_tree().process_frame
	_check(icons.get_child_count() == 1, "再次取料显示对应单个图标")
	await _shot("one_material")
	await _close_scene()
