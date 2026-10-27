extends Control
## 透明锅体与独立动态图层。弧段边界和 QTE 使用同一份宽度参数。
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")
const Judgement := preload("res://scripts/cooking/qte_judgement.gd")
const DESIGN_SIZE := Vector2(1536, 1024)
const ARC_CENTER := Vector2(768, 180)
const ARC_RADIUS := Vector2(500, 135)
const BAND_WIDTH := 48.0
const POT_SCALE := 0.94
const POT_OFFSET := Vector2(46.08, 190)
const POT_PATH := "res://assets/ui/cooking/pot_base.png"
const FIRE_PATH := "res://assets/ui/cooking/flame.png"
const POINTER_PATH := "res://assets/ui/cooking/cooking_pointer_v1.png"
const POINTER_HEIGHT := 104.0
# 原图 alpha>=0.05 的主体边界为(453,112,348,1012)，四边各留2像素。
# 外部极低 alpha 杂点不作为显示尺寸；此矩形不修改源图，也不裁两尖。
const POINTER_REGION := Rect2(451, 110, 352, 1016)
const ZONE_RED := Color("#ed6457")
const ZONE_YELLOW := Color("#ffdb69")
const ZONE_GREEN := Color("#7bc986")

var pointer_position := -1.0
var perfect_width := 0.16
var good_width := 0.80
var zone_center := 0.0
var running := false
var tutorial_highlight := false
var animation_time := 0.0
var ingredients: Dictionary = {}
var _icons: Dictionary = {}
var _pot: Texture2D
var _fire: Texture2D
var _pointer: AtlasTexture
var _pointer_sprite: Sprite2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pot = _load_texture(POT_PATH)
	_fire = _sprite_region(FIRE_PATH, Rect2(230, 75, 810, 1100))
	var pointer_source := _load_texture(POINTER_PATH)
	if pointer_source != null:
		# 原图像素与真实 alpha 不变，仅以非透明边界去除显示留白。
		_pointer = AtlasTexture.new()
		_pointer.atlas = pointer_source
		_pointer.region = POINTER_REGION
		_pointer.filter_clip = true
		_pointer_sprite = Sprite2D.new()
		_pointer_sprite.name = "GoldPointer"
		_pointer_sprite.texture = _pointer
		# 只让高分辨率指针平滑缩小，不改变锅体、食材等既有像素采样。
		_pointer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(_pointer_sprite)
	set_process(false)
	queue_redraw()

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("料理台素材缺失：" + path)
		return null
	return load(path) as Texture2D

func _sprite_region(path: String, region: Rect2) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = _load_texture(path)
	texture.region = region
	return texture

func set_pointer(value: float) -> void:
	pointer_position = clampf(value, -1.0, 1.0)
	queue_redraw()

func set_running(value: bool) -> void:
	running = value
	if not running:
		animation_time = 0.0
	set_process(running and not tutorial_highlight)
	queue_redraw()

func set_tutorial_highlight(value: bool) -> void:
	tutorial_highlight = value
	set_process(running and not tutorial_highlight)
	queue_redraw()

func set_ingredients(value: Dictionary) -> void:
	ingredients.clear()
	_icons.clear()
	var display := preload("res://scripts/ui/components/loot_modal.gd").new()
	for item_id in value:
		var entry := Catalog.get_ingredient(str(item_id))
		if entry.is_empty() or int(value[item_id]) <= 0:
			continue
		ingredients[str(item_id)] = int(value[item_id])
		# 正式原料可暂缺已批准图片；显示名称，不加载空路径或借用成品图。
		if str(entry.get("icon", "")).is_empty(): continue
		var source := _load_texture(str(entry.get("icon", "")))
		if source == null:
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = entry.get("icon_region", Rect2(Vector2.ZERO, source.get_size()))
		_icons[str(item_id)] = display.display_texture(atlas)
	display.free()
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _exit_tree() -> void:
	set_running(false)

func _design_scale() -> float:
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)

func _design_offset() -> Vector2:
	return (size - DESIGN_SIZE * _design_scale()) * 0.5

func arc_point(fraction: float, inset := 0.0) -> Vector2:
	return _arc_centerline(fraction) + _arc_normal(fraction) * (BAND_WIDTH * 0.5 - inset)

