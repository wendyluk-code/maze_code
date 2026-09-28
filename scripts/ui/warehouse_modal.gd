extends Control
## 仓库界面：5×6 食材图标网格，以及独立的已选择食材列表。

signal claimed(result: Dictionary)
signal cancelled
signal inspected

const MAX_ITEM_QUANTITY := 999
const GRID_COLUMNS := 5
const MAX_GRID_ITEMS := 30
const GRID_CELL_SIZE := SproutItemSlot.GRID_SIZE
const GRID_VISIBLE_HEIGHT := 3.5 * GRID_CELL_SIZE.y + 3 * 4
const PANEL_WIDTH := 5 * GRID_CELL_SIZE.x + 4 * 4 + 12 + 16
const ROCK_SALT_ICON: Texture2D = preload("res://assets/ui/ingredients/rock_salt.png")
const ROCKMANE_MEAT_ICON: Texture2D = preload("res://assets/ui/ingredients/rockmane_meat.png")
const DISH_ICON: Texture2D = preload("res://assets/ui/ingredients/salt_grilled_rockmane.png")

var _overlay: ColorRect
var _panel: PanelContainer
var _meat_slot: SproutItemSlot
var _salt_slot: SproutItemSlot
var _dish_slot: SproutItemSlot
var _selection_label: Label
var _message: Label
var _empty_label: Label
var _cancel_button: SproutButton
var _claim_button: SproutButton
var _selected := {}
var _open := false
var _empty_stock := false
var _stock_title: Label
var _slots_grid: GridContainer
var _scroll: ScrollContainer
var _grid_hover_region: Control
var _grid_scrollbar_dragging := false
var _tabs: TabBar
var _slot_by_id := {}
var _selected_title: Label
var _selected_scroll: ScrollContainer
var _selected_list: VBoxContainer
var _selected_empty_label: Label
var _selected_rows := {}
var _selection_area: PanelContainer
var _hidden_guide: Control
var _guide_was_visible := false
var _catalog := [
	{"id": "rockmane_meat", "name": "岩鬃肉", "icon": 0},
	{"id": "rock_salt", "name": "岩盐", "icon": 1},
	{"id": "salt_grilled_rockmane", "name": "盐烤岩鬃肉", "icon": 2},
]

