extends Control
## 首单仓库领取界面：只负责选择材料与提交一次真实库存事务。

signal claimed(result: Dictionary)
signal cancelled
signal inspected

var _overlay: ColorRect
var _panel: PanelContainer
var _meat_slot: SproutItemSlot
var _salt_slot: SproutItemSlot
var _selection_label: Label
var _message: Label
var _cancel_button: SproutButton
var _claim_button: SproutButton
var _selected := {}
var _open := false
var _empty_stock := false
var _stock_title: Label
var _order_title: Label
var _requirements: Label

func _ready() -> void:
	add_to_group("warehouse_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.07, 0.05, 0.66)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-360, -230)
	_panel.size = Vector2(720, 460)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)
	var heading := Label.new()
	heading.text = "仓库"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(heading)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var stock := VBoxContainer.new()
	stock.add_theme_constant_override("separation", 6)
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stock)
	var stock_title := Label.new()
	_stock_title = stock_title
	stock_title.text = "库存材料（请选择本单需要的材料）"
	stock_title.add_theme_font_size_override("font_size", 18)
	stock.add_child(stock_title)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	stock.add_child(slots)
	_meat_slot = SproutItemSlot.new()
	_meat_slot.configure("rockmane_meat", "岩鬃肉", 1, 0, false)
	_meat_slot.focus_mode = Control.FOCUS_NONE
	_meat_slot.custom_minimum_size = Vector2(170, 150)
	_meat_slot.slot_selected.connect(_on_slot_selected)
	slots.add_child(_meat_slot)
	_salt_slot = SproutItemSlot.new()
	_salt_slot.configure("rock_salt", "岩盐", 1, 1, false)
	_salt_slot.focus_mode = Control.FOCUS_NONE
	_salt_slot.custom_minimum_size = Vector2(170, 150)
	_salt_slot.slot_selected.connect(_on_slot_selected)
	slots.add_child(_salt_slot)
	var order_box := VBoxContainer.new()
	order_box.custom_minimum_size.x = 230
	order_box.add_theme_constant_override("separation", 8)
	body.add_child(order_box)
	var order_title := Label.new()
	_order_title = order_title
	order_title.text = "订单需求"
	order_title.add_theme_font_size_override("font_size", 20)
	order_box.add_child(order_title)
	var requirements := Label.new()
	_requirements = requirements
	requirements.text = "盐烤岩鬃肉 ×1\n所需：\n  岩鬃肉 ×1\n  岩盐 ×1"
	requirements.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	requirements.add_theme_font_size_override("font_size", 18)
	order_box.add_child(requirements)
	_selection_label = Label.new()
	_selection_label.text = "当前选择：0 / 2"
	_selection_label.add_theme_font_size_override("font_size", 18)
	order_box.add_child(_selection_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	order_box.add_child(spacer)
	_message = Label.new()
	_message.text = "请选齐两种材料后领取"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	outer.add_child(_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	outer.add_child(actions)
	_cancel_button = SproutButton.new()
	_cancel_button.configure("取消")
	_cancel_button.set_icon_visible(false)
	_cancel_button.set_focus_visual(false)
	_cancel_button.custom_minimum_size = Vector2(130, 52)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	actions.add_child(_cancel_button)
	_claim_button = SproutButton.new()
	_claim_button.configure("领取材料")
	_claim_button.set_icon_visible(false)
	_claim_button.set_focus_visual(false)
	_claim_button.custom_minimum_size = Vector2(170, 52)
	_claim_button.disabled = true
	_claim_button.pressed.connect(_on_claim_pressed)
	actions.add_child(_claim_button)

func open_for_order() -> void:
	_empty_stock = false
	_meat_slot.configure("rockmane_meat", "岩鬃肉", 1, 0, false)
	_salt_slot.configure("rock_salt", "岩盐", 1, 1, false)
	_stock_title.text = "库存材料（请选择本单需要的材料）"
	_order_title.text = "订单需求"
	_requirements.text = "盐烤岩鬃肉 ×1\n所需：\n  岩鬃肉 ×1\n  岩盐 ×1"
	_cancel_button.configure("取消")
	_claim_button.visible = true
	_selected.clear()
	_open = true
	visible = true
	_message.text = "请选齐两种材料后领取"
	_update_selection()
	_set_tutorial_suppressed(true)

func open_empty_stock() -> void:
	_empty_stock = true
	_selected.clear()
	_open = true
	visible = true
	var stock := SaveManager.inventory_snapshot()
	_meat_slot.configure("rockmane_meat", "岩鬃肉", int(stock.rockmane_meat), 0, true)
	_salt_slot.configure("rock_salt", "岩盐", int(stock.rock_salt), 1, true)
	_meat_slot.set_selected(false)
	_salt_slot.set_selected(false)
	_stock_title.text = "仓库现存食材"
	_order_title.text = "剩余食物"
	_requirements.text = "岩鬃肉 = %d\n岩盐 = %d\n盐烤岩鬃肉 = %d" % [stock.rockmane_meat, stock.rock_salt, stock.salt_grilled_rockmane]
	_selection_label.text = "库存已耗尽" if SaveManager.can_start_departure() else "请核对库存"
	_message.text = "没有任何食物" if SaveManager.can_start_departure() else "仓库仍有食物"
	_cancel_button.configure("确认")
	_claim_button.disabled = true
	_claim_button.visible = false
	_set_tutorial_suppressed(true)

func close_modal() -> void:
	_open = false
	visible = false
	_set_tutorial_suppressed(false)

func _on_slot_selected(item_id: String) -> void:
	if not _open or _empty_stock:
		return
	_selected[item_id] = not bool(_selected.get(item_id, false))
	_update_selection()

func _update_selection() -> void:
	var count := 0
	for value in _selected.values():
		if bool(value):
			count += 1
	_meat_slot.set_selected(bool(_selected.get("rockmane_meat", false)))
	_salt_slot.set_selected(bool(_selected.get("rock_salt", false)))
	_selection_label.text = "当前选择：%d / 2" % count
	_claim_button.disabled = count != 2

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
	if not _open or _claim_button.disabled:
		_message.text = "请先选择岩鬃肉和岩盐"
		return
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("claim_first_order_ingredients"):
		_message.text = "仓库暂时无法领取，请稍后再试"
		return
	var result: Dictionary = sm.claim_first_order_ingredients()
	if bool(result.get("success", false)):
		close_modal()
		claimed.emit(result)
	else:
		_message.text = "领取失败，当前订单未改变"

func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func _set_tutorial_suppressed(value: bool) -> void:
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide) and guide.has_method("set_modal_suppressed"):
		guide.set_modal_suppressed(value)
