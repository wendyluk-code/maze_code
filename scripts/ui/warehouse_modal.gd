extends Control
## 仓库界面：五列大图标网格，以及独立的已选择食材列表。

signal claimed(result: Dictionary)
signal cancelled
signal inspected

const MAX_ITEM_QUANTITY := 999
const GRID_COLUMNS := 5
const MAX_GRID_ITEMS := 30
const GRID_CELL_SIZE := Vector2(56, 56)
const GRID_VISIBLE_HEIGHT := 3.5 * GRID_CELL_SIZE.y + 3 * 4
const PANEL_WIDTH := 324.0
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
var _general_stock := false
var _backpack_view := false
var _temporary_backpack: Dictionary = {}
var _heading: Label
var _stock_title: Label
var _slots_grid: GridContainer
var _scroll: ScrollContainer
var _grid_hover_region: Control
var _grid_scrollbar_dragging := false
var _tabs: TabBar
var _slot_by_id := {}
var _backpack_slot_order: Array[Node] = []
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
	var recipes := preload("res://scripts/cooking/recipe_catalog.gd")
	_catalog.append({"id": "wood", "name": "木材", "icon": 0})
	for item in preload("res://data/maze/elder_firewood.gd").REWARD_ITEMS:
		if not recipes.INGREDIENTS.has(item.id): _catalog.append({"id": item.id, "name": item.name, "icon": 0})
	for id in recipes.INGREDIENTS:
		if id not in ["rockmane_meat", "rock_salt"]:
			_catalog.append({"id": id, "name": recipes.INGREDIENTS[id].name, "icon": 0})
	for id in recipes.RECIPES:
		if id != "salt_grilled_rockmane": _catalog.append({"id": id, "name": recipes.RECIPES[id].name, "icon": 0})
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
	_tabs.visible = not _backpack_view
	(_cancel_button.get_parent() as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER if _backpack_view else BoxContainer.ALIGNMENT_END
	_scroll.custom_minimum_size.y = 4 * 56 + 3 * 4 if _backpack_view else GRID_VISIBLE_HEIGHT
	var panel_width := PANEL_WIDTH + _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_panel.custom_minimum_size = Vector2(panel_width, 0)
	_panel.size = Vector2(panel_width, _panel.get_combined_minimum_size().y)
	_panel.position = (size - _panel.size) * 0.5

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
	_overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "WarehousePanel"
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", _box(Color("#f0d4a1"), Color("#a98049"), 2, 8))
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_panel)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 4)
	_panel.add_child(frame)

	# 内容区始终占满剩余高度，隐藏选择列表时也保持底部按钮栏的位置。
	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_theme_constant_override("separation", 4)
	frame.add_child(outer)

	var heading := Label.new()
	_heading = heading
	heading.text = "仓库"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(heading)

	_tabs = preload("res://scripts/ui/components/sprout_tab_bar.gd").new()
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
	_slots_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_slots_grid)
	_build_catalog()
	_slots_grid.resized.connect(_fit_square_slots)
	call_deferred("_fit_square_slots")

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
	_selection_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	_selection_label.add_theme_font_override("font", SproutTheme.FONT_CN)
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
	frame.add_child(actions)

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

func _fit_square_slots() -> void:
	if not is_instance_valid(_slots_grid) or _slots_grid.size.x <= 0:
		return
	var side := 56.0
	if side < 56.0:
		return
	for slot in _slots_grid.get_children():
		if slot is SproutItemSlot:
			slot.configure_grid_display(Vector2(side, side), Vector2(40, 40), true)

func _create_slot(id: String, label_text: String, icon_index: int) -> SproutItemSlot:
	var slot := SproutItemSlot.new()
	slot.name = id
	# 槽位横向填满网格列，避免网格左右出现额外留白；图标仍在正方形槽内居中。
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = GRID_CELL_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.slot_selected.connect(_on_slot_selected)
	slot.selection_changed.connect(_on_slot_quantity_changed)
	slot.configure(id, label_text, 0, icon_index, true)
	slot.set_grid_mode(true)
	slot.configure_grid_display(GRID_CELL_SIZE, Vector2(40, 40), true)
	if id == "rock_salt":
		slot.set_icon_texture(_ingredient_icon(ROCK_SALT_ICON, Rect2(83, 88, 97, 90)))
	elif id == "rockmane_meat":
		slot.set_icon_texture(_ingredient_icon(ROCKMANE_MEAT_ICON, Rect2(77, 83, 106, 95)))
	elif id in ["lantern_berry", "insulating_leaf", "sour_vine_juice"]:
		for item in preload("res://data/maze/elder_firewood.gd").REWARD_ITEMS:
			if item.id == id:
				slot.set_icon_texture(preload("res://data/maze/elder_firewood.gd").reward_texture(item))
	elif id == "slime_gel":
		slot.set_icon_texture(preload("res://assets/ui/ingredients/slime_gel.png"))
	elif id == "wood":
		slot.set_icon_texture(_ingredient_icon(preload("res://generated_assets/wood_logs_pixel_256.png"), Rect2(40, 60, 177, 155)))
	elif id == "salt_grilled_rockmane":
		slot.set_icon_texture(_ingredient_icon(DISH_ICON, Rect2(279, 424, 696, 505)))
	var configured_icon := preload("res://scripts/cooking/recipe_catalog.gd").item_texture(id)
	if configured_icon != null: slot.set_icon_texture(configured_icon)
	return slot

