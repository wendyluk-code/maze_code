extends "res://tools/tests/team_entry_01.gd"
## 仅在隔离预览实例中替换姓名排版，生产界面保持不变。
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
			await _click(modal.selection_done)
			for i in modal.selected.size():
				var id: String = modal.selected[i]
				var button: Button = modal.slot_names[i]
				button.text = ""
				var center := CenterContainer.new()
				center.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(center)
				center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				var row := HBoxContainer.new()
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_theme_constant_override("separation", 8)
				center.add_child(row)
				var name_label: Label = modal._label(modal._config(id).name, 20, SproutTheme.INK)
				row.add_child(name_label)
				var level: Label = modal._label("Lv.%d" % modal._record(id).level, 14, SproutTheme.INK_MUTED)
				level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(level)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(modal.team_panel.visible, "现有团队界面预览")
			await _capture(_arg("--output-dir="), "team_name_%dx%d" % [resolution.x,resolution.y])
			scene.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
