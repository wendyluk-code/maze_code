extends Control
## 首单回执与持续追踪 HUD。
## 只由 SaveManager 的真实订单结果驱动，不把普通 Toast 当作订单状态。

const RECEIPT_DURATION := 1.45
const PANEL_SIZE := Vector2(356, 178)

var _panel: PanelContainer
var _receipt: Label
var _title: Label
var _status: Label
var _item_slot: SproutItemSlot
var _receipt_tween: Tween

func _ready() -> void:
	add_to_group("order_tracking")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -PANEL_SIZE.x - 24.0
	offset_top = 20.0
	offset_right = -24.0
	offset_bottom = 20.0 + PANEL_SIZE.y
	visible = false
	_build()
	call_deferred("_restore_saved_order")

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outer)

	_receipt = Label.new()
	_receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_receipt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_receipt.custom_minimum_size.y = 28
	_receipt.add_theme_color_override("font_color", Color("#5d9c63"))
	_receipt.add_theme_font_size_override("font_size", 20)
	_receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_receipt)

	_title = Label.new()
	_title.text = "订单追踪"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_color_override("font_color", SproutTheme.INK)
	_title.add_theme_font_size_override("font_size", 22)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(row)

	_item_slot = SproutItemSlot.new()
	_item_slot.configure("", "", 0, 0, true)
	_item_slot.custom_minimum_size = Vector2(148, 76)
	_item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_item_slot)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	_status.add_theme_font_size_override("font_size", 17)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_status)

func _restore_saved_order() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("current_order"):
		var order: Dictionary = sm.current_order()
		if str(order.get("status", "none")) == "in_progress":
			_refresh(order)

func show_order_receipt(order) -> void:
	if not order is Dictionary:
		return
	_refresh(order)
	_receipt.text = "已接单：%s ×%d" % [str(order.get("item_name", "")), int(order.get("quantity", 0))]
	_receipt.visible = true
	if _receipt_tween != null and _receipt_tween.is_valid():
		_receipt_tween.kill()
	_receipt_tween = create_tween()
	_receipt_tween.tween_interval(RECEIPT_DURATION)
	_receipt_tween.tween_callback(_hide_receipt)

func _hide_receipt() -> void:
	if is_instance_valid(_receipt):
		_receipt.visible = false

func _refresh(order: Dictionary) -> void:
	var item_name := str(order.get("item_name", ""))
	var quantity := int(order.get("quantity", 0))
	_item_slot.configure(str(order.get("item_id", "")), item_name, quantity, 4, true)
	_item_slot.custom_minimum_size = Vector2(148, 76)
	_status.text = "状态：进行中\n订单号：%s\n下一步：准备食材" % str(order.get("id", ""))
	visible = true
