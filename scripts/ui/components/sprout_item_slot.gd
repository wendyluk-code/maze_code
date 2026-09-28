class_name SproutItemSlot
extends Control
## 仓库物品格：图标可点击选择，名称/库存数量独立显示，并支持选择份数。

signal slot_selected(item_id: String)
signal pressed
signal selection_changed(item_id: String, quantity: int)

const GRID_SIZE := Vector2(56, 56)
var item_id := ""
var _item_name := ""
var _quantity := 0
var _selected_quantity := 0
var max_quantity := 999
var _legacy_text := ""
var _selected := false
var _disabled := false
var _icon_index := 0
var _custom_icon: Texture2D
var _grid_mode := false
var _icon_button: Button
var _icon_view: TextureRect
var _name_label: Label
var _quantity_label: Label
var _minus_button: Button
var _selected_quantity_label: Label
var _plus_button: Button
var _stock_badge: Label

var text: String:
	get:
		return _legacy_text
	set(value):
		_legacy_text = value

var disabled: bool:
	get:
		return _disabled
	set(value):
		_disabled = value
		if is_instance_valid(_icon_button):
			_icon_button.disabled = value
			_apply_visual()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = GRID_SIZE if _grid_mode else Vector2(128, 164)
	_build_visual()
	pressed.connect(_on_pressed)
	resized.connect(_apply_visual)
	_apply_visual()

func _build_visual() -> void:
	_icon_button = Button.new()
	_icon_button.name = "IconButton"
	_icon_button.custom_minimum_size = Vector2(84, 78)
	_icon_button.focus_mode = Control.FOCUS_ALL
	_icon_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_icon_button.pressed.connect(func(): pressed.emit())
	add_child(_icon_button)

	_icon_view = TextureRect.new()
	_icon_view.name = "Icon"
	_icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_view.position = Vector2(18, 14)
	_icon_view.size = Vector2(48, 48)
	_icon_button.add_child(_icon_view)

	_name_label = _make_label(16, SproutTheme.INK)
	_name_label.name = "ItemName"
	add_child(_name_label)
	_quantity_label = _make_label(15, SproutTheme.INK_MUTED)
	_quantity_label.name = "Quantity"
	add_child(_quantity_label)

	_minus_button = Button.new()
	_minus_button.name = "Decrease"
	_minus_button.text = "−"
	_minus_button.focus_mode = Control.FOCUS_ALL
	_minus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_minus_button.pressed.connect(_on_decrease_pressed)
	add_child(_minus_button)

	_selected_quantity_label = _make_label(15, SproutTheme.INK)
	_selected_quantity_label.name = "SelectedQuantity"
	add_child(_selected_quantity_label)

	_plus_button = Button.new()
	_plus_button.name = "Increase"
	_plus_button.text = "+"
	_plus_button.focus_mode = Control.FOCUS_ALL
	_plus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_plus_button.pressed.connect(_on_increase_pressed)
	add_child(_plus_button)

	_stock_badge = Label.new()
	_stock_badge.name = "StockBadge"
	_stock_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stock_badge.add_theme_font_size_override("font_size", 12)
	_stock_badge.add_theme_font_override("font", ThemeDB.fallback_font)
	_stock_badge.add_theme_color_override("font_color", SproutTheme.CREAM)
	_stock_badge.add_theme_color_override("font_outline_color", Color("#382817"))
	_stock_badge.add_theme_constant_override("outline_size", 3)
	_stock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_badge.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_child(_stock_badge)
	_stock_badge.visible = false

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func configure(id: String, label_text: String, quantity: int, icon_index: int, disabled_state := false) -> SproutItemSlot:
	item_id = id
	_item_name = label_text
	_quantity = clampi(quantity, 0, max_quantity)
	_selected_quantity = mini(_selected_quantity, _quantity)
	_icon_index = icon_index
	_legacy_text = "%s\n×%d" % [_item_name, _quantity]
	disabled = disabled_state
	if is_node_ready():
		_apply_visual()
	return self

func set_available_quantity(value: int) -> void:
	_quantity = clampi(value, 0, max_quantity)
	_selected_quantity = mini(_selected_quantity, _quantity)
	_legacy_text = "%s\n×%d" % [_item_name, _quantity]
	if is_node_ready():
		_apply_visual()

func set_icon_texture(texture: Texture2D) -> void:
	_custom_icon = texture
	if is_node_ready():
		_apply_visual()

func set_grid_mode(value: bool) -> void:
	_grid_mode = value
	if value:
		custom_minimum_size = GRID_SIZE
	if is_node_ready():
		_apply_visual()

func get_icon_texture() -> Texture2D:
	return _custom_icon if is_instance_valid(_custom_icon) else SproutTheme.icon(_icon_index)

func set_selected_quantity(value: int, emit_change := false) -> void:
	var next := clampi(value, 0, mini(_quantity, max_quantity))
	if _selected_quantity == next:
		if is_node_ready():
			_apply_visual()
		return
	_selected_quantity = next
	_selected = next > 0
	if is_node_ready():
		_apply_visual()
	if emit_change:
		selection_changed.emit(item_id, _selected_quantity)

func get_selected_quantity() -> int:
	return _selected_quantity

func set_selected(value: bool) -> void:
	_selected = value
	if value and _selected_quantity == 0 and _quantity > 0:
		_selected_quantity = 1
	elif not value:
		_selected_quantity = 0
	if is_node_ready():
		_apply_visual()

