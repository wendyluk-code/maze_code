extends RefCounted
## 原底图三座、独立前台与顾客走道；不改变玩家碰撞和地图尺寸。
const SEATS := [Vector2(471,251), Vector2(397,264), Vector2(321,278)]
const COUNTER := Vector2(910,198)
const ENTRANCE := Vector2(1170,150)
const AISLE := Vector2(760,170)

static func service_point(index: int) -> Vector2:
	var seat: Vector2 = SEATS[index]
	return Vector2(seat.x, 480.0 - (seat.x - 183.0) * 59.0 / 521.0)

static func seat_path(index: int) -> Array[Vector2]:
	return [AISLE, SEATS[index] + Vector2(0,-40), SEATS[index] + Vector2(0,24)]

static func exit_path(index: int) -> Array[Vector2]:
	if index < 0: return [ENTRANCE]
	return [SEATS[index] + Vector2(0,-40), AISLE, COUNTER, ENTRANCE]
