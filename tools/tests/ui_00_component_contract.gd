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

	var list := SproutScrollList.new()
	root.add_child(list)
	list.set_items([])
	if list.get_child_count() == 0:
		_failures.append("SproutScrollList 未建立滚动容器")

	var tabs := SproutCategoryTabs.new()
	root.add_child(tabs)
	tabs.set_categories([{"id": "a", "label": "甲"}, {"id": "b", "label": "乙"}])
	if tabs.selected_id != "a":
		_failures.append("SproutCategoryTabs 未选择首个分类")

	var modal := SproutModal.new()
	root.add_child(modal)
	await process_frame
	modal.show_modal("测试", "内容")
	if not modal.visible:
		_failures.append("SproutModal 未打开")
	modal.close_modal()
	if modal.visible:
		_failures.append("SproutModal 未关闭")

	if _failures.is_empty():
		print("UI00_CONTRACT_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("UI00_CONTRACT_FAILED")
		quit(1)