func _apply_visual() -> void:
	if not is_instance_valid(_icon_button):
		return
	_icon_view.texture = _custom_icon if is_instance_valid(_custom_icon) else SproutTheme.icon(_icon_index)
	if _grid_mode:
		_apply_grid_visual()
		return
	_icon_view.visible = _quantity > 0
	_name_label.text = _item_name
	_name_label.visible = _quantity > 0
	_quantity_label.text = "×%d" % _quantity
	_quantity_label.visible = _quantity > 0
	_quantity_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_selected_quantity_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_selected_quantity_label.text = "%d" % _selected_quantity
	_icon_button.tooltip_text = "%s\n库存：×%d\n已选：×%d" % [_item_name, _quantity, _selected_quantity] if _quantity > 0 else "空位"
	var width := maxf(128.0, size.x)
	_icon_button.position = Vector2((width - 84.0) * 0.5, 0.0)
	_name_label.position = Vector2(0.0, 82.0)
	_name_label.size = Vector2(width, 24.0)
	_quantity_label.position = Vector2(0.0, 106.0)
	_quantity_label.size = Vector2(width, 22.0)
	_minus_button.position = Vector2((width - 114.0) * 0.5, 132.0)
	_minus_button.size = Vector2(32.0, 28.0)
	_selected_quantity_label.position = Vector2((width - 50.0) * 0.5, 132.0)
	_selected_quantity_label.size = Vector2(50.0, 28.0)
	_plus_button.position = Vector2((width + 50.0) * 0.5, 132.0)
	_plus_button.size = Vector2(32.0, 28.0)
	_minus_button.disabled = _disabled or _selected_quantity <= 0
	_plus_button.disabled = _disabled or _selected_quantity >= mini(_quantity, max_quantity)
	_minus_button.visible = not _disabled
	_plus_button.visible = not _disabled
	_selected_quantity_label.visible = not _disabled
	_apply_icon_style()

func _apply_grid_visual() -> void:
	_icon_button.custom_minimum_size = GRID_SIZE
	_icon_button.position = Vector2.ZERO
	_icon_button.size = GRID_SIZE
	_icon_view.position = Vector2(8, 5)
	_icon_view.size = Vector2(40, 40)
	_icon_view.visible = _quantity > 0
	_icon_button.tooltip_text = "%s\n库存：×%d" % [_item_name, _quantity] if _quantity > 0 else "空位"
	_name_label.visible = false
	_quantity_label.visible = false
	_minus_button.visible = false
	_plus_button.visible = false
	_selected_quantity_label.visible = false
	_stock_badge.visible = _quantity > 0
	_stock_badge.text = str(_quantity)
	_stock_badge.size = Vector2(maxf(18, _stock_badge.get_minimum_size().x), 16)
	_stock_badge.position = GRID_SIZE - _stock_badge.size - Vector2(2, 2)
	_apply_icon_style()

func _apply_icon_style() -> void:
	if not is_instance_valid(_icon_button):
		return
	if _grid_mode:
		# 保留键盘焦点能力，但不绘制额外焦点框；选中外观仅由选择数量决定。
		_icon_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for state in ["normal", "hover", "pressed", "disabled"]:
			var grid_style := StyleBoxFlat.new()
			grid_style.bg_color = Color("#bed29d") if _selected_quantity > 0 else Color("#e9d2a7")
			if _quantity == 0:
				grid_style.bg_color = Color("#d9c39e")
			elif state == "hover":
				grid_style.bg_color = Color("#d6e1bc")
			grid_style.border_color = Color("#6a8953") if _selected_quantity > 0 else Color("#b69a71")
			grid_style.set_border_width_all(2 if _selected_quantity > 0 else 1)
			grid_style.set_corner_radius_all(4)
			_icon_button.add_theme_stylebox_override(state, grid_style)
		return
	var style: StyleBox
	if _disabled:
		style = SproutTheme.button_style(Color("#c4bda9"))
	elif _selected or _selected_quantity > 0:
		style = SproutTheme.selected_style()
	else:
		style = SproutTheme.unselected_style()
	for state in ["normal", "hover", "pressed"]:
		_icon_button.add_theme_stylebox_override(state, style)
	_icon_button.add_theme_color_override("font_color", SproutTheme.INK)
	_icon_button.add_theme_color_override("font_hover_color", SproutTheme.INK)
	_icon_button.add_theme_color_override("font_pressed_color", SproutTheme.INK)
	for button in [_minus_button, _plus_button]:
		if is_instance_valid(button):
			button.add_theme_font_size_override("font_size", 17)
			button.add_theme_font_override("font", ThemeDB.fallback_font)
			for state in ["normal", "hover", "pressed", "disabled"]:
				var small_style := SproutTheme.button_style(Color("#eadfbe"))
				small_style.content_margin_left = 4
				small_style.content_margin_right = 4
				small_style.content_margin_top = 2
				small_style.content_margin_bottom = 2
				button.add_theme_stylebox_override(state, small_style)

func _on_pressed() -> void:
	if not _disabled:
		slot_selected.emit(item_id)

func _on_decrease_pressed() -> void:
	if not _disabled:
		set_selected_quantity(_selected_quantity - 1, true)

func _on_increase_pressed() -> void:
	if not _disabled:
		set_selected_quantity(_selected_quantity + 1, true)
