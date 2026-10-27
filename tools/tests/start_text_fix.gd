extends "res://tools/tests/start_02_ui.gd"

func _manage_run() -> void:
	var isolation := OS.get_environment("MAZE_START01_ROOT").replace("\\", "/").to_lower()
	if isolation.is_empty() or not ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().begins_with(isolation + "/"):
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	mode = _arg("--mode=")
	sm.create_new_game()
	sm.create_new_game()
	screen = load("res://scenes/start_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(0.3).timeout
	await _click(screen.continue_button)
	var modal = screen.save_modal
	_check(modal._title_label.text == "继续游戏", "弹窗标题")
	await _capture("title")
	for remaining in [1, 0]:
		var target: String = modal._slots[0].id
		await _click(modal._rows[target].get_node("Actions/delete"))
		_check(modal._mode == "delete", "打开删除确认")
		await _click(modal._edit_modal._confirm_button)
		_check(not FileAccess.file_exists(target) and modal._slots.size() == remaining, "实际删除存档")
		await _click(modal._cancel_button)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(1000, 100)
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
		_check(not modal.visible and screen.continue_button.has_focus() and not screen.continue_button.disabled, "关闭恢复按钮输入及焦点")
		_check(screen.continue_button.get_theme_color("font_focus_color") == Color("#5f704d"), "焦点文字保持深绿")
		await _capture("remaining-" + str(remaining))
		await _key(KEY_ENTER)
		_check(modal.visible, "键盘重新打开存档列表")
	await _capture("empty")
	_write(_arg("--report="), JSON.stringify({"checks":checks,"failures":failures,"captures":captures}, "\t"))
	print("START TEXT checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
