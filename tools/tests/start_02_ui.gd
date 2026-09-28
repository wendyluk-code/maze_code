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
	sm.accept_first_order()
	var b: Dictionary = sm.create_new_game()
	_write("user://saves/broken.json", "{broken")
	var before: Dictionary = sm.data.duplicate(true)
	var active: String = sm.active_save_path()
	screen = load("res://scenes/start_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await _click(screen.continue_button)
	var modal = screen.save_modal
	_check(modal._cancel_button.get_theme_stylebox("focus") is StyleBoxEmpty, "取消保留键盘焦点但不画绿色边框")
	await _capture("initial")
	for slot in modal._slots:
		var row: Control = modal._rows[slot.id]
		var fields := row.get_node("Fields").get_children()
		_check(fields.size() == 2 and fields[0].text == slot.name and fields[1].text == sm.save_date_text(slot.saved_at), "条目仅名称与北京时间日期")
		var actions: Control = row.get_node("Actions")
		_check(row.get_global_rect().encloses(actions.get_global_rect()) and actions.position.x > row.size.x * 0.5, "图标位于行内右侧")
	# 未选中 A 时直接点它的图标，必须操作 A 而不是载入或作用于旧选择。
	await _capture_icon_states(modal, a.id)
	await _select_row(b.id)
	var list_panel_rect: Rect2 = modal._panel.get_global_rect()
	var original_row = modal._rows[a.id]
	await _click(modal._rows[a.id].get_node("Actions/rename"))
	_check(modal._selected == a.id and modal._mode == "rename" and sm.active_save_path() == active, "未选中行重命名图标准确定位且不载入")
	await _check_layered(modal, list_panel_rect)
	await _capture("rename-layered")
	await _key(KEY_ESCAPE)
	_check(modal.visible and not modal._edit_modal.visible and modal._rows[a.id] == original_row and original_row.get_node("Actions/rename").has_focus(), "Esc 只关闭上层，保留列表实例与选择并恢复原图标焦点")
	await _capture("rename-focus-restored")
	await _select_row(a.id)
	# 长名称不能挤走右侧图标；用真实输入保存再从同行图标编辑。
	await _click(modal._rows[a.id].get_node("Actions/rename"))
	await type_name("长".repeat(40))
	await _click(modal._edit_modal._confirm_button)
	var long_row: Control = modal._rows[a.id]
	_check(long_row.get_node("Fields").get_global_rect().end.x <= long_row.get_node("Actions").get_global_rect().position.x, "40字名称省略且不遮挡行内操作")
	await _capture("long-name")
	await _click(long_row.get_node("Actions/rename"))
	_check(modal._mode == "rename" and modal._selected == a.id, "长名称存档重新打开上层编辑")
	await _capture("long-name-edit")
	await type_name("冒险1")
	await _click(modal._edit_modal._confirm_button)
	_check(modal._selected == a.id, "Viewport 鼠标选择 A")
	await _capture("selected")
	await _click(modal._rows[modal._selected].get_node("Actions/rename"))
	_check(modal._mode == "rename" and modal._name_edit.has_focus(), "重命名输入框获焦")
	await type_name("Cancelled")
	await _capture("rename-cancel")
	await _key(KEY_ESCAPE)
	_check(modal._mode == "list" and sm.data == before and sm.list_save_slots().slots.size() == 3, "Esc 取消重命名不改变状态或数量")
	await _click(modal._rows[modal._selected].get_node("Actions/rename"))
	await type_name("Renamed-A")
	await _click(modal._edit_modal._confirm_button)
	_check(modal._mode == "list" and JSON.parse_string(_disk(a.id))[sm.SLOT_META_KEY].name == "Renamed-A", "鼠标确认重命名落盘")
	_check(sm.data == before and sm.active_save_path() == active, "非活动档改名不切换内存路径")
	await _capture("renamed")
	await _click(modal._rows[modal._selected].get_node("Actions/rename"))
	await type_name("CancelledAgain")
	await _click(modal._edit_modal._cancel_button)
	_check(JSON.parse_string(_disk(a.id))[sm.SLOT_META_KEY].name == "Renamed-A", "取消按钮保留已提交名称")
	await _click(modal._rows[modal._selected].get_node("Actions/delete"))
	await _check_layered(modal, list_panel_rect)
	modal._edit_modal._cancel_button.grab_focus()
	await _capture("delete-confirmation")
	_check(modal._mode == "delete" and modal._edit_modal._cancel_button.has_focus(), "删除确认默认焦点为取消")
	await _key(KEY_ENTER)
	_check(modal._mode == "list" and FileAccess.file_exists(a.id), "默认 Enter 取消删除")
	await _capture("delete-focus-restored")
	await _click(modal._rows[modal._selected].get_node("Actions/delete"))
	await _click(modal._edit_modal._close_button)
	_check(FileAccess.file_exists(a.id) and sm.data == before, "关闭删除确认不改状态")
	await _click(modal._rows[modal._selected].get_node("Actions/delete"))
	await _click(modal._edit_modal._confirm_button)
	_check(not FileAccess.file_exists(a.id) and sm.list_save_slots().slots.size() == 2 and sm.data == before and sm.active_save_path() == active, "确认删除仅移除 A")
	await _capture("deleted")
	await _select_row("user://saves/broken.json")
	await _click(modal._rows[modal._selected].get_node("Actions/rename"))
	await type_name("Broken")
	await _click(modal._edit_modal._confirm_button)
	_check(modal._mode == "rename" and modal._edit_modal._body_label.text.contains("损坏") and _disk("user://saves/broken.json") == "{broken", "坏档重命名失败留在弹窗原档不变")
	await _capture("broken-rename")
	await _key(KEY_ESCAPE)
	await _click(modal._confirm_button)
	_check(modal.visible and modal._body_label.text.contains("损坏") and sm.active_save_path() == active and sm.data == before, "坏档载入错误不切换内存路径")
	await _capture("broken-load")
	await _select_row(b.id)
	DirAccess.make_dir_absolute(b.id + ".tmp")
	await _click(modal._rows[modal._selected].get_node("Actions/rename"))
	await type_name("FailWrite")
	await _click(modal._edit_modal._confirm_button)
	_check(modal._edit_modal._body_label.text.contains("失败") and sm.data == before and sm.active_save_path() == active, "界面显示写入失败且状态不变")
	await _capture("write-failed")
	DirAccess.remove_absolute(b.id + ".tmp")
	await _click(modal._edit_modal._confirm_button)
	_check(modal._mode == "list" and not modal._edit_modal.visible and JSON.parse_string(_disk(b.id))[sm.SLOT_META_KEY].name == "FailWrite", "写入恢复后可在上层原输入基础上重试成功")
	await _click(modal._rows[modal._selected].get_node("Actions/delete"))
	await _click(modal._edit_modal._confirm_button)
	_check(sm.active_save_path().is_empty() and not sm.save() and not FileAccess.file_exists(b.id), "界面删除活动档不能复活")
	await _capture("active-deleted")
	_check(modal.visible and not modal._edit_modal.visible and modal._cancel_button.has_focus(), "删除成功后保留下层并恢复安全焦点")
	await _check_scroll_restore(modal)
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

func _capture_icon_states(modal, slot_id: String) -> void:
	for kind in ["rename", "delete"]:
		var button: Button = modal._rows[slot_id].get_node("Actions/" + kind)
		var point := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		get_viewport().push_input(motion, true)
		await _capture(kind + "-hover")
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.pressed = down
			get_viewport().push_input(event, true)
			if down:
				await _capture(kind + "-pressed")
			else:
				await get_tree().process_frame
		await _key(KEY_ESCAPE)
		await _capture(kind + "-focus")

func _click(control: Control) -> void:
	# Container 隐藏/显示后的排序在帧末执行；等待布局稳定后再定位输入。
	await get_tree().create_timer(0.15).timeout
	await _click_at(control.get_global_rect().get_center())
	await RenderingServer.frame_post_draw

func _check_layered(modal, original_rect: Rect2) -> void:
	_check(modal.slot_list.is_visible_in_tree() and modal._edit_modal.visible and modal._panel.get_global_rect() == original_rect, "上层打开时保留原列表及面板尺寸")
	var edit_rect: Rect2 = modal._edit_modal._panel.get_global_rect()
	_check(original_rect.encloses(edit_rect) and edit_rect.size.x < original_rect.size.x and edit_rect.size.y < original_rect.size.y, "操作弹窗居中叠放且小于原列表")
	var selected: String = modal._selected
	await _click(modal._close_button)
	_check(modal.visible and modal._edit_modal.visible and modal._selected == selected, "遮罩阻止点击下层关闭按钮")
	var trapped := true
	for index in 8:
		await _key(KEY_TAB)
		var focused := get_viewport().gui_get_focus_owner()
		trapped = trapped and focused != null and modal._edit_modal.is_ancestor_of(focused)
	_check(trapped, "Tab 循环始终位于上层弹窗")
	for index in 5:
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_TAB
			event.shift_pressed = true
			event.pressed = down
			get_viewport().push_input(event, true)
			await get_tree().process_frame
		trapped = trapped and modal._edit_modal.is_ancestor_of(get_viewport().gui_get_focus_owner())
	_check(trapped, "Shift+Tab 反向循环保持在上层")

func _check_scroll_restore(modal) -> void:
	for index in 6:
		sm.create_new_game()
	modal.open_slots()
	await get_tree().create_timer(0.2).timeout
	var target: String = modal._slots[-1].id
	modal.slot_list._scroll.scroll_vertical = 10000
	await get_tree().create_timer(0.2).timeout
	var scroll_before: int = modal.slot_list._scroll.scroll_vertical
	await _click(modal._rows[target].get_node("Actions/rename"))
	_check(scroll_before > 0 and modal._mode == "rename", "滚动列表底部打开二级弹窗")
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	_check(modal._selected == target and modal.slot_list._scroll.scroll_vertical == scroll_before, "取消二级弹窗保留滚动位置和选中项")
	await _click(modal._rows[target].get_node("Actions/delete"))
	await _click(modal._edit_modal._cancel_button)
	_check(modal._selected == target and modal.slot_list._scroll.scroll_vertical == scroll_before, "删除确认取消后仍保留滚动位置")
	var valid_slots: Array = modal._slots.filter(func(slot): return slot.problem.is_empty())
	var valid_target: String = valid_slots[-1].id
	await _click(modal._rows[valid_target].get_node("Actions/rename"))
	await type_name("滚动后改名")
	await _click(modal._edit_modal._confirm_button)
	await get_tree().create_timer(0.2).timeout
	_check(modal._mode == "list" and modal._selected == valid_target and modal.slot_list._scroll.scroll_vertical == scroll_before and JSON.parse_string(_disk(valid_target))[sm.SLOT_META_KEY].name == "滚动后改名", "重命名成功刷新后保留选择和滚动位置")
