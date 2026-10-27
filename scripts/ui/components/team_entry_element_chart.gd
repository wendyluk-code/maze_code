extends Control
## 只读属性关系图：节点顺序与捕获配置的克制环一致。
const Catalog := preload("res://data/maze/capture_catalog.gd")
const ORDER := ["fire", "grass", "earth", "thunder", "water", "wind"]
var elements: Array = []
var textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 190)
	for id in ORDER:
		textures[id] = load("res://assets/ui/factions/%s.png" % ("lightning" if id == "thunder" else id))
	resized.connect(queue_redraw)

func set_elements(values: Array) -> void:
	if elements == values: return
	elements = values.duplicate()
	queue_redraw()

func _draw() -> void:
	# 固定顶部内容起点；剩余高度只在底部留白，不把整图重新居中。
	var radius := minf(77.0, minf(size.x * 0.29, (size.y - 26) * 0.5))
	var center := Vector2(size.x * 0.5, radius + 13)
	var points := PackedVector2Array()
	for i in 6: points.append(center + Vector2.from_angle(-PI / 2 + i * PI / 3) * radius)
	var line := Color("#dfcba5")
	for factor in [0.5, 1.0]:
		var ring := PackedVector2Array()
		for p in points: ring.append(center + (p - center) * factor)
		ring.append(ring[0])
		draw_polyline(ring, line, 1.5, true)
	for p in points: draw_line(center, p, line, 1, true)
	for i in 6:
		if not elements.has(ORDER[i]): continue
		var start := points[i]
		var finish := points[(i + 1) % 6]
		var direction := (finish - start).normalized()
		draw_line(start, finish, Color("#6c934a"), 3, true)
		var tip := start.lerp(finish, 0.63)
		draw_polyline(PackedVector2Array([tip - direction.rotated(0.6) * 10, tip, tip - direction.rotated(-0.6) * 10]), Color("#6c934a"), 3, true)
	var font := SproutTheme.FONT_CN
	for i in 6:
		var p := points[i]
		if elements.has(ORDER[i]):
			draw_circle(p, 18, Color("#c8dda9"), true, -1, true)
			draw_arc(p, 18, 0, TAU, 40, Color("#a98049"), 1.5, true)
		if textures.has(ORDER[i]): draw_texture_rect(textures[ORDER[i]], Rect2(p - Vector2(13, 13), Vector2(26, 26)), false)
		var offset := Vector2(23, 6) if i < 4 else Vector2(-43, 6)
		draw_string(font, p + offset, Catalog.ELEMENTS[ORDER[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, SproutTheme.INK)
	var text := "捕获克制"
	draw_string(font, center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, SproutTheme.INK_MUTED)