func _ready() -> void:
	add_to_group("warehouse_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	resized.connect(_layout_modal)
	_layout_modal()

func _layout_modal() -> void:
	if not is_instance_valid(_panel):
		return
	var panel_height := minf(480.0, size.y - 16.0)
	var panel_width := PANEL_WIDTH + _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_panel.position = Vector2((size.x - panel_width) * 0.5, (size.y - panel_height) * 0.5)
	_panel.size = Vector2(panel_width, panel_height)

func _process(_delta: float) -> void:
	if not _open:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_grid_scrollbar_dragging = false
	_update_grid_scrollbar()

func _update_grid_scrollbar() -> void:
	# 保留轨道宽度，仅控制显示，避免显隐改变五列网格布局。
	var hovered := _grid_hover_region.get_global_rect().has_point(get_global_mouse_position())
	_scroll.get_v_scroll_bar().self_modulate.a = 1.0 if _open and (hovered or _grid_scrollbar_dragging) else 0.0

func _on_grid_scrollbar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_grid_scrollbar_dragging = event.pressed

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.07, 0.05, 0.66)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "WarehousePanel"
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", _box(Color("#f0d4a1"), Color("#a98049"), 2, 8))
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_panel.add_child(outer)

	var heading := Label.new()
	heading.text = "仓库"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(heading)

	_tabs = TabBar.new()
	_tabs.name = "CategoryTabs"
	_tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	_tabs.add_tab("全部")
	_tabs.custom_minimum_size = Vector2(0, 26)
	_tabs.add_theme_font_size_override("font_size", 16)
	outer.add_child(_tabs)

	_stock_title = Label.new()
	_stock_title.text = "食材"
	_stock_title.visible = false
	_stock_title.add_theme_font_size_override("font_size", 18)
	_stock_title.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(_stock_title)

	var grid_background := PanelContainer.new()
	_grid_hover_region = grid_background
	grid_background.name = "GridBackground"
	grid_background.add_theme_stylebox_override("panel", _box(Color("#cbb28a"), Color("#b5996d"), 1, 6))
	outer.add_child(grid_background)
	_scroll = ScrollContainer.new()
	_scroll.name = "MaterialScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.custom_minimum_size = Vector2(0, GRID_VISIBLE_HEIGHT)
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.follow_focus = true
	grid_background.add_child(_scroll)
	_scroll.get_v_scroll_bar().self_modulate.a = 0.0
	_scroll.get_v_scroll_bar().gui_input.connect(_on_grid_scrollbar_input)

	_slots_grid = GridContainer.new()
	_slots_grid.name = "MaterialGrid"
	_slots_grid.columns = GRID_COLUMNS
	_slots_grid.add_theme_constant_override("h_separation", 4)
	_slots_grid.add_theme_constant_override("v_separation", 4)
	_slots_grid.custom_minimum_size = Vector2(0, 6.0 * GRID_CELL_SIZE.y + 5.0 * 4.0)
	_slots_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_scroll.add_child(_slots_grid)
	_build_catalog()

	_empty_label = Label.new()
	_empty_label.text = "仓库暂无材料"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	_empty_label.visible = false
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_empty_label)

	_selected_title = Label.new()
	_selected_title.text = "已选择食材"
	_selected_title.add_theme_font_size_override("font_size", 18)
	_selected_title.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(_selected_title)

	_selection_area = PanelContainer.new()
	_selection_area.name = "SelectedFoodBackground"
	_selection_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selection_area.add_theme_stylebox_override("panel", _box(Color("#f5e5c6"), Color("#d4b986"), 1, 4))
	outer.add_child(_selection_area)
	_selected_scroll = ScrollContainer.new()
	_selected_scroll.name = "SelectedFoodScroll"
	_selected_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_selected_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_selected_scroll.custom_minimum_size = Vector2(0, 72)
	_selected_scroll.follow_focus = true
	_selection_area.add_child(_selected_scroll)

	_selected_list = VBoxContainer.new()
	_selected_list.name = "SelectedFoodList"
	_selected_list.add_theme_constant_override("separation", 3)
	_selected_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_scroll.add_child(_selected_list)
	_selected_empty_label = Label.new()
	_selected_empty_label.text = ""
	_selected_empty_label.visible = false
	_selected_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_empty_label.add_theme_font_size_override("font_size", 15)
	_selected_empty_label.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	_selected_empty_label.custom_minimum_size = Vector2(0, 36)
	_selected_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_list.add_child(_selected_empty_label)

	_selection_label = Label.new()
	_selection_label.text = "已选择 0 种，共 0 份"
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.add_theme_font_size_override("font_size", 16)
	_selection_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_selection_label.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	_selection_label.visible = false
	outer.add_child(_selection_label)

	_message = Label.new()
	_message.text = ""
	_message.visible = false
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 15)
	_message.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	outer.add_child(_message)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.custom_minimum_size.y = 38
	actions.add_theme_constant_override("separation", 10)
	outer.add_child(actions)

	_cancel_button = SproutButton.new()
	_cancel_button.configure("取消")
	_cancel_button.set_icon_visible(false)
	_cancel_button.set_focus_visual(false)
	_cancel_button.custom_minimum_size = Vector2(120, 44)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	actions.add_child(_cancel_button)
	_cancel_button.custom_minimum_size = Vector2(120, 38)
	_cancel_button.size_flags_vertical = Control.SIZE_SHRINK_END

	_claim_button = SproutButton.new()
	_claim_button.configure("取出材料")
	_claim_button.set_icon_visible(false)
	_claim_button.set_focus_visual(false)
	_claim_button.custom_minimum_size = Vector2(160, 44)
	_claim_button.disabled = true
	_claim_button.pressed.connect(_on_claim_pressed)
	actions.add_child(_claim_button)
	_claim_button.custom_minimum_size = Vector2(160, 38)
	_claim_button.size_flags_vertical = Control.SIZE_SHRINK_END

func _box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _build_catalog() -> void:
	for i in range(MAX_GRID_ITEMS):
		var entry: Dictionary
		if i < _catalog.size():
			entry = _catalog[i]
		else:
			entry = {"id": "reserved_%02d" % (i + 1), "name": "", "icon": 0}
		var slot := _create_slot(str(entry.id), str(entry.name), int(entry.icon))
		_slot_by_id[slot.item_id] = slot
		_slots_grid.add_child(slot)
		if slot.item_id == "rockmane_meat":
			_meat_slot = slot
		elif slot.item_id == "rock_salt":
			_salt_slot = slot
		elif slot.item_id == "salt_grilled_rockmane":
			_dish_slot = slot

