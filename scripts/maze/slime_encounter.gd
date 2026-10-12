extends Node2D
## 四方向原地爬行帧；沿旧城长廊中心线往返，不改地图和道路碰撞。
const ATLAS := preload("res://assets/monsters/slime/slime_crawl_4directions.png")
const CENTER := preload("res://data/maze/entry_roads.gd").MONSTER
const START := Vector2(953, 255)
const END := Vector2(914, 276)
var elapsed := 0.0
var body: Sprite2D

func _ready() -> void:
	position = CENTER
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/characters/tieshan/ground_shadow.png")
	shadow.scale = Vector2(0.34, 0.22)
	add_child(shadow)
	body = Sprite2D.new()
	body.texture = ATLAS
	body.hframes = 4
	body.vframes = 4
	body.centered = false
	body.offset = Vector2(-128, -214)
	body.scale = Vector2.ONE * 0.24
	add_child(body)
	var label := Label.new()
	label.text = "史莱姆"
	label.position = Vector2(-28, -64)
	label.add_theme_font_override("font", SproutTheme.FONT_CN)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SproutTheme.CREAM)
	label.add_theme_color_override("font_outline_color", SproutTheme.INK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)

func _process(delta: float) -> void:
	elapsed += delta
	var phase := fmod(elapsed, 5.6) / 2.8
	position = START.lerp(END, phase if phase < 1 else 2 - phase)
	# 西南 / 东北，与路径斜向一致。
	body.frame = (4 if phase < 1 else 8) + int(elapsed / 0.14) % 4
