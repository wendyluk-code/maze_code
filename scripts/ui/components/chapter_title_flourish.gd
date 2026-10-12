extends Control
## 原生矢量芽叶与金色弧线，随章节标题整体缩放。

const CREAM := Color("f7efd7")
const GOLD := Color("d7af70")
const LEAF := Color("879c58")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _curve(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, Color(0.10, 0.13, 0.07, 0.55), width + 5.0, true)
	draw_polyline(points, CREAM, width + 2.5, true)
	draw_polyline(points, color, width, true)

func _leaf(base: Vector2, tip: Vector2, width: float, color: Color) -> void:
	var axis := tip - base
	var normal := Vector2(-axis.y, axis.x).normalized()
	var points := PackedVector2Array()
	for side in [1.0, -1.0]:
		for index in range(17):
			var t := float(index) / 16.0 if side > 0 else 1.0 - float(index) / 16.0
			points.append(base + axis * t + normal * sin(t * PI) * width * side)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, CREAM, 2.0, true)
	draw_line(base + axis * 0.18, base + axis * 0.78, Color(0.96, 0.92, 0.77, 0.38), 1.0, true)

func _draw() -> void:
	# 轻微不对称的芽叶呼应游戏标志，不包成面板边框。
	_curve(PackedVector2Array([Vector2(65, 87), Vector2(53, 72), Vector2(48, 53)]), LEAF, 3.0)
	_leaf(Vector2(53, 73), Vector2(24, 51), 9, LEAF)
	_leaf(Vector2(50, 63), Vector2(56, 29), 10, Color("9ca76b"))
	_curve(PackedVector2Array([Vector2(634, 88), Vector2(646, 72), Vector2(650, 50)]), LEAF, 3.0)
	_leaf(Vector2(646, 69), Vector2(677, 48), 9, LEAF)
	_leaf(Vector2(649, 61), Vector2(641, 27), 10, Color("9ca76b"))
	var arc := PackedVector2Array()
	for index in range(65):
		var t := float(index) / 64.0
		arc.append(Vector2(104 + t * 490, 116 + sin(t * PI) * 22))
	_curve(arc, GOLD, 4.0)
	_leaf(Vector2(591, 118), Vector2(617, 100), 7, GOLD)
	# “完”左右的细枝只作点缀，让文字本身成为视觉中心。
	for direction in [-1.0, 1.0]:
		var start := Vector2(350 + direction * 78, 220)
		var end := Vector2(350 + direction * 156, 221)
		draw_line(start, end, GOLD, 1.5, true)
		_leaf(Vector2(350 + direction * 115, 220), Vector2(350 + direction * 132, 204), 5, LEAF)
		_leaf(Vector2(350 + direction * 132, 221), Vector2(350 + direction * 151, 235), 5, Color("aa955e"))
