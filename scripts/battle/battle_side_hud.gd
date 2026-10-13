extends Control
## 战斗角落信息：透明水彩头像框、生命徽章和瓷勺行动点，只显示规则状态。
const PORTRAIT = preload("res://assets/characters/yaya_portrait.png")
const AVATAR_FRAME = preload("res://assets/ui/battle/side_hud/avatar_frame_v1.png")
const HEALTH_BADGE = preload("res://assets/ui/battle/side_hud/health_badge_v1.png")
const SPOON_READY = preload("res://assets/ui/battle/side_hud/spoon_ready_v1.png")
const SPOON_SPENT = preload("res://assets/ui/battle/side_hud/spoon_spent_v1.png")
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
var ready_spoons: Array[TextureRect] = []
var health_badge: TextureRect

func _ready() -> void:
	size = Vector2(210, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(13, 18)
	portrait.size = Vector2(82, 82)
	portrait.name = "Avatar"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); c.a *= 1.0 - smoothstep(0.485, 0.5, length(UV - vec2(0.5))); COLOR = c; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	portrait.material = material
	add_child(portrait)
	_texture("AvatarFrame", AVATAR_FRAME, Rect2(-11, 4, 126, 111))
	# 徽章与数字独立，受伤、治疗及失败结算继续使用实时生命值。
	health_badge = _texture("HealthBadge", HEALTH_BADGE, Rect2(61, 71, 49, 49))
	hp_label = _label("", Rect2(63, 73, 45, 45), 26, Color("#fff5df"), true)
	for i in range(2):
		var rect := Rect2(124 + i * 40, 29, 35, 47)
		_texture("SpoonSpent%d" % i, SPOON_SPENT, rect)
		var ready := _texture("SpoonReady%d" % i, SPOON_READY, rect)
		ready.modulate.a = fill[i]
		ready_spoons.append(ready)

func _texture(node_name: String, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

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
	ready_spoons[index].modulate.a = value

func _set_flash(value: float) -> void:
	hp_flash = value
	health_badge.modulate = Color.WHITE.lerp(Color("#ffb7a2"), value * 0.45)
	queue_redraw()

func _draw() -> void:
	# 深色头像底保留在透明框下方，现有头像始终由场景提供。
	draw_circle(Vector2(54, 59), 43, Color("#29494d"))
