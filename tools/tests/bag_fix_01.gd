extends "res://tools/tests/ch2_entry_state.gd"
const Run := preload("res://scripts/maze/capture_run.gd")
const Icon := preload("res://scripts/ui/components/bag_icon_display.gd")
const WARNING := "完成探索后带回餐厅，中途放弃将失去所有食材"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_icon_checks()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await get_tree().process_frame
			await _bag_checks()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("BAG_FIX_01 ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _icon_checks() -> void:
	var image := Image.create(100, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(25, 30, 20, 10), Color.WHITE)
	var source := ImageTexture.create_from_image(image)
	var result := Icon.texture(source)
	_check(result.get_size() == Vector2(20,10) and source.get_size() == Vector2(100,80), "透明边界裁显示副本且源纹理不变")
	_check(Icon.texture(source) == result, "重复查询复用缓存")
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(20,25,40,30)
	_check(Icon.texture(atlas).get_size() == Vector2(20,10), "图集子区域正确归一化")
	var blank := ImageTexture.create_from_image(Image.create(10,10,false,Image.FORMAT_RGBA8))
	_check(Icon.texture(blank) == blank, "全透明纹理安全回退")
	var legacy := SproutItemSlot.new()
	legacy.set_grid_mode(true)
	add_child(legacy)
	_check(legacy.custom_minimum_size == Vector2(56,56) and legacy._icon_view.size == Vector2(40,40), "未显式配置的格子保持原尺寸")
	legacy.queue_free()

func _bag_checks() -> void:
	_completed()
	sm.cancel_maze_entry()
	var maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	_check(maze._entry_ready, "实际迷宫入口就绪"+suffix)
	var modal = maze.backpack_warehouse
	for items in [{}, {"slime_gel":12,"slime_shell":123}, {"slime_gel":12,"slime_shell":123,"rock_salt":99,"rockmane_meat":101,"moondew_honey":3,"brick_snail_meat":4,"petrifying_lizard_tail":5}]:
		sm.data[Run.KEY].bag = items.duplicate()
		var before := JSON.stringify(sm.data)
		await _click(maze.backpack_entry)
		await get_tree().process_frame
		_check(modal.visible and maze.player.input_locked, "真实入口打开并锁定移动")
		_check(modal._message.text.replace("\n", "") == WARNING and modal._message.visible, "空态与非空态均显示准确风险文案")
		_layout(modal)
		await _shot("backpack_%d" % items.size())
		await _send_key(KEY_PAGEDOWN)
		_check(modal._scroll.scroll_vertical > 0, "键盘向下翻页")
		if items.size() > 3: await _shot("backpack_scrolled")
		await _send_key(KEY_HOME)
		_check(modal._scroll.scroll_vertical == 0, "键盘回顶")
		await _wheel(modal._scroll)
		_check(modal._scroll.scroll_vertical > 0, "鼠标滚轮滚动")
		await _send_key(KEY_ESCAPE)
		_check(not modal.visible and not maze.player.input_locked and JSON.stringify(sm.data) == before, "Esc恢复输入且暂存与库存不变")
	# 同一个实际组件切回仓库取料；夹具仅设置隔离库存，事务通过真实按钮提交。
	sm.data.warehouse_stock = {"rockmane_meat":123,"rock_salt":99}
	var old_inventory: int = sm.inventory_snapshot().get("rockmane_meat",0)
	modal.open_stock()
	await get_tree().process_frame
	_check(modal._heading.text == "仓库", "背包切仓库恢复标题")
	await _click(modal._meat_slot._icon_button)
	await _click(modal._salt_slot._icon_button)
	modal._meat_slot._item_name = "用于验收的超长岩鬃肉食材名称"
	modal._rebuild_selected_list()
	var row = modal._selected_rows.rockmane_meat
	var names: Array = row.find_children("*", "Label", true, false)
	for label in names:
		if label.text == "岩鬃肉": label.text = modal._meat_slot._item_name
	await get_tree().process_frame
	await get_tree().process_frame
	_layout(modal)
	_check(modal._selected.size() == 2 and modal._tabs.tab_count == 1, "仓库选择与全部分类保留")
	for label in names:
		_check(row.get_global_rect().encloses(label.get_global_rect()), "长名称与数量处于所选行范围")
	await _shot("warehouse_selected_long_name")
	await _click(modal._claim_button)
	_check(not modal.visible and sm.warehouse_snapshot().rockmane_meat == 122 and sm.inventory_snapshot().rockmane_meat == old_inventory+1, "真实取料事务恰好转移一份")
	modal.open_backpack({}, true)
	await _click(modal._cancel_button)
	_check(not modal.visible and not maze.player.input_locked, "鼠标关闭恢复输入")
	modal.open_empty_stock()
	await get_tree().process_frame
	_layout(modal)
	await _shot("warehouse_readonly")
	await _click(modal._cancel_button)
	maze.queue_free()
	await get_tree().process_frame

func _layout(modal: Control) -> void:
	var viewport := get_viewport().get_visible_rect()
	_check(viewport.encloses(modal._panel.get_global_rect()), "面板不超屏"+suffix)
	_check(modal._slots_grid.columns == 5, "仓库背包五列紧凑网格")
	var cells: Array = modal._slots_grid.get_children()
	_check(cells[0]._icon_button.size == Vector2(56,56), "格子与食谱同为56像素")
	_check(cells[0]._icon_view.position + cells[0]._icon_view.size * 0.5 == Vector2(28,28), "食材图标水平垂直居中")
	_check(absf(cells[0].size.x - cells[0].size.y) < 0.1 and cells[4].position.y == cells[0].position.y and cells[5].position.y > cells[0].position.y, "正方形格子与换行坐标")
	_check(modal._slots_grid.size.x - cells[4].get_rect().end.x < 10, "末列右侧无额外留白")
	_check(modal._scroll.get_h_scroll_bar().max_value <= modal._scroll.size.x, "无水平裁切")
	for cell in cells:
		if cell._quantity > 0:
			_check(cell.get_global_rect().encloses(cell._stock_badge.get_global_rect()), "两三位数量不超格："+cell.item_id)
	_check(modal._panel.get_global_rect().encloses(modal._cancel_button.get_global_rect()), "关闭按钮完整在面板内")
	if modal._message.visible:
		_check(modal._message.size.y >= modal._message.get_minimum_size().y, "提示文字完整换行")

func _wheel(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
