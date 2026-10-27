extends Control
## 标题两侧简洁绿叶与细金线，不绘制下弧线或繁复枝条。
const GOLD := Color("e8ba62")
const LEAF := Color("87ad55")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _leaf(base: Vector2, tip: Vector2, width: float) -> void:
	var axis := tip - base
	var normal := Vector2(-axis.y, axis.x).normalized()
	var points := PackedVector2Array()
	for side in [1.0, -1.0]:
		for index in range(17):
			var t := float(index) / 16.0 if side > 0 else 1.0 - float(index) / 16.0
			points.append(base + axis * t + normal * sin(t * PI) * width * side)
	draw_colored_polygon(points, LEAF)
	draw_line(base, tip, Color("b9ce80"), 0.7, true)
func _draw() -> void:
	for right in [false, true]:
		var x := 30.0 if not right else 730.0
		var direction := 1.0 if not right else -1.0
		draw_line(Vector2(x + direction * 18, 40), Vector2(x + direction * 82, 40), GOLD, 1.4, true)
		draw_circle(Vector2(x + direction * 18, 40), 1.6, GOLD)
		_leaf(Vector2(x + direction * 14, 40), Vector2(x - direction * 7, 25), 5)
		_leaf(Vector2(x + direction * 10, 40), Vector2(x - direction * 17, 49), 5)
