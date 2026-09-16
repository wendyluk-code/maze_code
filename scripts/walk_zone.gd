extends Node2D
## 可走区域：从涂鸦掩码图（绿色=可走）提取多边形 + 内部道具岛

@export_file("*.png") var mask_path: String = "res://assets/maps/walkable_mask.png"
@export var sample_step := 2
@export var green_tolerance := 60.0
@export var debug_draw := false

var polygons: Array = []
var obstacle_polys: Array = []
var img_w := 0
var img_h := 0

func _ready() -> void:
	add_to_group("walk_zone")
	_build_polygons()

func _build_polygons() -> void:
	var tex := load(mask_path) as Texture2D
	if tex == null:
		push_error("walkable mask not found: " + mask_path)
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var size := img.get_size()
	var data := img.get_data()
	var w := int(size.x)
	var h := int(size.y)
	img_w = w
	img_h = h

	var bm := BitMap.new()
	bm.create(size)
	for y in range(0, h, sample_step):
		for x in range(0, w, sample_step):
			var i := (y * w + x) * 4
			var r: float = data[i] / 255.0
			var g: float = data[i + 1] / 255.0
			var b: float = data[i + 2] / 255.0
			if g > 0.51 and (g - r) > 0.39 and r < 0.157 and b > 0.157 and b < 0.59:
				for dyy in range(sample_step):
					for dxx in range(sample_step):
						var bx := x + dxx
						var by := y + dyy
						if bx < w and by < h:
							bm.set_bit(bx, by, true)

	# 可走外轮廓（opaque_to_polygons 不支持洞，只给外环）
	var raw := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 2.0)
	polygons.clear()
	for p in raw:
		polygons.append(p)

	# 内部道具岛：非绿像素中，未被"连通到图像边缘的背景"覆盖的封闭岛
	obstacle_polys.clear()
	var bg := _background_mask(bm, w, h)
	var island_bm := BitMap.new()
	island_bm.create(size)
	for y in range(0, h):
		for x in range(0, w):
			if not bm.get_bit(x, y) and bg[y * w + x] == 0:
				island_bm.set_bit(x, y, true)
	var islands := island_bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 2.0)
	for ip in islands:
		obstacle_polys.append(ip)
	print("[WalkZone] polygons: ", polygons.size(), "  islands: ", obstacle_polys.size())
	queue_redraw()

func _background_mask(green: BitMap, w: int, h: int) -> PackedByteArray:
	# BFS from image border: mark non-green pixels connected to the border (background)
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []  # BFS 栈
	for x in range(w):
		for y in [0, h - 1]:
			var i: int = y * w + x
			if not green.get_bit(x, y) and bg[i] == 0:
				bg[i] = 1
				stack.append(i)
	for y in range(h):
		for x in [0, w - 1]:
			var i: int = y * w + x
			if not green.get_bit(x, y) and bg[i] == 0:
				bg[i] = 1
				stack.append(i)
	while stack.size() > 0:
		var i: int = stack.pop_back()
		var x: int = i % w
		var y: int = i / w
		for n in [i - w, i + w, i - 1, i + 1]:
			if n < 0 or n >= w * h:
				continue
			var nx: int = n % w
			var ny: int = n / w
			if abs(nx - x) + abs(ny - y) != 1:
				continue
			if not green.get_bit(nx, ny) and bg[n] == 0:
				bg[n] = 1
				stack.append(n)
	return bg

func is_point_inside(p: Vector2) -> bool:
	# 必须在可走外轮廓内，且不在任何道具岛内
	var in_walk := false
	for poly in polygons:
		if Geometry2D.is_point_in_polygon(p, poly):
			in_walk = true
			break
	if not in_walk:
		return false
	for op in obstacle_polys:
		if Geometry2D.is_point_in_polygon(p, op):
			return false
	return true

func get_spawn_point() -> Vector2:
	# 优先用最大可走多边形的质心；若落在道具岛上，从质心向外扩展搜索可走点
	var best: PackedVector2Array = PackedVector2Array()
	var best_area := 0.0
	for poly in polygons:
		var a := polygon_cross_sum(poly)
		if absf(a) > best_area:
			best_area = absf(a)
			best = poly
	if best.size() < 3:
		return Vector2.ZERO
	var cross_sum := polygon_cross_sum(best)
	if absf(cross_sum) < 0.001:
		return Vector2(700, 620)
	var c := Vector2.ZERO
	for i in best.size():
		var p := best[i]
		var q := best[(i + 1) % best.size()]
		c += (p + q) * p.cross(q)
	c /= 3.0 * cross_sum
	if is_point_inside(c):
		return c
	# 从质心向外扩展矩形搜索
	var step: int = 32
	var cxi: int = int(c.x)
	var cyi: int = int(c.y)
	var grow: int = 0
	while grow < 2400:
		var x0: int = maxi(0, cxi - grow)
		var x1: int = mini(img_w, cxi + grow)
		var y0: int = maxi(0, cyi - grow)
		var y1: int = mini(img_h, cyi + grow)
		var gy: int = y0
		while gy < y1:
			var gx: int = x0
			while gx < x1:
				var cand := Vector2(gx, gy)
				if is_point_inside(cand):
					return cand
				gx += step
			gy += step
		grow += step
	return Vector2(700, 620)

func polygon_cross_sum(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.cross(q)
	return s

func nearest_obstacle(point: Vector2) -> PackedVector2Array:
	# 只认"点落在岛内部"的道具岛；可走区的点不匹配任何岛 -> 返回空
	for op in obstacle_polys:
		var poly: PackedVector2Array = op
		if poly.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, poly):
			return poly
	return PackedVector2Array()

func top_anchor_of(point: Vector2) -> Vector2:
	# "点所在道具岛"的顶部边界（世界 y 最小）水平中心；
	# 点不在任何岛内时返回 ZERO，由调用方回退到交互点自身坐标
	var poly := nearest_obstacle(point)
	if poly.size() < 3:
		return Vector2.ZERO
	return top_anchor_of_poly(poly)

func top_anchor_of_poly(poly: PackedVector2Array) -> Vector2:
	var top_y := INF
	for p in poly:
		if p.y < top_y:
			top_y = p.y
	var left_x := INF
	var right_x := -INF
	for p in poly:
		if absf(p.y - top_y) < 1.0:
			if p.x < left_x:
				left_x = p.x
			if p.x > right_x:
				right_x = p.x
	return Vector2((left_x + right_x) * 0.5, top_y)

func _draw() -> void:
	if not debug_draw:
		return
	for poly in polygons:
		if poly.size() < 2:
			continue
		var closed := PackedVector2Array(poly)
		closed.append(closed[0])
		draw_polyline(closed, Color(1, 0, 0, 0.95), 4.0)
	for op in obstacle_polys:
		if op.size() < 2:
			continue
		var closed := PackedVector2Array(op)
		closed.append(closed[0])
		draw_polyline(closed, Color(0, 1, 1, 0.95), 4.0)
