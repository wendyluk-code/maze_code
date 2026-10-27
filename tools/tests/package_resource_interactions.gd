extends "res://tools/tests/combat_02_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		await _new_scene()
		maze.capture_flow.set_process(false)
		var targets: Array = []
		targets.append_array(maze.dig_sites)
		targets.append_array(maze.chests)
		for target in targets:
			var found := false
			for radius in [0, 20, 40, 60]:
				for angle in range(0, 360, 15):
					var point: Vector2 = target.global_position + Vector2.from_angle(deg_to_rad(angle)) * radius
					if not Roads.is_walkable(point): continue
					maze.player.global_position = point
					maze.player.last_valid = point
					maze._update_chest_target()
					if maze.dig_target == target or maze.chest_target == target:
						found = true
						break
				if found: break
			_check(found, "可走区域存在物件交互站位")
			if not found: continue
			await get_tree().create_timer(0.1).timeout
			await _send_key(KEY_E)
			_check(maze.loot_modal.visible and not target.visible, "E打开奖励且移除已领取物件")
			if not maze.loot_modal.visible: break
			_check(maze.player.input_locked, "领取弹窗锁定移动")
			await _capture_image("resource_" + str(targets.find(target)))
			await _click(maze.loot_modal._confirm_button)
			_check(not maze.loot_modal.visible and not maze.player.input_locked, "收下恢复输入")
			await _send_key(KEY_E)
			_check(not maze.loot_modal.visible, "重复E不重复领取")
		_check(sm.inventory_quantity("wood") == 12, "四处木材实际入库12个")
		_check(sm.data.claimed_dig_sites.size() == 4, "四处采集记录持久化")
		var before: Dictionary = sm.data.duplicate(true)
		sm.load_data()
		_check(sm.data.claimed_dig_sites == before.claimed_dig_sites, "重载保留采集记录")
		await _close_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
