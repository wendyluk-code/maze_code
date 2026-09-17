class_name SproutButton
extends Button
## 可复用操作按钮：图标 + 中文文本，包含正常/悬停/按下/禁用/焦点状态。

signal activated(button: SproutButton)

@export var icon_index := 0

func _ready() -> void:
	theme = SproutTheme.make_theme()
	focus_mode = Control.FOCUS_ALL
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	expand_icon = true
	custom_minimum_size = Vector2(190, 52)
	icon = SproutTheme.icon(icon_index)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func configure(label_text: String, new_icon_index := -1) -> SproutButton:
	text = label_text
	if new_icon_index >= 0:
		icon_index = new_icon_index
		icon = SproutTheme.icon(icon_index)
	return self

func _on_pressed() -> void:
	activated.emit(self)
