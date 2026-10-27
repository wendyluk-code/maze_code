extends RefCounted
## 石阵封住出口道路，交互只在地图内侧进行。
const POSITION := Vector2(70, 714)
const FRONT := Vector2(100, 720)
const ARRIVAL := Vector2(160, 730)
const BLOCK_X := 94.0
const INTERACT_RADIUS := 70.0
static func can_bank(point: Vector2) -> bool:
 return point.x >= BLOCK_X and point.distance_to(POSITION) < INTERACT_RADIUS
