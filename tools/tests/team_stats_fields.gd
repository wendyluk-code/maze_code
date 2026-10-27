extends "res://tools/tests/team_entry_01.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			_completed()
			sm.cancel_maze_entry()
			await _restaurant()
			await _click(modal.slots[0])
			_check(modal.defense_value.text == "0" and modal.health_value.text == "0", "空队汇总清零")
			await _click(modal.checks.yaya)
			_check(modal.defense_value.text == "1" and modal.health_value.text == "12", "单人汇总")
			await _click(modal.checks.tieshan)
			_check(modal.defense_value.text == "3" and modal.health_value.text == "36" and modal.power_value.text == "3", "双人攻击生命防御汇总")
			_check(modal.selection_totals[2].text == "总防御  3" and modal.selection_totals[3].text == "饱腹 / 上限  3 / 3", "选人汇总同步")
			for id in modal.row_panels:
				var portrait: Button = modal.portrait_buttons[id]
				var row_badge: TextureRect = portrait.get_node("TeamRarityBadge")
				_check((row_badge.position + row_badge.size).is_equal_approx(Vector2(75,75)), "列表头像角标贴右下外伸3像素")
				var stats: Dictionary = modal._record(id)
				var value: Label = modal.row_panels[id].get_child(0).get_child(1)
				_check(value.text == "%d / %d / %d" % [stats.attack, stats.health, stats.defense], "角色行显示防御")
			await _shot_stats("selection", resolution)
			for i in modal.selected.size():
				var mini_badge: TextureRect = modal.mini_slots[i].get_node("TeamRarityBadge")
				_check((mini_badge.position + mini_badge.size).is_equal_approx(Vector2(47,47)), "底部缩略头像角标贴右下外伸3像素")
			await _click(modal.selection_done)
			_check(modal.team_panel.visible and not modal.selector.visible, "确认返回团队页")
			_check(modal.defense_value.is_visible_in_tree() and modal.health_value.is_visible_in_tree(), "团队页生命防御可见")
			_check(modal.food_value.text == "3", "团队页饱腹只显示当前值")
			_check(modal.slot_name_labels[0].text == "芽芽" and modal.slot_level_labels[0].text == "Lv.1", "姓名与小号等级分离")
			var badge: TextureRect = modal.slots[0].get_node("TeamRarityBadge")
			_check((badge.position + badge.size).is_equal_approx(Vector2(67,67)), "字标右下角外伸3像素")
			await _click(modal.slot_names[0])
			_check(modal.details.visible, "新姓名排版仍可点击详情")
			await _send_key(KEY_ESCAPE)
			_check(modal.slot_stats.all(func(label): return not label.is_visible_in_tree()), "头像下方不显示个人属性")
			await _shot_stats("team", resolution)
			await _click(modal.slots[0])
			await _click(modal.checks.tieshan)
			_check(modal.defense_value.text == "1" and modal.selection_totals[1].text == "总生命  12", "取消角色两页同步扣除")
			await _send_key(KEY_ESCAPE)
			await _click(modal.close_button)
			_check(not hud._player.input_locked, "关闭恢复输入")
			scene.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _shot_stats(label: String, resolution: Vector2i) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _capture(_arg("--output-dir="), "%s_%dx%d" % [label,resolution.x,resolution.y])
