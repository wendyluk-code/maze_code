extends Node2D
## 复用对白暗幕上方的入口节点，细暖金线贴门框内缘。
const BREATH_SECONDS := 3.6
var outline := PackedVector2Array([
	Vector2(1301, 960), Vector2(1305, 831), Vector2(1313, 805),
	Vector2(1330, 783), Vector2(1353, 766), Vector2(1379, 757),
	Vector2(1401, 758), Vector2(1424, 770), Vector2(1440, 790),
	Vector2(1447, 813), Vector2(1447, 960)
])
var inner_edges: Array[PackedVector2Array] = []
var motes := PackedVector2Array()
var background: Sprite2D
var elapsed := 0.0
var strength := 1.0

func configure_entrance(which: String) -> void:
	if which == "maze":
		outline = PackedVector2Array([
			Vector2(65, 875), Vector2(62, 790), Vector2(66, 759),
			Vector2(78, 735), Vector2(97, 717), Vector2(118, 711),
			Vector2(138, 715), Vector2(160, 728), Vector2(177, 748),
			Vector2(189, 775), Vector2(197, 812), Vector2(212, 880)
		])
		# 左缘只在植物缝隙露出短段，不穿过覆盖叶片。
		inner_edges = [PackedVector2Array([
			Vector2(103, 734), Vector2(119, 727), Vector2(134, 731),
			Vector2(151, 742), Vector2(166, 761), Vector2(177, 787),
			Vector2(184, 819), Vector2(195, 862)
		]), PackedVector2Array([Vector2(69, 794), Vector2(70, 810), Vector2(73, 837), Vector2(76, 850)]),
		PackedVector2Array([Vector2(72, 762), Vector2(69, 777)])]
		motes = PackedVector2Array([Vector2(179, 850), Vector2(192, 881), Vector2(158, 923), Vector2(135, 901)])
	else:
		# 蓝旗与植物覆盖处断开，保留稿中露出的下缘短段。
		inner_edges = [PackedVector2Array([
			Vector2(1320, 879), Vector2(1321, 838), Vector2(1327, 816),
			Vector2(1340, 798), Vector2(1359, 784), Vector2(1380, 778),
			Vector2(1398, 779), Vector2(1416, 789), Vector2(1427, 805),
			Vector2(1430, 826), Vector2(1430, 881)
		]), PackedVector2Array([Vector2(1320, 887), Vector2(1320, 917), Vector2(1320, 943)]),
		PackedVector2Array([Vector2(1321, 961), Vector2(1327, 976), Vector2(1340, 978)])]
		motes = PackedVector2Array([Vector2(1320, 927), Vector2(1330, 951), Vector2(1314, 970), Vector2(1321, 988)])

	for index in inner_edges.size():
		inner_edges[index] = _smooth_edge(inner_edges[index])

func _smooth_edge(points: PackedVector2Array) -> PackedVector2Array:
	var curve := Curve2D.new()
	for index in points.size():
		var previous := points[maxi(0, index - 1)]
		var following := points[mini(points.size() - 1, index + 1)]
		var tangent := (following - previous) / 6.0
		curve.add_point(points[index], -tangent if index > 0 else Vector2.ZERO, tangent if index < points.size() - 1 else Vector2.ZERO)
	curve.bake_interval = 1.0
	return curve.get_baked_points()

func _process(delta: float) -> void:
	if not is_instance_valid(background):
		return
	elapsed += delta
	strength = 0.5 + 0.5 * cos(elapsed * TAU / BREATH_SECONDS)
	# 保留背景本地坐标投影，跟随现有镜头与窗口。
	transform = background.get_global_transform_with_canvas()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(background) or background.texture == null:
		return
	# 背景与植物只使用原场景绘制，避免纹理重绘形成硬边亮斑。
	for edge in inner_edges:
		_draw_edge(edge, Color(1.0, 0.66, 0.18, 0.05 + 0.025 * strength), 7.0)
		_draw_edge(edge, Color(1.0, 0.76, 0.29, 0.18 + 0.08 * strength), 4.0)
		_draw_edge(edge, Color(1.0, 0.86, 0.46, 0.76 + 0.18 * strength), 1.65)
	for index in motes.size():
		var phase := fposmod(elapsed / 4.8 + float(index) * 0.23, 1.0)
		var point := motes[index] + Vector2(sin(phase * TAU + index) * 0.7, -phase * 5.0)
		var alpha := (0.70 + 0.30 * sin(phase * PI)) * (0.82 + 0.16 * strength)
		for ring in range(20, 0, -1):
			var radius := float(ring) * 0.5
			draw_circle(point, radius, Color(1.0, 0.69, 0.17, alpha * 0.085 * pow(1.0 - float(ring) / 21.0, 1.4)))
		draw_circle(point, 2.0, Color(1.0, 0.84, 0.39, alpha * 0.8))
		draw_circle(point, 1.0, Color(1.0, 0.95, 0.70, alpha))

func _draw_edge(edge: PackedVector2Array, color: Color, width: float) -> void:
	var colors := PackedColorArray()
	for index in edge.size():
		var tint := color
		var point := edge[index]
		var variation := 0.70 + 0.30 * sin(point.y * 0.085 + point.x * 0.045)
		tint.a *= variation
		if index == 0 or index == edge.size() - 1:
			tint.a *= 0.25
		colors.append(tint)
	draw_polyline_colors(edge, colors, width, true)
