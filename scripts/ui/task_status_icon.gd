extends Control
## 固定占位的任务状态：圆圈渐隐，绿勾按两段路径实际描绘。
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(20, 20)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var origin := (size - Vector2(20, 20)) * 0.5
	if progress < 1.0:
		draw_arc(origin + Vector2(10, 10), 6.5, 0, TAU, 32, Color(Color("#ac9167"), 1.0 - progress), 1.6, true)
	if progress <= 0.0:
		return
	var a := origin + Vector2(3, 10)
	var b := origin + Vector2(8, 15)
	var c := origin + Vector2(17, 5)
	var points := PackedVector2Array([a])
	if progress <= 0.35:
		points.append(a.lerp(b, progress / 0.35))
	else:
		points.append(b)
		points.append(b.lerp(c, (progress - 0.35) / 0.65))
	draw_polyline(points, Color("#35572b"), 5.5, true)
	draw_polyline(points, Color("#82c75e"), 3.0, true)
