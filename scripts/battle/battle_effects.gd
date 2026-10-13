extends Node2D
## 战斗局部绘制：目标曲线、命中环和纸屑。不持有牌局状态。
var aim_visible := false
var aim_from := Vector2.ZERO
var aim_to := Vector2.ZERO
var aim_valid := false
var bursts: Array[Dictionary] = []
var dissolves: Array[Dictionary] = []

func dissolve(at: Vector2, color: Color) -> void:
	dissolves.append({"at": at, "color": color, "age": 0.0})

func burst(at: Vector2, color: Color, strong := false) -> void:
	bursts.append({"at": at, "color": color, "age": 0.0, "strong": strong})

func _process(delta: float) -> void:
	for item in bursts:
		item.age += delta
	bursts = bursts.filter(func(item: Dictionary) -> bool: return item.age < 0.65)
	for item in dissolves: item.age += delta
	dissolves = dissolves.filter(func(item: Dictionary) -> bool: return item.age < 0.75)
	queue_redraw()

func _draw() -> void:
	# 低透明度叠色水彩点，复用战斗色系，不加载新素材。
	for item in dissolves:
		var t: float = item.age / 0.75
		for i in range(18):
			var direction := Vector2.from_angle(i * TAU / 18.0)
			var at: Vector2 = item.at + direction * (18 + t * (38 + i % 4 * 9)) + Vector2(0, -t * 22)
			var color: Color = item.color
			color.a = (1.0 - t) * 0.22
			draw_circle(at, (7 + i % 3 * 4) * (1.0 - t * 0.5), color)
	if aim_visible:
		var color := Color("#83e1c4") if aim_valid else Color("#e8d7a7")
		var bend := (aim_from + aim_to) * 0.5 + Vector2(-55, -65)
		var points := PackedVector2Array()
		for i in range(33):
			var t := i / 32.0
			points.append(aim_from.lerp(bend, t).lerp(bend.lerp(aim_to, t), t))
		draw_polyline(points, Color(0.1, 0.22, 0.2, 0.45), 8, true)
		draw_polyline(points, color, 3, true)
		var direction := (aim_to - bend).normalized()
		var normal := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([aim_to, aim_to - direction * 19 + normal * 9, aim_to - direction * 19 - normal * 9]), color)
		draw_arc(aim_to, 23, 0, TAU, 40, color, 2, true)
	for item in bursts:
		var t: float = item.age / 0.65
		var color: Color = item.color
		color.a *= 1.0 - t
		var radius: float = lerpf(8, 110 if item.strong else 65, t)
		draw_arc(item.at, radius, 0, TAU, 64, color, 3 * (1 - t) + 1, true)
		for i in range(12):
			var angle := i * TAU / 12.0 + t * 0.5
			var direction := Vector2.from_angle(angle)
			var p: Vector2 = item.at + direction * radius
			draw_line(p, p + direction * 12 * (1 - t), color, 3, true)
