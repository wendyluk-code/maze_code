extends "res://tools/tests/start_01_suite.gd"

func _ready() -> void:
	_manage_run.call_deferred()

func _manage_run() -> void:
	var isolation := OS.get_environment("MAZE_START01_ROOT").replace("\\", "/").to_lower()
	if isolation.is_empty() or not ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower().begins_with(isolation + "/"):
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	mode = _arg("--mode=")
	var a: Dictionary = sm.create_new_game()
	sm.rename_save_slot(a.id, "冒险甲")
	sm.accept_first_order()
	var b: Dictionary = sm.create_new_game()
	sm.rename_save_slot(b.id, "冒险乙")
	_write("user://saves/broken.json", "{broken")
	var before: Dictionary = sm.data.duplicate(true)
	var active: String = sm.active_save_path()
	screen = load("res://scenes/start_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await _click(screen.continue_button)
	await _select_row(a.id)
	var modal = screen.save_modal
	_check(modal._selected == a.id, "Viewport 鼠标选择 A")
	await _capture("selected")
	await _click(modal._rename_button)
	_check(modal._mode == "rename" and modal._name_edit.has_focus(), "重命名输入框获焦")
	await type_name("Cancelled")
	await _capture("rename-cancel")
	await _key(KEY_ESCAPE)
	_check(modal._mode == "list" and sm.data == before and sm.list_save_slots().slots.size() == 3, "Esc 取消重命名不改变状态或数量")
	await _click(modal._rename_button)
	await type_name("Renamed-A")
	await _click(modal._confirm_button)
	_check(modal._mode == "list" and JSON.parse_string(_disk(a.id))[sm.SLOT_META_KEY].name == "Renamed-A", "鼠标确认重命名落盘")
	_check(sm.data == before and sm.active_save_path() == active, "非活动档改名不切换内存路径")
	await _capture("renamed")
	await _click(modal._rename_button)
	await type_name("CancelledAgain")
	await _click(modal._cancel_button)
	_check(JSON.parse_string(_disk(a.id))[sm.SLOT_META_KEY].name == "Renamed-A", "取消按钮保留已提交名称")
	await _click(modal._delete_button)
	await _capture("delete-confirmation")
	_check(modal._mode == "delete" and modal._cancel_button.has_focus(), "删除确认默认焦点为取消")
	await _key(KEY_ENTER)
	_check(modal._mode == "list" and FileAccess.file_exists(a.id), "默认 Enter 取消删除")
	await _click(modal._delete_button)
	await _click(modal._close_button)
	_check(FileAccess.file_exists(a.id) and sm.data == before, "关闭删除确认不改状态")
	await _click(modal._delete_button)
	await _click(modal._confirm_button)
	_check(not FileAccess.file_exists(a.id) and sm.list_save_slots().slots.size() == 2 and sm.data == before and sm.active_save_path() == active, "确认删除仅移除 A")
	await _capture("deleted")
	await _select_row("user://saves/broken.json")
	await _click(modal._rename_button)
	await type_name("Broken")
	await _click(modal._confirm_button)
	_check(modal._mode == "rename" and modal._body_label.text.contains("损坏") and _disk("user://saves/broken.json") == "{broken", "坏档重命名失败留在弹窗原档不变")
	await _capture("broken-rename")
	await _key(KEY_ESCAPE)
	await _click(modal._confirm_button)
	_check(modal.visible and modal._body_label.text.contains("损坏") and sm.active_save_path() == active and sm.data == before, "坏档载入错误不切换内存路径")
	await _capture("broken-load")
	await _select_row(b.id)
	DirAccess.make_dir_absolute(b.id + ".tmp")
	await _click(modal._rename_button)
	await type_name("FailWrite")
	await _click(modal._confirm_button)
	_check(modal._body_label.text.contains("失败") and sm.data == before and sm.active_save_path() == active, "界面显示写入失败且状态不变")
	await _capture("write-failed")
	DirAccess.remove_absolute(b.id + ".tmp")
	await _key(KEY_ESCAPE)
	await _click(modal._delete_button)
	await _click(modal._confirm_button)
	_check(sm.active_save_path().is_empty() and not sm.save() and not FileAccess.file_exists(b.id), "界面删除活动档不能复活")
	await _capture("active-deleted")
	_write(_arg("--report="), JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"input":"Viewport event injection; not OS mouse/keyboard"}, "\t"))
	print("START02 UI checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func type_name(value: String) -> void:
	# 输入框已全选，逐字向实际 Viewport 投递 Unicode 按键，不直接写 text。
	for character in value:
		for down in [true, false]:
			var event := InputEventKey.new()
			event.unicode = character.unicode_at(0)
			event.pressed = down
			get_viewport().push_input(event, true)
			await get_tree().process_frame

func _click(control: Control) -> void:
	# Container 隐藏/显示后的排序在帧末执行；等待布局稳定后再定位输入。
	await get_tree().create_timer(0.15).timeout
	await _click_at(control.get_global_rect().get_center())
