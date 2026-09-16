class_name IsoUtil

## 等距 2:1 投影工具
## 世界坐标 (x, y)：x 向右上斜，y 向右下斜；z 为高度向上
const SX := 32.0  # 每个世界单元在屏幕上的 x 偏移
const SY := 16.0  # 每个世界单元在屏幕上的 y 偏移
const SZ := 24.0  # 每个高度单元在屏幕上的 y 偏移

static func to_screen(world_pos: Vector3) -> Vector2:
	var sx := (world_pos.x - world_pos.y) * SX
	var sy := (world_pos.x + world_pos.y) * SY - world_pos.z * SZ
	return Vector2(sx, sy)

static func to_world(screen_delta: Vector2) -> Vector2:
	# 屏幕像素增量 -> 世界 (x, y) 增量（z 固定）
	var a := screen_delta.y / SY
	var b := screen_delta.x / SX
	return Vector2((a + b) * 0.5, (a - b) * 0.5)
