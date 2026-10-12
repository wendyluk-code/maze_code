extends Button
## 圆形小地图的鼠标命中区域，透明四角不拦截场景点击。
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= minf(size.x,size.y) * 0.5
