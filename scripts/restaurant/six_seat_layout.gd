extends RefCounted
## 已确认的六座吧台。地图其余区域继续显示原始底图，尺寸与坐标不变。
const TEXTURE := "res://assets/restaurant_layout/bar_six_seat_preview.png"
const SEATS := [Vector2(283,282),Vector2(430,265),Vector2(568,247),Vector2(700,230),Vector2(827,213),Vector2(980,193)]
static var PATCH := PackedVector2Array([Vector2(148,308),Vector2(235,296),Vector2(240,245),Vector2(365,220),Vector2(405,140),Vector2(540,140),Vector2(585,182),Vector2(1020,135),Vector2(1120,185),Vector2(1120,329),Vector2(780,403),Vector2(190,477),Vector2(148,410)])
static var BODY := PackedVector2Array([Vector2(163,342),Vector2(1087,224),Vector2(1085,316),Vector2(183,452)])

static func service_point(index: int) -> Vector2:
	var seat: Vector2 = SEATS[index]
	return Vector2(seat.x, 479.0 - (seat.x - 183.0) * 136.0 / 902.0)
