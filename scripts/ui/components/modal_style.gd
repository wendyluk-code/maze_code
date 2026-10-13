extends RefCounted
## 弹窗共用外观；输入、层级和关闭业务仍由接入方管理。
const BACKDROP := Color(0.08, 0.06, 0.04, 0.72)

static func close_button() -> Button:
	var button := Button.new()
	button.text = "×"
	button.tooltip_text = "关闭弹窗"
	button.theme = SproutTheme.make_theme()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(44, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color("e4bf73"))
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("ffd56a"))
	button.add_theme_color_override("font_pressed_color", Color("c49c53"))
	button.add_theme_color_override("font_disabled_color", Color("8d8066"))
	button.add_theme_constant_override("outline_size", 0)
	return button
