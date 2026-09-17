class_name SproutItemSlot
extends Button
## 仅用于预览/展示的物品格，不连接真实库存。

signal slot_selected(item_id: String)

var item_id := ""
var _selected := false

func _ready() -> void:
	theme = SproutTheme.make_theme()
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(128, 102)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	add_theme_font_size_override("font_size", 15)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func configure(id: String, label_text: String, quantity: int, icon_index: int, disabled_state := false) -> SproutItemSlot:
	item_id = id
	text = "%s\n×%d" % [label_text, quantity]
	icon = SproutTheme.icon(icon_index)
	disabled = disabled_state
	return self

func set_selected(value: bool) -> void:
	_selected = value
	if _selected:
		add_theme_stylebox_override("normal", SproutTheme.selected_style())
		add_theme_stylebox_override("hover", SproutTheme.selected_style())
	else:
		add_theme_stylebox_override("normal", SproutTheme.unselected_style())
		add_theme_stylebox_override("hover", SproutTheme.button_style(SproutTheme.GREEN_HOVER))

func _on_pressed() -> void:
	if not disabled:
		slot_selected.emit(item_id)