func _create_slot(id: String, label_text: String, icon_index: int) -> SproutItemSlot:
	var slot := SproutItemSlot.new()
	slot.name = id
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.custom_minimum_size = GRID_CELL_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.slot_selected.connect(_on_slot_selected)
	slot.selection_changed.connect(_on_slot_quantity_changed)
	slot.configure(id, label_text, 0, icon_index, true)
	slot.set_grid_mode(true)
	if id == "rock_salt":
		slot.set_icon_texture(_ingredient_icon(ROCK_SALT_ICON, Rect2(83, 88, 97, 90)))
	elif id == "rockmane_meat":
		slot.set_icon_texture(_ingredient_icon(ROCKMANE_MEAT_ICON, Rect2(77, 83, 106, 95)))
	elif id == "salt_grilled_rockmane":
		slot.set_icon_texture(_ingredient_icon(DISH_ICON, Rect2(279, 424, 696, 505)))
	return slot

func _ingredient_icon(source: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = region
	return texture

func open_for_order() -> void:
	_empty_stock = false
	_selected.clear()
	_stock_title.text = "食材"
	_message.text = ""
	_message.visible = false
	_cancel_button.configure("取消")
	_claim_button.configure("取出材料")
	_claim_button.visible = true
	_selected_title.visible = true
	_selected_scroll.visible = true
	_selection_area.visible = true
	_empty_label.visible = false
	for item_id in _slot_by_id:
		var slot: SproutItemSlot = _slot_by_id[item_id]
		var available := 1 if item_id in ["rockmane_meat", "rock_salt"] else 0
		_set_slot(slot, available, available <= 0, true)
	_open = true
	visible = true
	_scroll.scroll_vertical = 0
	_selected_scroll.scroll_vertical = 0
	_grid_scrollbar_dragging = false
	_update_grid_scrollbar()
	_update_selection()
	_set_tutorial_suppressed(true)

func open_empty_stock() -> void:
	_empty_stock = true
	_selected.clear()
	_open = true
	visible = true
	var stock := SaveManager.inventory_snapshot()
	_stock_title.text = "食材"
	_message.text = "当前库存一览" if _has_stock(stock) else "没有任何食物"
	_message.visible = true
	_cancel_button.configure("确认")
	_claim_button.visible = false
	_selected_title.visible = false
	_selected_scroll.visible = false
	_selection_area.visible = false
	_selection_label.visible = false
	_empty_label.visible = false
	_scroll.scroll_vertical = 0
	_grid_scrollbar_dragging = false
	_update_grid_scrollbar()
	for item_id in _slot_by_id:
		var slot: SproutItemSlot = _slot_by_id[item_id]
		var quantity := int(stock.get(item_id, 0))
		_set_slot(slot, quantity, true, true)
	_update_selection()
	_set_tutorial_suppressed(true)

func _has_stock(stock: Dictionary) -> bool:
	for item_id in ["rockmane_meat", "rock_salt", "salt_grilled_rockmane"]:
		if int(stock.get(item_id, 0)) > 0:
			return true
	return false

func _set_slot(slot: SproutItemSlot, quantity: int, disabled_state: bool, slot_visible: bool) -> void:
	slot.configure(slot.item_id, slot._item_name, clampi(quantity, 0, MAX_ITEM_QUANTITY), slot._icon_index, disabled_state)
	slot.set_selected_quantity(0)
	slot.set_selected(false)
	slot.visible = slot_visible

func close_modal() -> void:
	_open = false
	_grid_scrollbar_dragging = false
	_update_grid_scrollbar()
	visible = false
	_set_tutorial_suppressed(false)

func _on_slot_selected(item_id: String) -> void:
	if not _open or _empty_stock:
		return
	var slot: SproutItemSlot = _slot_by_id.get(item_id)
	if not is_instance_valid(slot) or slot.disabled or slot._quantity <= 0:
		return
	slot.set_selected_quantity(slot.get_selected_quantity() + 1, true)

func _on_slot_quantity_changed(item_id: String, quantity: int) -> void:
	if not _open or _empty_stock:
		return
	if quantity <= 0:
		_selected.erase(item_id)
	else:
		_selected[item_id] = quantity
	var slot: SproutItemSlot = _slot_by_id.get(item_id)
	if is_instance_valid(slot):
		slot.set_selected(quantity > 0)
	_update_selection()

func _update_selection() -> void:
	var kinds := 0
	var total := 0
	for value in _selected.values():
		var quantity := int(value)
		if quantity > 0:
			kinds += 1
			total += quantity
	_selection_label.text = "已选择 %d 种，共 %d 份" % [kinds, total]
	_selected_title.text = "已选择食材"
	_claim_button.disabled = not _is_first_order_selection()
	_rebuild_selected_list()

func _rebuild_selected_list() -> void:
	if not is_instance_valid(_selected_list):
		return
	for item_id in _selected_rows.keys():
		if not _selected.has(item_id):
			var row: Control = _selected_rows[item_id]
			var focus := get_viewport().gui_get_focus_owner()
			var focused := is_instance_valid(focus) and row.is_ancestor_of(focus)
			_selected_list.remove_child(row)
			row.queue_free()
			_selected_rows.erase(item_id)
			if focused:
				_slot_by_id[item_id]._icon_button.grab_focus()
	var visible_count := 0
	for item_id in _selected:
		var quantity := int(_selected[item_id])
		if quantity <= 0:
			continue
		visible_count += 1
		var slot: SproutItemSlot = _slot_by_id.get(item_id)
		if not is_instance_valid(slot):
			continue
		if not _selected_rows.has(item_id):
			var row := _make_selected_row(item_id, slot, quantity)
			_selected_rows[item_id] = row
			_selected_list.add_child(row)
		var content: HBoxContainer = _selected_rows[item_id].get_child(0)
		content.get_node("Count").text = str(quantity)
		content.get_node("Plus").disabled = quantity >= slot._quantity
	if visible_count == 0:
		if _selected_empty_label.get_parent() != _selected_list:
			_selected_list.add_child(_selected_empty_label)
		_selected_empty_label.visible = false
	else:
		_selected_empty_label.visible = false

func _make_selected_row(item_id: String, slot: SproutItemSlot, quantity: int) -> Control:
	var row := PanelContainer.new()
	row.name = "Selected_" + item_id
	row.custom_minimum_size = Vector2(0, 32)
	row.add_theme_stylebox_override("panel", _box(Color("#fff7e5"), Color("#dfcaa5"), 1, 3))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	row.add_child(content)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = slot.get_icon_texture()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var name_label := Label.new()
	name_label.text = slot._item_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", SproutTheme.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	var minus := _make_quantity_button("−")
	minus.name = "Minus"
	minus.pressed.connect(_change_selected_quantity.bind(item_id, -1))
	content.add_child(minus)
	var count := Label.new()
	count.name = "Count"
	count.add_theme_font_override("font", ThemeDB.fallback_font)
	count.text = str(quantity)
	count.custom_minimum_size = Vector2(34, 26)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 15)
	count.add_theme_color_override("font_color", SproutTheme.INK)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(count)
	var plus := _make_quantity_button("+")
	plus.name = "Plus"
	plus.pressed.connect(_change_selected_quantity.bind(item_id, 1))
	content.add_child(plus)
	return row

