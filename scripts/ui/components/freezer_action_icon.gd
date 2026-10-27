extends Button
## 原生绘制图标，不依赖字体符号；保留按钮焦点及悬浮说明。
var trash := false

func _ready() -> void:
	custom_minimum_size = Vector2(34, 34)
	tooltip_text = "丢弃这份料理" if trash else "取出这份料理"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := SproutTheme.thin_panel_style(SproutTheme.CREAM if state == "normal" else SproutTheme.PANEL)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		add_theme_stylebox_override(state, style)

func _draw() -> void:
	var c := SproutTheme.INK_MUTED
	var p := size / 2.0
	if trash:
		draw_line(p + Vector2(-8,-6), p + Vector2(8,-6), c, 2, true)
		draw_line(p + Vector2(-3,-10), p + Vector2(3,-10), c, 2, true)
		draw_rect(Rect2(p + Vector2(-6,-3), Vector2(12,12)), c, false, 2)
		for x in [-2, 2]: draw_line(p + Vector2(x,-1), p + Vector2(x,7), c, 1.5, true)
	else:
		draw_polyline(PackedVector2Array([p+Vector2(-9,2),p+Vector2(-9,10),p+Vector2(9,10),p+Vector2(9,2)]),c,2,true)
		draw_line(p+Vector2(0,5),p+Vector2(0,-10),c,2,true)
		draw_polyline(PackedVector2Array([p+Vector2(-6,-4),p+Vector2(0,-10),p+Vector2(6,-4)]),c,2,true)
