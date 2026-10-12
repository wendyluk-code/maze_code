extends Control
## 战斗角落信息：只显示头像、生命数值与水滴，不持有规则。
const PORTRAIT = preload("res://assets/characters/yaya_portrait.png")
const INK := Color("#345356")
const GOLD := Color("#d5ad5e")
var hp := -1
var points := -1
var active := false
var fill := [0.0, 0.0]
var hp_flash := 0.0
var fill_motion: Tween
var health_motion: Tween
var hp_label: Label

func _ready() -> void:
	size = Vector2(210, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(10, 18)
	portrait.size = Vector2(84, 84)
	portrait.name = "Avatar"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); c.a *= 1.0 - smoothstep(0.485, 0.5, length(UV - vec2(0.5))); COLOR = c; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	portrait.material = material
	add_child(portrait)
	# 生命徽章后加在头像之上，避免肖像遮住数字底色。
	var badge := Panel.new()
	badge.position = Vector2(62, 72)
	badge.size = Vector2(44, 44)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#954c4b")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	badge.add_theme_stylebox_override("panel", style)
	add_child(badge)
	hp_label = _label("", Rect2(62, 72, 44, 44), 26, Color("#fff5df"), true)

func _label(value: String, rect: Rect2, font_size: int, color: Color, centered := false) -> Label:
	var node := Label.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(node)
	return node

func sync(health: int, ap: int, current: bool) -> void:
	if hp != health and hp >= 0:
		if health_motion and health_motion.is_valid(): health_motion.kill()
		hp_flash = 1.0
		health_motion = create_tween()
		health_motion.tween_method(_set_flash, 1.0, 0.0, 0.4)
	hp = health
	hp_label.text = str(maxi(0, hp))
	active = current
	if points != ap:
		if fill_motion and fill_motion.is_valid(): fill_motion.kill()
		fill_motion = create_tween().set_parallel(true)
		for i in range(2):
			fill_motion.tween_method(_set_fill.bind(i), float(fill[i]), 1.0 if i < ap else 0.0, 0.22)
	points = ap
	queue_redraw()

func _set_fill(value: float, index: int) -> void:
	fill[index] = value
	queue_redraw()

func _set_flash(value: float) -> void:
	hp_flash = value
	queue_redraw()

func _draw() -> void:
	var center := Vector2(52, 60)
	if active: draw_circle(center, 53, Color(0.36,0.79,0.74,0.17))
	draw_circle(center, 48, Color("#29494d"))
	draw_arc(center, 49, 0, TAU, 96, GOLD if active else Color("#839b91"), 2, true)
	draw_arc(center, 45, 0, TAU, 96, Color("#e3c888"), 1, true)
	if hp_flash > 0:
		draw_arc(center, 51 + 5 * (1 - hp_flash), 0, TAU, 96, Color(0.86,0.59,0.43,hp_flash), 3, true)
	for i in range(2):
		var origin := Vector2(137 + i * 38, 50)
		var outline := PackedVector2Array()
		# 尖端向上，圆腹向下；由三段贝塞尔曲线组成真正的水滴轮廓。
		var top := Vector2(0,-21)
		var right := Vector2(13,5)
		var left := Vector2(-13,5)
		for j in range(13):
			var t := j / 12.0
			outline.append(origin + top.bezier_interpolate(Vector2(3,-10),Vector2(13,-5),right,t))
		for j in range(1,17):
			outline.append(origin + right.bezier_interpolate(Vector2(13,24),Vector2(-13,24),left,j/16.0))
		for j in range(1,13):
			outline.append(origin + left.bezier_interpolate(Vector2(-13,-5),Vector2(-3,-10),top,j/12.0))
		var lit := Color("#53cbbb") if active else Color("#8eaaa5")
		var empty := Color("#d3e2d9")
		draw_colored_polygon(outline, empty.lerp(lit, fill[i]))
		draw_polyline(outline, GOLD if active else Color("#829991"), 1.8, true)
		if fill[i] > 0.02:
			draw_arc(origin + Vector2(1,4), 8, 2.8, 4.2, 12, Color(0.93,1,0.96,fill[i]*0.85), 2, true)