func _ingredient_icon(source: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = region
	return texture

func open_for_order() -> void:
	_heading.text = "仓库"
	_restore_slot_order()
	_backpack_view = false
	_general_stock = false
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
	call_deferred("_layout_modal")

func open_empty_stock() -> void:
	_heading.text = "仓库"
	_restore_slot_order()
	_backpack_view = false
	_general_stock = false
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
	_compact_backpack_slots(stock)
	_update_selection()
	_set_tutorial_suppressed(true)
	call_deferred("_layout_modal")

func _has_stock(stock: Dictionary) -> bool:
	for item_id in stock:
		if int(stock.get(item_id, 0)) > 0:
			return true
	return false

func open_stock() -> void:
	_restore_slot_order()
	var stock := SaveManager.warehouse_snapshot()
	if not _has_stock(stock):
		open_empty_stock()
		_message.text = "没有任何食物"
		for item_id in _slot_by_id:
			_set_slot(_slot_by_id[item_id], 0, true, true)
		return
	open_for_order()
	_general_stock = true
	for item_id in _slot_by_id:
		var quantity := int(stock.get(item_id, 0))
		_set_slot(_slot_by_id[item_id], quantity, quantity <= 0, true)
	_compact_backpack_slots(stock)
	_update_selection()

func _set_slot(slot: SproutItemSlot, quantity: int, disabled_state: bool, slot_visible: bool) -> void:
	slot.modulate = Color.WHITE
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
	if not _open or _empty_stock or _backpack_view:
		return
	if not SaveManager.carried_ingredients().is_empty():
		return
	if not _selected.has(item_id) and _selected.size() >= SaveManager.MAX_WAREHOUSE_KINDS:
		return
	var slot: SproutItemSlot = _slot_by_id.get(item_id)
	if not is_instance_valid(slot) or slot.disabled or slot._quantity <= 0:
		return
	slot.set_selected_quantity(slot.get_selected_quantity() + 1, true)

func _on_slot_quantity_changed(item_id: String, quantity: int) -> void:
	if not _open or _empty_stock or _backpack_view:
		return
	if quantity > 0 and not SaveManager.carried_ingredients().is_empty():
		var blocked_slot: SproutItemSlot = _slot_by_id.get(item_id)
		if is_instance_valid(blocked_slot): blocked_slot.set_selected_quantity(int(_selected.get(item_id, 0)))
		return
	if quantity > 0 and not _selected.has(item_id) and _selected.size() >= SaveManager.MAX_WAREHOUSE_KINDS:
		var rejected_slot: SproutItemSlot = _slot_by_id.get(item_id)
		if is_instance_valid(rejected_slot): rejected_slot.set_selected_quantity(0)
		return
	if quantity > int(_selected.get(item_id, 0)) and not _can_add_material(item_id, quantity):
		var rejected_slot: SproutItemSlot = _slot_by_id.get(item_id)
		if is_instance_valid(rejected_slot): rejected_slot.set_selected_quantity(int(_selected.get(item_id, 0)))
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
	_claim_button.disabled = not SaveManager.warehouse_selection_complete(_selected) if _general_stock else not _is_first_order_selection()
	_claim_button.disabled = _claim_button.disabled or not SaveManager.carried_ingredients().is_empty()
	_update_recipe_slots()
	_rebuild_selected_list()

func _can_add_material(item_id: String, quantity: int) -> bool:
	var proposed := _selected.duplicate()
	proposed[item_id] = quantity
	if proposed.size() > SaveManager.MAX_WAREHOUSE_KINDS:
		return false
	return not SaveManager.warehouse_recipe_candidates(proposed).is_empty()

func _update_recipe_slots() -> void:
	if _backpack_view or _empty_stock:
		return
	var hands_full := not SaveManager.carried_ingredients().is_empty()
	for item_id in _slot_by_id:
		var slot: SproutItemSlot = _slot_by_id[item_id]
		var quantity := int(_selected.get(item_id, 0))
		slot.disabled = hands_full or quantity >= slot._quantity or not _can_add_material(item_id, quantity + 1)
		# 只在仓库取料模式灰显不相容材料，保留已选格的绿色及背包原样式。
		slot.modulate = Color(0.48, 0.48, 0.48, 0.65) if slot.disabled and quantity == 0 and slot._quantity > 0 else Color.WHITE

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
		content.get_node("Plus").disabled = quantity >= slot._quantity or not _can_add_material(item_id, quantity + 1) or not SaveManager.carried_ingredients().is_empty()
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
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if not _open or _empty_stock or _backpack_view:
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
	if _backpack_view: return
	if not SaveManager.carried_ingredients().is_empty():
		_update_selection()
		return
	if _selected.size() > SaveManager.MAX_WAREHOUSE_KINDS:
		return
	if not SaveManager.warehouse_selection_complete(_selected):
		_update_selection()
		return
	if _general_stock and _open:
		var result := SaveManager.take_warehouse_items(_selected)
		if result.success:
			close_modal()
			claimed.emit(result)
		else:
			_message.text = "取出失败，当前库存未改变"
			_message.show()
		return
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

## temporary=true仅显示传入暂存食材；默认调用保留餐厅原有只读库存入口。
func open_backpack(temporary_items: Dictionary = {}, temporary: bool = false) -> void:
	open_empty_stock()
	_backpack_view = true
	_empty_stock = false
	_temporary_backpack = temporary_items.duplicate(true)
	var display_stock: Dictionary = _temporary_backpack.duplicate(true)
	if not temporary:
		display_stock = SaveManager.inventory_snapshot()
		var stored := SaveManager.warehouse_snapshot()
		for item_id in stored: display_stock[item_id] = int(display_stock.get(item_id,0)) + int(stored[item_id])
	_cancel_button.configure("关闭")
	_cancel_button.grab_focus()
	for item_id in display_stock:
		if not _slot_by_id.has(item_id):
			var info := preload("res://scripts/cooking/recipe_catalog.gd").get_ingredient(item_id)
			var slot := _create_slot(item_id, str(info.get("name",item_id)), 0)
			_slots_grid.add_child(slot)
			_slot_by_id[item_id] = slot
	for item_id in _slot_by_id:
		var slot: SproutItemSlot = _slot_by_id[item_id]
		_set_slot(slot, int(display_stock.get(item_id,0)), false, true)
	_heading.text = "背包" if temporary else "仓库"
	_compact_backpack_slots(display_stock)
	_message.text = "完成探索后带回餐厅，\n中途放弃将失去所有食材" if temporary else "材料与食材"
	_message.show()
	_scroll.scroll_vertical = 0

func _restore_slot_order() -> void:
	for index in _backpack_slot_order.size():
		if is_instance_valid(_backpack_slot_order[index]):
			_slots_grid.move_child(_backpack_slot_order[index], index)
	_backpack_slot_order.clear()

func _compact_backpack_slots(stock: Dictionary = {}) -> void:
	# 背包是只读汇总视图：有库存的槽位稳定保持原顺序并压到前排，空槽统一置后。
	_backpack_slot_order = _slots_grid.get_children()
	if not stock.is_empty():
		var occupied_by_stock: Array[SproutItemSlot] = []
		var empty_by_stock: Array[SproutItemSlot] = []
		for child in _slots_grid.get_children():
			if not child is SproutItemSlot: continue
			var slot := child as SproutItemSlot
			if int(stock.get(slot.item_id, 0)) > 0: occupied_by_stock.append(slot)
			else: empty_by_stock.append(slot)
		var ordered_by_stock: Array[SproutItemSlot] = occupied_by_stock + empty_by_stock
		for index in ordered_by_stock.size(): _slots_grid.move_child(ordered_by_stock[index], index)
		_backpack_slot_order.clear()
		for slot in ordered_by_stock:
			_backpack_slot_order.append(slot)
		return
	var occupied: Array[SproutItemSlot] = []
	var empty: Array[SproutItemSlot] = []
	for child in _slots_grid.get_children():
		if not child is SproutItemSlot:
			continue
		var slot := child as SproutItemSlot
		if slot._quantity > 0:
			occupied.append(slot)
		else:
			empty.append(slot)
	var ordered: Array[SproutItemSlot] = occupied + empty
	for index in ordered.size():
		_slots_grid.move_child(ordered[index], index)


func _input(event: InputEvent) -> void:
	if not _backpack_view or not _open: return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed:
			match event.keycode:
				KEY_ESCAPE:
					if not event.echo: _on_cancel_pressed()
				KEY_DOWN:
					_scroll.scroll_vertical += int(GRID_CELL_SIZE.y + 4)
				KEY_UP:
					_scroll.scroll_vertical -= int(GRID_CELL_SIZE.y + 4)
				KEY_PAGEDOWN:
					_scroll.scroll_vertical += int(GRID_VISIBLE_HEIGHT)
				KEY_PAGEUP:
					_scroll.scroll_vertical -= int(GRID_VISIBLE_HEIGHT)
				KEY_HOME:
					_scroll.scroll_vertical = 0
				KEY_END:
					_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