func _arc_centerline(fraction: float) -> Vector2:
	# 色带与指针使用同一条中心轨迹；厚度仅向两侧扩展。
	var progress := clampf(fraction, 0.0, 1.0) * 2.0 - 1.0
	return ARC_CENTER + Vector2(progress * ARC_RADIUS.x, progress * progress * ARC_RADIUS.y)

func _arc_normal(fraction: float) -> Vector2:
	var progress := clampf(fraction, 0.0, 1.0) * 2.0 - 1.0
	return Vector2(2.0 * ARC_RADIUS.y * progress, -ARC_RADIUS.x).normalized()

func pointer_tip() -> Vector2:
	# 保留原检测入口：返回菱形中心，也就是与色带中线的交点。
	return _design_offset() + _arc_centerline((pointer_position + 1.0) * 0.5) * _design_scale()

func countdown_center() -> Vector2:
	return _design_offset() + Vector2(768, 265) * _design_scale()

func zone_boundaries() -> PackedFloat32Array:
	# [-1, 1] 的判定半宽映射到 [0, 1]，须再除以二。
	var center := (zone_center + 1.0) * 0.5
	return PackedFloat32Array([0.0, center - good_width * 0.25, center - perfect_width * 0.25, center + perfect_width * 0.25, center + good_width * 0.25, 1.0])

