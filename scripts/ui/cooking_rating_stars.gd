extends Control
## 固定三颗星槽：金色亮星与浅色凹槽，不依赖字体里的星号字形。
const CENTERS := [Vector2(48, 60), Vector2(132, 47), Vector2(216, 60)]
const RADII := [31.0, 38.0, 31.0]
var uniform := false
var quality := 0
var elapsed := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(264, 108)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func present(value: int) -> void:
	quality = clampi(value, 1, 3)
	elapsed = 0.0
	set_process(true)
	queue_redraw()

func stop() -> void:
	set_process(false)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= 1.1:
		set_process(false)

func _shape(center: Vector2, radius: float) -> PackedVector2Array:
	var corners: Array[Vector2] = []
	for i in 10:
		var angle := -PI / 2.0 + float(i) * PI / 5.0
		corners.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 if i % 2 == 0 else 0.55))
	var points := PackedVector2Array()
	for i in 10:
		var corner := corners[i]
		# 外尖大圆角、内凹柔和过渡，让轮廓更饱满。
		var rounding := 0.40 if i % 2 == 0 else 0.28
		var start := corner.lerp(corners[(i + 9) % 10], rounding)
		var finish := corner.lerp(corners[(i + 1) % 10], rounding)
		for j in 10:
			var t := float(j) / 9.0
			points.append(start.lerp(corner, t).lerp(corner.lerp(finish, t), t))
	return points

func _solid(center: Vector2, radius: float, color: Color) -> void:
	var shape := _shape(center, radius)
	draw_colored_polygon(shape, color)
	shape.append(shape[0])
	draw_polyline(shape, color, 0.8, true)

func _draw() -> void:
	for index in 3:
		var center: Vector2 = Vector2(48 + 84 * index, 54) if uniform else CENTERS[index]
		var radius: float = 31.0 if uniform else RADII[index]
		# 三个槽位始终可见，缺星不移动、不用文字补位。
		_solid(center + Vector2(0, 3), radius, Color("#b99055"))
		_solid(center, radius, Color("#cba66a"))
		_solid(center + Vector2(0, 1), radius * 0.88, Color("#edd6a9"))
		if index >= quality:
			continue
		var t := clampf((elapsed - float(index) * 0.16) / 0.38, 0.0, 1.0)
		if t <= 0.0:
			continue
		var back := 1.0 + 2.70158 * pow(t - 1.0, 3) + 1.70158 * pow(t - 1.0, 2)
		radius *= 0.65 + 0.35 * back
		_solid(center + Vector2(0, 5), radius, Color("#b9650c"))
		_solid(center, radius, Color("#ee9a0a"))
		var face := _shape(center + Vector2(0, -1), radius * 0.90)
		var colors := PackedColorArray()
		for point in face:
			var y := clampf((point.y - center.y + radius) / (radius * 2.0), 0.0, 1.0)
			colors.append(Color("#fff58a").lerp(Color("#ffbd0c"), y))
		draw_polygon(face, colors)
		face.append(face[0])
		colors.append(colors[0])
		draw_polyline_colors(face, colors, 0.8, true)
		# 上缘高光与小闪点，保留手绘UI的柔和轮廓。
		draw_line(center + Vector2(-3, -radius * 0.66), center + Vector2(-radius * 0.18, -radius * 0.27), Color("#fffbd5"), 3.0, true)
		var sparkle := sin(clampf((elapsed - float(index) * 0.16) / 0.75, 0.0, 1.0) * PI)
		if sparkle > 0.01:
			var p := center + Vector2(radius * 0.85, -radius * 0.72)
			var light := Color(1.0, 0.98, 0.73, sparkle)
			draw_line(p - Vector2(0, 5), p + Vector2(0, 5), light, 2.0, true)
			draw_line(p - Vector2(4, 0), p + Vector2(4, 0), light, 2.0, true)
