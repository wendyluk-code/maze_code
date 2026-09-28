extends Control
## 首单任务入口：进度读取已提交的任务状态，不等同于库存。

const PANEL_WIDTH := 260.0
const PANEL_POSITION := Vector2(16, 66)
const EXPAND_DURATION := 0.25
const DISH_ICON: Texture2D = preload("res://assets/ui/ingredients/salt_grilled_rockmane.png")
const MEAT_ICON: Texture2D = preload("res://assets/ui/ingredients/rockmane_meat.png")
const SALT_ICON: Texture2D = preload("res://assets/ui/ingredients/rock_salt.png")
var _panel: PanelContainer
var _task_button: Button
var _notification: Label
var _order_status: Button
var _meat_status: Button
var _salt_status: Button
var _cook_status: Button
var _ingredients_title: Label
var _cook_title: Label
var _expanded := false
var _expand_tween: Tween
var _known_order_id := ""
var _subtask_panels: Array[PanelContainer] = []
var _explanation_highlight := false

func _ready() -> void:
	add_to_group("order_tracking")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = SproutTheme.make_theme()
	visible = false
	_build()
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("refresh_saved_state")

func _exit_tree() -> void:
	collapse_details()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		collapse_details()

func _process(_delta: float) -> void:
	if not _expanded:
		return
	var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
	var cooking := get_tree().get_first_node_in_group("cooking_modal")
	var departure := get_tree().get_first_node_in_group("departure_panel")
	var other_ui_open: bool = is_instance_valid(warehouse) and warehouse.visible
	other_ui_open = other_ui_open or (is_instance_valid(cooking) and cooking.visible)
	other_ui_open = other_ui_open or (is_instance_valid(departure) and bool(departure.get("_open")))
	other_ui_open = other_ui_open or (is_instance_valid(departure) and departure.has_method("_cards_open") and departure._cards_open())
	if other_ui_open:
		collapse_details()

func get_layout_side() -> String:
	return "left"

func _build() -> void:
	_task_button = Button.new()
	_task_button.name = "TaskButton"
	_task_button.position = Vector2(16, 16)
	_task_button.custom_minimum_size = Vector2(154, 42)
	_task_button.focus_mode = Control.FOCUS_NONE
	_task_button.icon = SproutTheme.icon(21)
	_task_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_task_button.expand_icon = true
	_task_button.pressed.connect(_toggle_tasks)
	add_child(_task_button)
	_notification = _make_label("●", 14, Color("#c85d36"))
	_notification.position = Vector2(157, 13)
	add_child(_notification)
	_notification.visible = false
	_panel = PanelContainer.new()
	_panel.name = "TaskPanel"
	_panel.position = PANEL_POSITION
	_panel.size = Vector2(PANEL_WIDTH, 276.0)
	_panel.custom_minimum_size = _panel.size
	_panel.add_theme_stylebox_override("panel", _box(Color("#fff2d4"), Color("#b99055"), 1, 12))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.visible = false
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	var main := PanelContainer.new()
	main.name = "OrderTask"
	main.add_theme_stylebox_override("panel", _box(Color("#d8b16c"), Color("#987039"), 2, 10))
	outer.add_child(main)
	var main_content := VBoxContainer.new()
	main_content.add_theme_constant_override("separation", 6)
	main.add_child(main_content)
	var heading := HBoxContainer.new()
	main_content.add_child(heading)
	var title := _make_label("订单任务", 19, SproutTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_order_status = _make_status_button()
	heading.add_child(_order_status)
	var dish_row := HBoxContainer.new()
	dish_row.add_theme_constant_override("separation", 8)
	main_content.add_child(dish_row)
	dish_row.add_child(_make_item_icon("salt_grilled_rockmane"))
	dish_row.add_child(_make_label("交出盐烤岩鬃肉", 18, SproutTheme.INK))
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 12)
	outer.add_child(indent)
	var subtasks := VBoxContainer.new()
	subtasks.name = "Subtasks"
	subtasks.add_theme_constant_override("separation", 8)
	indent.add_child(subtasks)
	var ingredients := _make_subtask(subtasks, "IngredientsTask")
	_ingredients_title = _make_label("领取食材", 16, SproutTheme.INK)
	ingredients.add_child(_ingredients_title)
	_meat_status = _add_item_row(ingredients, "岩鬃肉", "rockmane_meat")
	_salt_status = _add_item_row(ingredients, "岩盐", "rock_salt")
	var cooking := _make_subtask(subtasks, "CookingTask")
	_cook_title = _make_label("制作料理", 16, SproutTheme.INK)
	cooking.add_child(_cook_title)
	_cook_status = _add_item_row(cooking, "盐烤岩鬃肉", "salt_grilled_rockmane")
	_update_entry()