func _draw() -> void:
	var factor := _design_scale()
	draw_set_transform(_design_offset() + POT_OFFSET * factor, 0.0, Vector2.ONE * factor * POT_SCALE)
	if _pot != null:
		draw_texture_rect(_pot, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	if running:
		_draw_fire()
		_draw_steam()
	_draw_ingredients()
	draw_set_transform(_design_offset(), 0.0, Vector2.ONE * factor)
	var boundaries := zone_boundaries()
	for index in range(boundaries.size() - 1):
		var start := boundaries[index]
		var end := boundaries[index + 1]
		var stars := Judgement.stars_for_position((start + end) - 1.0, perfect_width, good_width, zone_center)
		_draw_band(start, end, ZONE_GREEN if stars == 3 else (ZONE_YELLOW if stars == 2 else ZONE_RED))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for step in range(129):
		outer.append(arc_point(float(step) / 128.0))
		inner.append(arc_point(float(step) / 128.0, BAND_WIDTH))
	draw_polyline(outer, Color("#fff9e8"), 4.0, true)
	draw_polyline(inner, Color("#fff9e8"), 4.0, true)
	draw_line(outer[0], inner[0], Color("#fff9e8"), 4.0, true)
	draw_line(outer[-1], inner[-1], Color("#fff9e8"), 4.0, true)
	if tutorial_highlight:
		var glow := PackedVector2Array()
		for step in range(25):
			glow.append(_arc_centerline(lerpf(boundaries[2], boundaries[3], float(step) / 24.0)))
		draw_polyline(glow, Color(0.7, 1.0, 0.66, 0.3), BAND_WIDTH + 34.0, true)
		_draw_band(boundaries[2], boundaries[3], Color("#a4f39c"))
	_draw_pointer()
	draw_set_transform(Vector2.ZERO)

func _draw_band(start: float, end: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := maxi(3, ceili((end - start) * 150.0))
	for step in range(steps + 1):
		points.append(arc_point(lerpf(start, end, float(step) / steps)))
	for step in range(steps, -1, -1):
		points.append(arc_point(lerpf(start, end, float(step) / steps), BAND_WIDTH))
	draw_colored_polygon(points, color)

func _draw_pointer() -> void:
	var fraction := (pointer_position + 1.0) * 0.5
	var center := _arc_centerline(fraction)
	var normal := _arc_normal(fraction)
	var tangent := Vector2(-normal.y, normal.x)
	if _pointer == null:
		return
	var factor := _design_scale()
	# 原轨迹交点仍为纹理中心，两尖沿色带法线转向；评分与速度不参与显示变换。
	_pointer_sprite.position = _design_offset() + center * factor
	_pointer_sprite.rotation = tangent.angle()
	_pointer_sprite.scale = Vector2.ONE * (factor * POINTER_HEIGHT / _pointer.region.size.y)

func _draw_ingredients() -> void:
	var count := ingredients.size()
	if count == 0:
		return
	var index := 0
	for id in ingredients:
		var center := Vector2(768 + (float(index) - float(count - 1) * 0.5) * 255.0, 330)
		var wiggle := sin(animation_time * 5.0 + index * 2.2) if running else 0.0
		center.y += wiggle * 9.0
		var texture: Texture2D = _icons.get(id)
		if texture != null:
			var source_size := texture.get_size()
			var icon_size := source_size * minf(160.0 / source_size.x, 144.0 / source_size.y)
			draw_texture_rect(texture, Rect2(center - icon_size * 0.5, icon_size), false)
		else:
			draw_string(SproutTheme.FONT_CN, center + Vector2(-110, 12), str(Catalog.get_ingredient(id).get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, 220, 36, SproutTheme.INK)
		var number := str(ingredients[id])
		var baseline := center + Vector2(55, 72)
		draw_string_outline(SproutTheme.FONT_CN, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 58, 10, Color("#553824"))
		draw_string(SproutTheme.FONT_CN, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 58, SproutTheme.CREAM)
		index += 1

func _draw_fire() -> void:
	if _fire == null:
		return
	var factor := _design_scale() * POT_SCALE
	var offset := _design_offset() + POT_OFFSET * _design_scale()
	# 沿柴堆前缘错开火根；高低、倾斜和镜像共同打破重复贴图的轮廓。
	var flames := [
		[Vector2(443, 778), 162.0, 0.53, -0.28, false],
		[Vector2(536, 823), 229.0, 0.62, -0.18, true],
		[Vector2(654, 849), 154.0, 0.62, 0.19, false],
		[Vector2(755, 872), 271.0, 0.70, -0.08, true],
		[Vector2(866, 850), 138.0, 0.66, 0.23, false],
		[Vector2(992, 818), 221.0, 0.58, 0.22, false],
		[Vector2(1091, 775), 135.0, 0.50, 0.31, true],
	]
	for layer in range(3):
		var glow_alpha := 0.018 + layer * 0.007
		draw_set_transform(offset + Vector2(770, 807) * factor, 0.0, Vector2(1.0, 0.27) * factor)
		draw_circle(Vector2.ZERO, 375.0 - layer * 45.0, Color(1.0, 0.55, 0.16, glow_alpha))
	for index in range(flames.size()):
		var item: Array = flames[index]
		var phase := animation_time * (7.2 + index * 0.43) + index * 2.4
		var height := float(item[1]) * (1.0 + sin(phase) * 0.045)
		var width := height * float(item[2])
		var origin: Vector2 = item[0]
		var rotation := float(item[3]) + sin(phase * 0.7) * 0.025
		var mirror := -1.0 if bool(item[4]) else 1.0
		draw_set_transform(offset + origin * factor, rotation, Vector2(mirror, 1.0) * factor)
		draw_texture_rect(_fire, Rect2(-width * 0.5, -height, width, height), false, Color(1, 1, 1, 0.94 + sin(phase + 1.0) * 0.06))
	draw_set_transform(offset, 0.0, Vector2.ONE * factor)
	# 少量余烬只在炉火内侧上升，不进入判定色带。
	for index in range(3):
		var progress := fposmod(animation_time * 0.42 + index * 0.34, 1.0)
		var ember := Vector2(544 + index * 214 + sin(progress * 5.0 + index) * 19.0, 767 - progress * 137.0)
		draw_circle(ember, 3.5 - progress * 1.8, Color(1.0, 0.67, 0.25, sin(progress * PI) * 0.72))

func _draw_steam() -> void:
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array()
		var origin := Vector2(768 + side * 200, 285)
		for index in range(32):
			var height := float(index) / 31.0
			points.append(origin + Vector2(sin(height * 6.0 + animation_time * 2.0 + side) * 32.0, -height * 220.0))
		draw_polyline(points, Color(1.0, 0.88, 0.58, 0.18), 47.0, true)
		draw_polyline(points, Color(1.0, 0.94, 0.76, 0.3), 26.0, true)
