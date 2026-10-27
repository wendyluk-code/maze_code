extends "res://tools/tests/team_entry_01.gd"
## 仅供设计审批：运行时注入汇总行，不修改生产弹窗。
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离预览存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			_completed()
			sm.cancel_maze_entry()
			await _restaurant()
			await _click(modal.slots[0])
			await _click(modal.checks.yaya)
			await _click(modal.checks.tieshan)
			for label in modal.selection_panel.find_children("*", "Label", true, false):
				if label.text == "攻击 / 生命上限": label.text = "攻击 / 生命 / 防御"
			for id in modal.row_panels:
				var stats: Dictionary = modal._record(id)
				var value: Label = modal.row_panels[id].get_child(0).get_child(1)
				value.text = "%d / %d / %d" % [stats.attack, stats.health, stats.defense]
			var column: VBoxContainer = modal.selection_panel.get_child(0)
			var summary := HBoxContainer.new()
			summary.add_theme_constant_override("separation", 24)
			column.add_child(summary)
			column.move_child(summary, column.get_child_count() - 2)
			var defense := 0
			for id in modal.selected: defense += int(modal._record(id).defense)
			for value in ["总攻击  " + modal.power_value.text, "总生命  " + modal.health_value.text, "总防御  " + str(defense), "饱腹 / 上限  " + modal.food_value.text]:
				var label: Label = modal._label(value, 18, SproutTheme.INK)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				summary.add_child(label)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(modal.selection_panel.get_global_rect().encloses(summary.get_global_rect()), "汇总行位于现有面板内")
			await _capture(_arg("--output-dir="), "selection_preview_%dx%d" % [resolution.x,resolution.y])
			scene.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
