extends Node2D
## 在对白暗幕上方重绘门口原图，并沿石拱轮廓缓慢闪烁。
var outline := PackedVector2Array([
	Vector2(1301, 960), Vector2(1305, 831), Vector2(1313, 805),
	Vector2(1330, 783), Vector2(1353, 766), Vector2(1379, 757),
	Vector2(1401, 758), Vector2(1424, 770), Vector2(1440, 790),
	Vector2(1447, 813), Vector2(1447, 960)
])
var background: Sprite2D
var elapsed := 0.0
var strength := 1.0

func configure_entrance(which: String) -> void:
	if which == "maze":
		# 按左侧木门的倾斜石拱取样，不使用原来的规则半圆。
		outline = PackedVector2Array([
			Vector2(65, 875), Vector2(62, 790), Vector2(66, 759),
			Vector2(78, 735), Vector2(97, 717), Vector2(118, 711),
			Vector2(138, 715), Vector2(160, 728), Vector2(177, 748),
			Vector2(189, 775), Vector2(197, 812), Vector2(212, 880)
		])

func _process(delta: float) -> void:
	if not is_instance_valid(background):
		return
	elapsed += delta
	strength = 0.5 + 0.5 * cos(elapsed * TAU / 1.4)
	# 背景本地坐标直接投影到引导层，镜头/分辨率改变时仍贴合门口。
	transform = background.get_global_transform_with_canvas()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(background) or background.texture == null:
		return
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	for index in outline.size():
		var point := outline[index]
		uv.append(point / background.texture.get_size())
		var fade := 0.0 if index == 0 or index == outline.size() - 1 else 1.0
		colors.append(Color(1, 1, 1, (0.35 + 0.65 * strength) * fade))
	draw_polygon(outline, colors, uv, background.texture)
	# 细亮芯与两层柔光，不改变门的原画与交互轮廓。
	_draw_glow(Color(1.0, 0.79, 0.32, 0.06 + 0.09 * strength), 17.0)
	_draw_glow(Color(1.0, 0.86, 0.43, 0.12 + 0.20 * strength), 9.0)
	_draw_glow(Color(1.0, 0.94, 0.66, 0.30 + 0.65 * strength), 2.5)

func _draw_glow(color: Color, width: float) -> void:
	var colors := PackedColorArray()
	for index in outline.size():
		var tint := color
		if index == 0 or index == outline.size() - 1:
			tint.a = 0.0
		colors.append(tint)
	draw_polyline_colors(outline, colors, width, true)
