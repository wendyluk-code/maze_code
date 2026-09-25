extends Control

var pointer_position := -1.0
var perfect_width := 0.16
var good_width := 0.38

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 100)
	queue_redraw()

func set_pointer(value: float) -> void:
	pointer_position = clampf(value, -1.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(20, 40, maxf(size.x - 40.0, 200.0), 18)
	draw_rect(rect, Color("#d6b58b"), true)
	var center := rect.position.x + rect.size.x * 0.5
	# 参数是归一化总宽度；指针 [-1,1] 映射到整条轨道，因此半宽需再除以 2。
	var good := rect.size.x * good_width * 0.25
	var perfect := rect.size.x * perfect_width * 0.25
	draw_rect(Rect2(center - good, rect.position.y, good * 2.0, rect.size.y), Color("#e8c76e"), true)
	draw_rect(Rect2(center - perfect, rect.position.y, perfect * 2.0, rect.size.y), Color("#8fcf9c"), true)
	var x := center + pointer_position * rect.size.x * 0.5
	draw_line(Vector2(x, 22), Vector2(x, 78), Color("#54382d"), 5.0)
	draw_string(ThemeDB.fallback_font, Vector2(center - 45, 96), "精准区", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#356849"))
