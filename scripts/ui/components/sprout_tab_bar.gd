extends TabBar
## 弹窗分类栏：保留原生选择、键盘导航和 tab_changed 接口。
func _init() -> void:
	theme = SproutTheme.make_theme()
	tab_alignment = TabBar.ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	add_theme_font_size_override("font_size", 16)
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = SproutTheme.GREEN if state == "tab_selected" else Color.TRANSPARENT
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		if state == "tab_focus":
			style.border_width_top = 2
			style.border_color = SproutTheme.GREEN_PRESSED
		add_theme_stylebox_override(state, style)
	for state in ["font_selected_color", "font_hovered_color", "font_hovered_selected_color", "font_unselected_color", "font_disabled_color"]:
		add_theme_color_override(state, SproutTheme.INK_MUTED if state in ["font_unselected_color", "font_disabled_color"] else SproutTheme.INK)
