class_name IsoCubeFresh
extends Node2D
## 程序化等距方块占位（顶 + 左 + 右 三面伪 3D 块）

@export var origin := Vector2.ZERO
@export var half_w := 1.0
@export var half_d := 1.0
@export var height := 1.0
@export var color := Color(0.8, 0.7, 0.5)
@export var show_outline := false

const SX := 32.0
const SY := 16.0
const SZ := 24.0

func _ready() -> void:
	z_index = int((origin.x + origin.y) * SY)

func _draw() -> void:
	var c: Array[Vector3] = _box(0.0)
	var top: Array[Vector3] = _box(height)
	_draw_face([c[0], c[3], top[3], top[0]], color.darkened(0.35))
	_draw_face([c[0], c[1], top[1], top[0]], color.darkened(0.18))
	_draw_face([top[0], top[1], top[2], top[3]], color)
	if show_outline:
		for i in range(4):
			draw_line(_sc(top[i]), _sc(top[(i + 1) % 4]), Color(0, 0, 0, 0.5), 1.0)
			draw_line(_sc(c[i]), _sc(top[i]), Color(0, 0, 0, 0.5), 1.0)

func _box(z: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	pts.append(Vector3(origin.x - half_w, origin.y - half_d, z))
	pts.append(Vector3(origin.x + half_w, origin.y - half_d, z))
	pts.append(Vector3(origin.x + half_w, origin.y + half_d, z))
	pts.append(Vector3(origin.x - half_w, origin.y + half_d, z))
	return pts

func _sc(wp: Vector3) -> Vector2:
	# iso 投影
	return Vector2((wp.x - wp.y) * SX, (wp.x + wp.y) * SY - wp.z * SZ)

func screen_center() -> Vector2:
	return _sc(Vector3(origin.x, origin.y, height * 0.5))

func _draw_face(world_pts: Array[Vector3], col: Color) -> void:
	var sc := PackedVector2Array()
	for p in world_pts:
		sc.push_back(_sc(p))
	draw_colored_polygon(sc, col)