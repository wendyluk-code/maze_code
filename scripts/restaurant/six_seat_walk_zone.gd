extends "res://scripts/walk_zone.gd"
## 仅替换原两段柜台阻挡；其他岛和地图外边界沿用原掩码。
const Layout := preload("res://scripts/restaurant/six_seat_layout.gd")

func _build_polygons() -> void:
	super._build_polygons()
	if not SaveManager.is_chapter_1_done(): return
	var retained: Array = []
	for polygon in obstacle_polys:
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		if bounds.has_point(Vector2(400,360)) or bounds.has_point(Vector2(950,275)):
			continue
		retained.append(polygon)
	retained.append(Layout.BODY)
	obstacle_polys = retained
	queue_redraw()
