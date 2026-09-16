extends Node2D
## 等距地面：菱形轮廓 + 网格辅助线（占位）

@export var world_half_w := 13.0
@export var world_half_d := 8.0
@export var floor_color := Color(0.85, 0.75, 0.6)
@export var grid_color := Color(0.6, 0.5, 0.38, 0.25)
@export var border_color := Color(0.45, 0.35, 0.25, 0.8)
@export var show_grid := true

const SX := 32.0
const SY := 16.0

func _draw() -> void:
	var corners := PackedVector2Array()
	corners.push_back(_p(-world_half_w, -world_half_d))
	corners.push_back(_p(world_half_w, -world_half_d))
	corners.push_back(_p(world_half_w, world_half_d))
	corners.push_back(_p(-world_half_w, world_half_d))
	draw_colored_polygon(corners, floor_color)

	if show_grid:
		for x in range(-int(world_half_w), int(world_half_w) + 1):
			var a := _p(float(x), -world_half_d)
			var b := _p(float(x), world_half_d)
			draw_line(a, b, grid_color, 1.0)
		for y in range(-int(world_half_d), int(world_half_d) + 1):
			var c := _p(-world_half_w, float(y))
			var d := _p(world_half_w, float(y))
			draw_line(c, d, grid_color, 1.0)

	for i in range(4):
		draw_line(corners[i], corners[(i + 1) % 4], border_color, 2.0)

func _p(wx: float, wy: float) -> Vector2:
	return Vector2((wx - wy) * SX, (wx + wy) * SY)