extends "res://tools/tests/elder_01_flow.gd"

func _walkthrough() -> void:
	_seed(12)
	_check(sm.accept_elder_firewood(NEAR).success and sm.deliver_elder_firewood(NEAR).success, "实际老者交付解锁背包")
	sm.data.inventory.wood = 0
	sm.data.inventory.rockmane_meat = 0
	sm.data.inventory.rock_salt = 0
	sm.data.inventory.slime_gel = 4
	sm.data.warehouse_stock = {"rockmane_meat":0, "rock_salt":0}
	_check(sm.save(), "截图相同库存组合落盘")
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	maze.player.position = NEAR
	await get_tree().create_timer(0.2).timeout
	var before := JSON.stringify(sm.data)
	await _click(maze.backpack_entry)
	var warehouse = maze.backpack_warehouse
	_check(warehouse.visible and maze.player.input_locked, "真实入口打开背包")
	var expected := ["lantern_berry", "insulating_leaf", "sour_vine_juice", "slime_gel"]
	for i in expected.size():
		_check(warehouse._slots_grid.get_child(i).item_id == expected[i], "已拥有物品连续前排："+expected[i])
	_check(warehouse._slots_grid.get_child(3)._quantity == 4, "凝胶实际数量保留")
	await _shot("backpack_compact")
	await _key(KEY_ESCAPE)
	_check(not warehouse.visible and not maze.player.input_locked and JSON.stringify(sm.data) == before, "关闭恢复输入且库存不变")
	sm.data.inventory.rock_salt = 2
	_check(sm.save(), "新增前序物品库存")
	before = JSON.stringify(sm.data)
	await _click(maze.backpack_entry)
	_check(warehouse._slots_grid.get_child(0).item_id == "rock_salt", "重开按原物品顺序重新紧排")
	_check(warehouse._slots_grid.get_child(4).item_id == "slime_gel", "无中间空槽")
	await _shot("backpack_compact_reopen")
	await _click(warehouse._cancel_button)
	_check(JSON.stringify(sm.data) == before and not maze.player.input_locked, "鼠标关闭不改库存")
	warehouse.open_for_order()
	_check(warehouse._slots_grid.get_child(0).item_id == "rockmane_meat" and warehouse._slots_grid.get_child(1).item_id == "rock_salt", "同实例切回取料恢复固定顺序")
	_check(warehouse._claim_button.visible and warehouse._selection_area.visible, "餐厅取料操作保留")
	warehouse.close_modal()
	await _close_maze()