func _box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _make_subtask(parent: Node, node_name: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _box(Color("#fff8e8"), Color("#dfcaa5"), 1, 10))
	_subtask_panels.append(panel)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	return content

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_item_icon(item_id: String) -> TextureRect:
	var texture := AtlasTexture.new()
	# 收紧透明留白，仅调整显示区域，保留用户提供的原图。
	match item_id:
		"rockmane_meat":
			texture.atlas = MEAT_ICON
			texture.region = Rect2(77, 83, 106, 95)
		"rock_salt":
			texture.atlas = SALT_ICON
			texture.region = Rect2(83, 88, 97, 90)
		"salt_grilled_rockmane":
			texture.atlas = DISH_ICON
			texture.region = Rect2(279, 424, 696, 505)
	var icon := TextureRect.new()
	icon.name = item_id + "Icon"
	icon.texture = texture
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _add_item_row(parent: Node, item_name: String, item_id: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(_make_item_icon(item_id))
	var label := _make_label(item_name, 16, SproutTheme.INK_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var status := _make_status_button()
	row.add_child(status)
	return status

func _make_status_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 24)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_font_size_override("font_size", 14)
	_set_counter(button, 0)
	return button

func _set_counter(button: Button, count: int) -> void:
	var complete := count >= 1
	button.text = "1/1" if complete else "0/1"
	var style := _box(Color("#dce8c6") if complete else Color("#f4e2bd"), Color("#b7a17b"), 1, 3)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", SproutTheme.INK)

func _toggle_tasks() -> void:
	if _explanation_highlight:
		return
	_expanded = not _expanded
	if _expanded:
		_notification.visible = false
	_update_entry()
	if _expanded:
		_animate_expansion()

func collapse_details() -> void:
	set_explanation_highlight(false)
	_expanded = false
	_update_entry()

## 接单说明只强调两个子任务；显式内边距保持框条与文字位置不变。
func set_explanation_highlight(enabled: bool) -> void:
	if enabled == _explanation_highlight:
		return
	_explanation_highlight = enabled
	if enabled and not _expanded:
		_expanded = true
		_update_entry()
		_animate_expansion()
	for panel in _subtask_panels:
		panel.add_theme_stylebox_override("panel", _box(Color("#fff8e8"),
			Color("#4c83ff") if enabled else Color("#dfcaa5"), 3 if enabled else 1, 10))

func _update_entry() -> void:
	_stop_expansion()
	_task_button.text = "当前任务  ▴" if _expanded else "当前任务  ▾"
	_panel.visible = _expanded

func _stop_expansion() -> void:
	if _expand_tween != null:
		_expand_tween.kill()
		_expand_tween = null
	_panel.position = PANEL_POSITION
	_panel.modulate.a = 1.0

func _animate_expansion() -> void:
	# 整块轻移并淡入，不缩放文字；关闭时直接取消，无延迟重新显示回调。
	_panel.position = PANEL_POSITION - Vector2(0, 10)
	_panel.modulate.a = 0.0
	_expand_tween = create_tween().set_parallel(true)
	_expand_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_expand_tween.tween_property(_panel, "position", PANEL_POSITION, EXPAND_DURATION)
	_expand_tween.tween_property(_panel, "modulate:a", 1.0, EXPAND_DURATION)

## 中央指引据此限制长文案宽度，避免与展开的任务面板重叠。
func expanded_panel_rect() -> Rect2:
	return _panel.get_global_rect() if visible and _expanded else Rect2()

func _restore_saved_order() -> void:
	refresh_saved_state()

func refresh_saved_state() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		_known_order_id = ""
		hide_tracking()
		return
	var order: Dictionary = sm.current_order()
	var completed := str(order.get("status", "none")) == "completed"
	if str(order.get("status", "none")) != "in_progress" and not completed:
		_known_order_id = ""
		hide_tracking()
		return
	# 恢复已有订单仅刷新内容；同一回执或读档不再次触发展开。
	_known_order_id = str(order.get("id", ""))
	var progress: Dictionary = sm.first_order_progress()
	var claimed := bool(progress.get("ingredients_claimed", false)) or completed
	var cooked := str(progress.get("next_step", "")) in ["deliver", "chapter_wrap_up"] or completed
	_set_counter(_order_status, int(completed))
	_set_counter(_meat_status, int(claimed))
	_set_counter(_salt_status, int(claimed))
	_set_counter(_cook_status, int(cooked))
	_ingredients_title.text = "✓ 领取食材" if claimed else "领取食材"
	_cook_title.text = "✓ 制作料理" if cooked else "制作料理"
	visible = true

func show_order_receipt(order) -> void:
	if order is Dictionary:
		var order_id := str(order.get("id", ""))
		var is_new_receipt := not order_id.is_empty() and order_id != _known_order_id
		refresh_saved_state()
		if not is_new_receipt or not visible or order_id != _known_order_id:
			return
		_expanded = true
		_notification.visible = false
		_update_entry()
		_animate_expansion()

func hide_tracking() -> void:
	set_explanation_highlight(false)
	visible = false
	_expanded = false
	_notification.visible = false
	_update_entry()
