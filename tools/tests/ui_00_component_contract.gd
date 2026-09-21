extends SceneTree
## UI-00 最小合约测试：验证可实例化、主题状态、焦点与信号连接。

var _failures: Array[String] = []

func _initialize() -> void:
	var root := Control.new()
	root.name = "UI00ContractRoot"
	root.theme = SproutTheme.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(root)
	await process_frame

	var button := SproutButton.new()
	button.configure("测试按钮", 0)
	root.add_child(button)
	await process_frame
	if button.focus_mode != Control.FOCUS_ALL:
		_failures.append("SproutButton 未启用键盘焦点")
	if button.icon == null:
		_failures.append("SproutButton 未设置图标")
	button.set_meta("activated", false)
	button.activated.connect(func(_button: SproutButton) -> void: button.set_meta("activated", true))
	button.emit_signal("pressed")
	if not bool(button.get_meta("activated")):
		_failures.append("SproutButton activated 信号未转发")

	var slot := SproutItemSlot.new()
	root.add_child(slot)
	slot.configure("test", "测试物品", 2, 5)
	if slot.item_id != "test":
		_failures.append("SproutItemSlot 未保存 item_id")
	slot.set_meta("selected", "")
	slot.slot_selected.connect(func(id: String) -> void: slot.set_meta("selected", id))
	slot.disabled = true
	slot.emit_signal("pressed")
	if str(slot.get_meta("selected")) != "":
		_failures.append("禁用物品格不应发出选择信号")
	slot.disabled = false
	slot.emit_signal("pressed")
	if str(slot.get_meta("selected")) != "test":
		_failures.append("物品格未发出选择信号")

	var list := SproutScrollList.new()
	list.set_items([
		{"id": "one", "label": "第一项", "icon": 10},
		{"id": "two", "label": "第二项", "icon": 11},
		{"id": "three", "label": "第三项", "icon": 12},
		{"id": "four", "label": "第四项", "icon": 13},
	])
	root.add_child(list)
	await process_frame
	var scroll_count := 0
	for child in list.get_children():
		if child is ScrollContainer:
			scroll_count += 1
	var empty_label_count := 0
	for child in list.find_children("*", "Label", true, false):
		if child is Label and child.text == "暂无模拟条目":
			empty_label_count += 1
	var row_count := 0
	for child in list.find_children("*", "Button", true, false):
		if child is Button:
			row_count += 1
	print("UI00_LIFECYCLE scroll_containers=%d empty_labels=%d rows=%d" % [scroll_count, empty_label_count, row_count])
	if scroll_count != 1:
		_failures.append("SproutScrollList 应仅构建一个 ScrollContainer，实际 %d 个" % scroll_count)
	if empty_label_count != 0:
		_failures.append("非空 SproutScrollList 不应显示空状态，实际 %d 个" % empty_label_count)
	if row_count != 4:
		_failures.append("SproutScrollList 应显示四个条目，实际按钮数 %d" % row_count)
	var scroll_nodes := list.find_children("*", "ScrollContainer", false, false)
	if scroll_nodes.is_empty():
		_failures.append("SproutScrollList 缺少 ScrollContainer，无法验证滚动")
	else:
		var list_scroll := scroll_nodes[0] as ScrollContainer
		list_scroll.set_deferred("scroll_vertical", 100)
		await process_frame
		if list_scroll.get_v_scroll_bar().max_value <= 0.0:
			_failures.append("SproutScrollList 条目未形成可滚动内容")
	list.set_meta("selected", "")
	list.item_selected.connect(func(id: String) -> void: list.set_meta("selected", id))
	var list_buttons := list.find_children("*", "Button", true, false)
	if not list_buttons.is_empty():
		(list_buttons[0] as Button).emit_signal("pressed")
	if str(list.get_meta("selected")) != "one":
		_failures.append("列表条目选择信号未传递 id")
	list.set_items([])
	await process_frame
	var empty_count_after_clear := 0
	for child in list.find_children("*", "Label", true, false):
		if child is Label and child.text == "暂无模拟条目":
			empty_count_after_clear += 1
	if empty_count_after_clear != 1:
		_failures.append("空列表应显示且仅显示一个空状态")
	list.set_items([
		{"id": "one", "label": "第一项", "icon": 10},
		{"id": "two", "label": "第二项", "icon": 11},
		{"id": "three", "label": "第三项", "icon": 12},
		{"id": "four", "label": "第四项", "icon": 13},
	])
	await process_frame
	var final_scroll_count := 0
	for child in list.get_children():
		if child is ScrollContainer:
			final_scroll_count += 1
	var final_empty_label_count := 0
	for child in list.find_children("*", "Label", true, false):
		if child is Label and child.text == "暂无模拟条目":
			final_empty_label_count += 1
	if final_scroll_count != 1 or final_empty_label_count != 0:
		_failures.append("重复 set_items 后滚动容器/空状态节点不一致")

	var tabs := SproutCategoryTabs.new()
	tabs.set_categories([
		{"id": "food", "label": "料理"},
		{"id": "tool", "label": "工具"},
		{"id": "key", "label": "素材"},
	])
	root.add_child(tabs)
	await process_frame
	var tabs_container_count := 0
	for child in tabs.get_children():
		if child is HBoxContainer:
			tabs_container_count += 1
	var tab_button_count := 0
	for child in tabs.find_children("*", "Button", true, false):
		if child is Button:
			tab_button_count += 1
	print("UI00_LIFECYCLE tab_containers=%d buttons=%d" % [tabs_container_count, tab_button_count])
	if tabs_container_count != 1:
		_failures.append("SproutCategoryTabs 应仅构建一个分类容器，实际 %d 个" % tabs_container_count)
	if tab_button_count != 3:
		_failures.append("分类页应显示三个分类按钮，实际 %d 个" % tab_button_count)
	if tabs.selected_id != "food":
		_failures.append("SproutCategoryTabs 未选择首个分类")
	tabs.set_meta("changed", "")
	tabs.category_changed.connect(func(id: String) -> void: tabs.set_meta("changed", id))
	var category_buttons := tabs.find_children("*", "Button", true, false)
	for category_button in category_buttons:
		if (category_button as Button).text == "工具":
			(category_button as Button).emit_signal("pressed")
	if tabs.selected_id != "tool" or str(tabs.get_meta("changed")) != "tool":
		_failures.append("分类选择未更新选中状态与信号")

	var modal := SproutModal.new()
	root.add_child(modal)
	await process_frame
	modal.set_meta("confirmed_count", 0)
	modal.set_meta("cancelled_count", 0)
	modal.set_meta("closed_count", 0)
	modal.confirmed.connect(func() -> void: modal.set_meta("confirmed_count", int(modal.get_meta("confirmed_count")) + 1))
	modal.cancelled.connect(func() -> void: modal.set_meta("cancelled_count", int(modal.get_meta("cancelled_count")) + 1))
	modal.closed.connect(func() -> void: modal.set_meta("closed_count", int(modal.get_meta("closed_count")) + 1))
	var modal_buttons := modal.find_children("*", "Button", true, false)
	var confirm_button: Button
	var cancel_button: Button
	var close_button: Button
	for modal_button in modal_buttons:
		match (modal_button as Button).text:
			"确认":
				confirm_button = modal_button as Button
			"取消":
				cancel_button = modal_button as Button
			"×":
				close_button = modal_button as Button
	if modal._confirm_button.icon != null or modal._cancel_button.icon != null:
		_failures.append("弹窗确认/取消按钮不应显示图标")
	if modal._confirm_button.focus_mode != Control.FOCUS_ALL or modal._cancel_button.focus_mode != Control.FOCUS_ALL:
		_failures.append("弹窗确认/取消按钮应保持键盘焦点")
	if not modal._confirm_button.get_theme_stylebox("focus") is StyleBoxEmpty or not modal._cancel_button.get_theme_stylebox("focus") is StyleBoxEmpty:
		_failures.append("弹窗确认/取消按钮不应绘制额外焦点框")
	if not button.get_theme_stylebox("focus") is StyleBoxFlat or button.icon == null:
		_failures.append("普通 SproutButton 的图标/焦点样式发生回归")
	modal.show_modal("测试", "内容")
	if not modal.visible:
		_failures.append("SproutModal 未打开")
	if get_root().gui_get_focus_owner() != confirm_button:
		_failures.append("弹窗打开后焦点未交给确认按钮")
	if confirm_button != null:
		confirm_button.emit_signal("pressed")
	if modal.visible:
		_failures.append("确认后弹窗未关闭")
	modal.show_modal("测试", "内容")
	if cancel_button != null:
		cancel_button.emit_signal("pressed")
	if modal.visible:
		_failures.append("取消后弹窗未关闭")
	modal.show_modal("测试", "内容")
	if close_button != null:
		close_button.emit_signal("pressed")
	if modal.visible:
		_failures.append("关闭按钮未关闭弹窗")
	modal.show_modal("测试", "内容")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	modal._unhandled_input(escape)
	if modal.visible:
		_failures.append("Esc 未关闭弹窗")
	if int(modal.get_meta("confirmed_count")) != 1:
		_failures.append("确认信号计数错误")
	if int(modal.get_meta("cancelled_count")) != 3:
		_failures.append("取消/关闭/Esc 信号计数错误")
	if int(modal.get_meta("closed_count")) != 4:
		_failures.append("closed 信号计数错误")
	var focus_after_close := get_root().gui_get_focus_owner()
	if is_instance_valid(focus_after_close) and modal.is_ancestor_of(focus_after_close):
		_failures.append("弹窗关闭后仍有内部控件占用键盘焦点")
	root.queue_free()
	await process_frame

	if _failures.is_empty():
		print("UI00_CONTRACT_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("UI00_CONTRACT_FAILED")
		quit(1)
