extends Control
## UI-00 独立预览：所有数据为模拟数据，不接游戏业务状态。

var _status: Label
var _category_content: Label
var _modal: SproutModal
var _list: SproutScrollList
var _empty_mode := false
var _action_count := 0
var _capture_path := ""

func _ready() -> void:
	theme = SproutTheme.make_theme()
	_build_preview()
	var args := OS.get_cmdline_user_args()
	if args.has("--ui00-open-modal"):
		_show_demo_modal()
	var capture_index := args.find("--ui00-capture")
	if capture_index >= 0 and capture_index + 1 < args.size():
		_capture_path = args[capture_index + 1]
		_capture_after_render.call_deferred()

func _capture_after_render() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(_capture_path)
	if result != OK:
		push_error("UI00_CAPTURE_FAILED path=%s error=%d" % [_capture_path, result])
		get_tree().quit(1)
		return
	print("UI00_CAPTURE_OK path=%s size=%dx%d" % [_capture_path, image.get_width(), image.get_height()])
	get_tree().quit()

func _build_preview() -> void:
	var background := ColorRect.new()
	background.color = Color("#33483b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var heading := PanelContainer.new()
	heading.theme = SproutTheme.make_theme()
	heading.custom_minimum_size.y = 74
	page.add_child(heading)
	var heading_box := VBoxContainer.new()
	heading.add_child(heading_box)
	var title := Label.new()
	title.text = "Sprout Lands · 组件预览"
	title.add_theme_font_size_override("font_size", 28)
	heading_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "UI-00 仅演示控件状态与输入反馈　|　模拟数据"
	subtitle.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	heading_box.add_child(subtitle)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	page.add_child(columns)
	columns.add_child(_make_actions_panel())
	columns.add_child(_make_items_panel())
	columns.add_child(_make_categories_panel())

	_status = Label.new()
	_status.text = "状态：等待操作"
	_status.custom_minimum_size.y = 32
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("#f5e8c7"))
	page.add_child(_status)

	_modal = SproutModal.new()
	add_child(_modal)
	_modal.confirmed.connect(func() -> void: _set_status("确认事件已触发，弹窗已关闭"))
	_modal.cancelled.connect(func() -> void: _set_status("取消/关闭事件已触发，弹窗已关闭"))

func _make_section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = SproutTheme.make_theme()
	var panel_style := SproutTheme.panel_style()
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 21)
	box.add_child(heading)
	return panel

func _section_content(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer

func _make_actions_panel() -> PanelContainer:
	var panel := _make_section("操作按钮")
	var box := _section_content(panel)
	var open_button := SproutButton.new()
	open_button.configure("打开通用弹窗", 0)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.pressed.connect(_show_demo_modal)
	box.add_child(open_button)
	var count_button := SproutButton.new()
	count_button.configure("记录一次点击", 1)
	count_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_button.pressed.connect(func() -> void:
		_action_count += 1
		_set_status("按钮点击计数：%d" % _action_count)
	)
	box.add_child(count_button)
	var disabled_button := SproutButton.new()
	disabled_button.configure("禁用状态示例", 2)
	disabled_button.disabled = true
	disabled_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(disabled_button)
	var hint := Label.new()
	hint.text = "可用按钮支持鼠标与键盘焦点激活"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	box.add_child(hint)
	return panel

func _make_items_panel() -> PanelContainer:
	var panel := _make_section("物品格")
	var box := _section_content(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var items := [
		["apple", "苹果", 3, 5, false],
		["herb", "香草", 8, 6, false],
		["mushroom", "蘑菇", 1, 7, false],
		["locked", "锁定格", 0, 8, true],
	]
	for data in items:
		var slot := SproutItemSlot.new()
		slot.configure(data[0], data[1], data[2], data[3], data[4])
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.slot_selected.connect(func(id: String) -> void:
			for child in grid.get_children():
				if child is SproutItemSlot:
					child.set_selected(child.item_id == id)
			_set_status("已选中模拟物品：%s" % id)
		)
		grid.add_child(slot)
	var hint := Label.new()
	hint.text = "选中与禁用仅影响展示，不修改库存"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	box.add_child(hint)
	return panel

func _make_categories_panel() -> PanelContainer:
	var panel := _make_section("分类页与滚动列表")
	var box := _section_content(panel)
	var tabs := SproutCategoryTabs.new()
	tabs.custom_minimum_size.y = 48
	tabs.category_changed.connect(_on_category_changed)
	box.add_child(tabs)
	tabs.set_categories([
		{"id": "food", "label": "料理"},
		{"id": "tool", "label": "工具"},
		{"id": "key", "label": "素材"},
	])
	_category_content = Label.new()
	_category_content.text = "分类内容：料理"
	_category_content.custom_minimum_size.y = 26
	box.add_child(_category_content)
	_list = SproutScrollList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 260
	_list.item_selected.connect(func(id: String) -> void: _set_status("列表选中模拟条目：%s" % id))
	box.add_child(_list)
	var empty_button := SproutButton.new()
	empty_button.configure("切换空状态", 9)
	empty_button.custom_minimum_size.y = 40
	empty_button.pressed.connect(_toggle_empty_state)
	box.add_child(empty_button)
	_list.set_items([
		{"id": "soup", "label": "蘑菇汤订单", "icon": 10},
		{"id": "bread", "label": "烤面包订单", "icon": 11},
		{"id": "tea", "label": "香草茶订单", "icon": 12},
		{"id": "jam", "label": "浆果果酱订单", "icon": 13},
	])
	return panel

func _show_demo_modal() -> void:
	_modal.show_modal("通用弹窗示例", "这是局部组件预览。确认、取消、右上角关闭与 Esc 都会关闭弹窗，并把结果写入底部状态栏。", "确认操作")

func _on_category_changed(category_id: String) -> void:
	var labels := {"food": "料理", "tool": "工具", "key": "素材"}
	if is_instance_valid(_category_content):
		_category_content.text = "分类内容：%s" % labels.get(category_id, category_id)
	_set_status("已切换分类：%s" % labels.get(category_id, category_id))

func _toggle_empty_state() -> void:
	_empty_mode = not _empty_mode
	if _empty_mode:
		_list.set_items([])
		_set_status("列表已切换为空状态")
	else:
		_list.set_items([
			{"id": "soup", "label": "蘑菇汤订单", "icon": 10},
			{"id": "bread", "label": "烤面包订单", "icon": 11},
			{"id": "tea", "label": "香草茶订单", "icon": 12},
			{"id": "jam", "label": "浆果果酱订单", "icon": 13},
		])
		_set_status("列表已恢复模拟条目")

func _set_status(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = "状态：" + message
