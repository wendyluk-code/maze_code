extends Control
## 目标高亮标记：在目标下方画一个圈 + 指向箭头的引导标
## 位置由 TutorialGuide 每帧换算（世界坐标 → 屏幕坐标），本节点只负责绘制
func _draw() -> void:
	var cx := size.x * 0.5
	var bottom := size.y
	# 底端三角（指向目标）
	draw_colored_polygon(
		PackedVector2Array([Vector2(cx, bottom), Vector2(cx - 9, bottom - 18), Vector2(cx + 9, bottom - 18)]),
		Color(1.0, 0.86, 0.3, 0.95)
	)
	# 目标上方一圈光环
	draw_arc(Vector2(cx, bottom - 44), 20.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.3, 0.95), 4.0)
	draw_arc(Vector2(cx, bottom - 44), 28.0, 0.0, TAU, 40, Color(1.0, 0.92, 0.55, 0.5), 2.0)
	# 连接线
	draw_line(Vector2(cx, bottom - 24), Vector2(cx, bottom - 76), Color(1.0, 0.9, 0.5, 0.6), 2.0)