func _make_quantity_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(28, 26)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := _box(Color("#eadfbe"), Color("#b99055"), 1, 2)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", SproutTheme.INK)
	return button

func _change_selected_quantity(item_id: String, delta: int) -> void:
	if not _open or _empty_stock:
		return
	var slot: SproutItemSlot = _slot_by_id.get(item_id)
	if not is_instance_valid(slot):
		return
	slot.set_selected_quantity(slot.get_selected_quantity() + delta, true)

func _is_first_order_selection() -> bool:
	return _selected.get("rockmane_meat", 0) == 1 and _selected.get("rock_salt", 0) == 1 and _selected.size() == 2

func _on_cancel_pressed() -> void:
	if not _open:
		return
	close_modal()
	if _empty_stock:
		inspected.emit()
	else:
		cancelled.emit()

func _on_claim_pressed() -> void:
	if _empty_stock:
		return
	if not _open or not _is_first_order_selection():
		_message.text = "首单需要选择岩鬃肉 ×1、岩盐 ×1"
		_message.visible = true
		return
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("claim_first_order_ingredients"):
		_message.text = "仓库暂时无法取出材料"
		_message.visible = true
		return
	var result: Dictionary = sm.claim_first_order_ingredients()
	if bool(result.get("success", false)):
		close_modal()
		claimed.emit(result)
	else:
		_message.text = "取出失败，当前库存未改变"
		_message.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func _set_tutorial_suppressed(value: bool) -> void:
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide) and guide.has_method("set_modal_suppressed"):
		guide.set_modal_suppressed(value)
		# 模态内隐藏背景教程，计时器继续运行；关闭后恢复父节点，不重播过期提示。
		if value and not is_instance_valid(_hidden_guide):
			_hidden_guide = guide
			_guide_was_visible = guide.visible
			guide.visible = false
		elif not value and is_instance_valid(_hidden_guide):
			_hidden_guide.visible = _guide_was_visible
			_hidden_guide = null
