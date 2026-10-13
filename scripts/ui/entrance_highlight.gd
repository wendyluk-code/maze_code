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
		# 左缘被原画树叶挡住，只绘制露出的上拱和右侧内缘。
		inner_edges = [PackedVector2Array([
			Vector2(103, 734), Vector2(119, 727), Vector2(134, 731),
			Vector2(151, 742), Vector2(166, 761), Vector2(177, 787),
			Vector2(184, 819), Vector2(195, 862)
		])]
		motes = PackedVector2Array([Vector2(108, 884), Vector2(139, 872), Vector2(173, 873), Vector2(191, 882)])
	else:
		# 蓝旗、灯和下方植物继续遮住门；不沿植物轮廓补成光圈。
		inner_edges = [PackedVector2Array([
			Vector2(1320, 879), Vector2(1321, 838), Vector2(1327, 816),
			Vector2(1340, 798), Vector2(1359, 784), Vector2(1380, 778),
			Vector2(1398, 779), Vector2(1416, 789), Vector2(1427, 805),
			Vector2(1430, 826), Vector2(1430, 881)
		])]
		motes = PackedVector2Array([Vector2(1315, 942), Vector2(1320, 951), Vector2(1325, 961), Vector2(1318, 967)])

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
		_draw_edge(edge, Color(1.0, 0.79, 0.36, 0.05 + 0.07 * strength), 3.0)
		_draw_edge(edge, Color(1.0, 0.86, 0.49, 0.30 + 0.26 * strength), 1.0)
	for index in motes.size():
		var phase := fposmod(elapsed / 4.8 + float(index) * 0.23, 1.0)
		var point := motes[index] + Vector2(sin(phase * TAU + index) * 0.7, -phase * 5.0)
		var alpha := sin(phase * PI) * (0.30 + 0.18 * strength)
		draw_circle(point, 2.0, Color(1.0, 0.77, 0.30, alpha * 0.16))
		draw_circle(point, 0.85, Color(1.0, 0.87, 0.48, alpha))

func _draw_edge(edge: PackedVector2Array, color: Color, width: float) -> void:
	var colors := PackedColorArray()
	for index in edge.size():
		var tint := color
		if index == 0 or index == edge.size() - 1:
			tint.a *= 0.25
		colors.append(tint)
	draw_polyline_colors(edge, colors, width, true)
