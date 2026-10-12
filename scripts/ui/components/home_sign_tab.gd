extends Button
## 直接使用批准稿的页签切片；文字保持原生可更新。
const GOLD := Color("#9a6b2f")
const SELECTED_ART := preload("res://assets/ui/home_collection/tab_selected.png")
const IDLE_ART := preload("res://assets/ui/home_collection/tab_idle.png")
var selected := false
var caption: Label

func _ready() -> void:
	theme = SproutTheme.make_theme()
	custom_minimum_size = Vector2(156, 68)
	size = custom_minimum_size
	pivot_offset = Vector2(0, 34)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	caption = Label.new()
	caption.text = text
	text = ""
	caption.position = Vector2(28, 0)
	caption.size = Vector2(90, 68)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 24)
	add_child(caption)
	set_selected(selected)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func set_selected(value: bool) -> void:
	selected = value
	scale = Vector2.ONE if value else Vector2(0.88, 0.98)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, GOLD if value else SproutTheme.CREAM)
	if is_instance_valid(caption): caption.add_theme_color_override("font_color", GOLD if value else SproutTheme.CREAM)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(SELECTED_ART if selected else IDLE_ART, Rect2(Vector2.ZERO, size), false)
	if has_focus(): draw_line(Vector2(40, 58), Vector2(112, 58), GOLD, 1, true)
