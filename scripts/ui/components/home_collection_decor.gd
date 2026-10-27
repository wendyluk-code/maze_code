extends Control
## 冒险者之家收藏页的轻量水彩叶饰，不承载交互。
var kind := 0
var mirrored := false
var tint := Color(0.56, 0.40, 0.20, 0.68)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _leaf(center: Vector2, angle: float, length: float, color: Color) -> void:
	var direction := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([
		center - direction * length * 0.5,
		center - direction * length * 0.02 + normal * length * 0.3,
		center + direction * length * 0.28 + normal * length * 0.2,
		center + direction * length * 0.5,
		center + direction * length * 0.28 - normal * length * 0.2,
		center - direction * length * 0.02 - normal * length * 0.3,
	])
	draw_colored_polygon(points, color)
	draw_line(center - direction * length * 0.38, center + direction * length * 0.38, Color(color, color.a + 0.12), 0.8, true)

func _draw() -> void:
	if kind == 0 or kind == 1:
		var mirror := -1.0 if kind == 1 else 1.0
		var base := Vector2(28 if kind == 0 else 2, 32)
		var stem := base + Vector2(20 * mirror, -24)
		draw_line(base, stem, tint, 1.4, true)
		_leaf(base + Vector2(7 * mirror, -8), -1.0 * mirror, 18, tint)
		_leaf(base + Vector2(14 * mirror, -17), -2.0 * mirror, 16, tint)
		_leaf(base + Vector2(19 * mirror, -25), -0.65 * mirror, 15, tint)
	elif kind == 2:
		var base := Vector2(6 if mirrored else 28, 28)
		var direction := -1.0 if mirrored else 1.0
		draw_line(base, base + Vector2(16 * direction, -18), tint, 1.1, true)
		_leaf(base + Vector2(6 * direction, -6), -2.3 * direction, 14, tint)
		_leaf(base + Vector2(12 * direction, -13), -0.6 * direction, 13, tint)
