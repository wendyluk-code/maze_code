extends SproutButton
## 组件库圆形返回按钮：沿用基础按钮输入与主题颜色，箭头不依赖字体字形。
const DIAMETER := 56.0

func _ready() -> void:
	set_icon_visible(false)
	super._ready()
	text = ""
	tooltip_text = "返回"
	custom_minimum_size = Vector2.ONE * DIAMETER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = SproutTheme.CREAM
		if state == "hover": fill = SproutTheme.GREEN_HOVER
		if state == "pressed": fill = SproutTheme.GREEN_PRESSED
		if state == "disabled": fill = SproutTheme.DISABLED
		var style := SproutTheme.thin_panel_style(fill)
		style.set_corner_radius_all(int(DIAMETER / 2.0))
		style.set_content_margin_all(0.0)
		add_theme_stylebox_override(state, style)
	var focus := SproutTheme.focus_style()
	focus.set_corner_radius_all(int(DIAMETER / 2.0))
	add_theme_stylebox_override("focus", focus)
	resized.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5

func _draw() -> void:
	var center := size * 0.5
	var ink := SproutTheme.INK
	draw_line(center + Vector2(-11, 0), center + Vector2(12, 0), ink, 3.5, true)
	draw_polyline(PackedVector2Array([center + Vector2(-2, -9), center + Vector2(-11, 0), center + Vector2(-2, 9)]), ink, 3.5, true)
