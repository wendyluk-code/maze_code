extends Node2D
## 世界空间的道具交互按钮：绑死在地图触发点坐标上（.tscn 的 position + ui_offset）
## 不做任何"世界→屏幕"逐帧换算；尺寸直接用原像素数值作为世界单位（无烘焙）。

const HEIGHT := 48.0
const KEY_X := 6.0
const KEY_SIZE := 30.0
const TEXT_GAP := 10.0
const PADDING_X := 18.0

var _text := "交互"
var _w := 140.0

var _font_cn: Font
var _font_key: Font
var _tex_btn: Texture2D
var _tex_key: Texture2D

func _init() -> void:
	_tex_btn = load("res://assets/ui/ui_big_play_blank.png") as Texture2D
	_tex_key = load("res://assets/ui/key_square26_frame0.png") as Texture2D
	_font_cn = load("res://assets/ui/zcool_kuail.ttf") as Font
	_font_key = load("res://assets/ui/sprout_lands.ttf") as Font

## 设置按钮文案与宽度（世界单位，即原像素数值）
func setup(text: String, width: float) -> void:
	_text = text
	_w = width
	queue_redraw()

func _draw() -> void:
	# 背景（米色九宫格按钮图）
	draw_texture_rect(_tex_btn, Rect2(0, 0, _w, HEIGHT), false)
	# 键帽底（垂直居中）
	var key_y := (HEIGHT - KEY_SIZE) * 0.5
	draw_texture_rect(_tex_key, Rect2(KEY_X, key_y, KEY_SIZE, KEY_SIZE), false)
	# E（键帽内居中）
	var e := "E"
	var e_size: Vector2 = _font_key.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, 14.0)
	var e_pos := Vector2(KEY_X + (KEY_SIZE - e_size.x) * 0.5, (HEIGHT + e_size.y) * 0.5 - 4.0)
	draw_string(_font_key, e_pos, e, HORIZONTAL_ALIGNMENT_LEFT, -1, 14.0, Color(0.16, 0.28, 0.15))
	# 文案（垂直居中）
	var ts: Vector2 = _font_cn.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15.0)
	draw_string(_font_cn, Vector2(KEY_X + KEY_SIZE + TEXT_GAP, (HEIGHT - ts.y) * 0.5 + ts.y - 2.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15.0, Color(0.4, 0.28, 0.16))

## 给出与文案匹配的按钮宽度（世界单位，即原像素数值）
static func desired_width(text: String) -> float:
	var font: Font = load("res://assets/ui/zcool_kuail.ttf") as Font
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15.0).x
	return maxf(140.0, 18.0 + 6.0 + 30.0 + 10.0 + tw)