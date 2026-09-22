extends Control
## 首单状态卡片：只展示 SaveManager 已提交的订单与库存状态。

const PANEL_SIZE := Vector2(380, 260)
const TOP_OFFSET := 94.0
const STATUS_PENDING := Color("#d8b77d")
const STATUS_DONE := Color("#9fca86")

var _panel: PanelContainer
var _order_status: Button
var _meat_status: Button
var _salt_status: Button
var _cook_status: Button

func _ready() -> void:
	add_to_group("order_tracking")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	call_deferred("refresh_saved_state")

func _process(_delta: float) -> void:
	if visible:
		_position_away_from_gameplay()

func get_layout_side() -> String:
	return "left" if _panel.offset_left < get_viewport_rect().size.x * 0.5 else "right"

func _position_away_from_gameplay() -> void:
	var viewport_size := get_viewport_rect().size
	var left_rect := Rect2(20.0, TOP_OFFSET, PANEL_SIZE.x, PANEL_SIZE.y)
	var right_rect := Rect2(viewport_size.x - PANEL_SIZE.x - 20.0, TOP_OFFSET, PANEL_SIZE.x, PANEL_SIZE.y)
	var obstacles: Array[Rect2] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		var player_screen := get_viewport().get_canvas_transform() * player.global_position
		obstacles.append(Rect2(player_screen + Vector2(-55.0, -155.0), Vector2(110.0, 180.0)))
	var tm := get_node_or_null("/root/TutorialManager")
	if tm != null and tm.active and tm.idx >= 0 and tm.idx < tm.steps.size():
		var step: Dictionary = tm.steps[tm.idx]
		var target: Node2D = tm.resolve_target(step.get("target")) if tm.has_method("resolve_target") else null
		if is_instance_valid(target):
			var target_screen := get_viewport().get_canvas_transform() * target.global_position
			obstacles.append(Rect2(target_screen + Vector2(-130.0, -165.0), Vector2(260.0, 210.0)))
	var ui := get_tree().get_first_node_in_group("ui_layer")
	if is_instance_valid(ui):
		for button in ui.get("_buttons").values():
			if is_instance_valid(button) and button.visible:
				obstacles.append(button.get_global_rect())
	var left_score := _overlap_score(left_rect, obstacles)
	var right_score := _overlap_score(right_rect, obstacles)
	var place_left := left_score < right_score
	if left_score == right_score and left_score > 0.0 and is_instance_valid(player):
		var player_screen := get_viewport().get_canvas_transform() * player.global_position
		place_left = player_screen.x >= viewport_size.x * 0.5
	var left := 20.0 if place_left else viewport_size.x - PANEL_SIZE.x - 20.0
	_panel.offset_left = left
	_panel.offset_right = left + PANEL_SIZE.x

func _overlap_score(rect: Rect2, obstacles: Array[Rect2]) -> float:
	var score := 0.0
	for obstacle in obstacles:
		if rect.intersects(obstacle):
			var overlap := rect.intersection(obstacle)
			score += overlap.size.x * overlap.size.y
	return score

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 20.0
	_panel.offset_right = 20.0 + PANEL_SIZE.x
	_panel.offset_top = TOP_OFFSET
	_panel.offset_bottom = TOP_OFFSET + PANEL_SIZE.y
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 7)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outer)

	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 4)
	order_row.custom_minimum_size.y = 34
	order_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(order_row)
	var order_prefix := _make_label("接到订单：交出", 16, SproutTheme.INK)
	order_row.add_child(order_prefix)
	order_row.add_child(_make_icon(4))
	var dish_name := _make_label("盐烤岩鬃肉", 16, SproutTheme.INK)
	dish_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_row.add_child(dish_name)
	_order_status = _make_status_button()
	order_row.add_child(_order_status)

	outer.add_child(_make_section_title("取货"))
	outer.add_child(_make_item_row(0, "岩鬃肉", "meat"))
	outer.add_child(_make_item_row(1, "岩盐", "salt"))

	outer.add_child(_make_section_title("烹饪"))
	var cook_row := HBoxContainer.new()
	cook_row.add_theme_constant_override("separation", 7)
	cook_row.custom_minimum_size.y = 34
	cook_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var make_label := _make_label("制作", 16, SproutTheme.INK)
	cook_row.add_child(make_label)
	cook_row.add_child(_make_icon(4))
	var cook_name := _make_label("盐烤岩鬃肉", 16, SproutTheme.INK)
	cook_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cook_row.add_child(cook_name)
	_cook_status = _make_status_button()
	cook_row.add_child(_cook_status)
	outer.add_child(cook_row)

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_section_title(value: String) -> Label:
	var label := _make_label(value, 18, SproutTheme.INK)
	label.custom_minimum_size.y = 23
	return label

func _make_icon(index: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = SproutTheme.icon(index)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_item_row(icon_index: int, item_name: String, which: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 30
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_make_icon(icon_index))
	var label := _make_label(item_name, 16, SproutTheme.INK_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var state := _make_status_button()
	row.add_child(state)
	if which == "meat":
		_meat_status = state
	else:
		_salt_status = state
	return row

func _make_status_button() -> Button:
	var button := Button.new()
	button.text = "0/1"
	button.custom_minimum_size = Vector2(50, 28)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_font_size_override("font_size", 15)
	_set_status_style(button, false)
	return button

func _set_status_style(button: Button, complete: bool) -> void:
	var color := STATUS_DONE if complete else STATUS_PENDING
	var style := SproutTheme.button_style(color)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", SproutTheme.INK)
	button.add_theme_color_override("font_hover_color", SproutTheme.INK)
	button.add_theme_color_override("font_pressed_color", SproutTheme.INK)

func _restore_saved_order() -> void:
	refresh_saved_state()

func refresh_saved_state() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("current_order"):
		visible = false
		return
	var order: Dictionary = sm.current_order()
	if str(order.get("status", "none")) != "in_progress":
		visible = false
		return
	var meat := int(sm.inventory_quantity("rockmane_meat")) if sm.has_method("inventory_quantity") else 0
	var salt := int(sm.inventory_quantity("rock_salt")) if sm.has_method("inventory_quantity") else 0
	_set_counter(_order_status, 0)
	_set_counter(_meat_status, meat)
	_set_counter(_salt_status, salt)
	# 料理与交付事务尚未实现；不得因拥有食材而伪报完成。
	_set_counter(_cook_status, 0)
	visible = true

func show_order_receipt(order) -> void:
	# 兼容既有 TutorialManager 调用；回执已并入唯一订单卡片，不再弹第二份确认。
	if order is Dictionary:
		refresh_saved_state()

func hide_tracking() -> void:
	# Skip hides the tutorial's temporary HUD presentation; saved order state is untouched.
	visible = false

func _set_counter(button: Button, count: int) -> void:
	if not is_instance_valid(button):
		return
	var complete := count >= 1
	button.text = "1/1" if complete else "0/1"
	_set_status_style(button, complete)
