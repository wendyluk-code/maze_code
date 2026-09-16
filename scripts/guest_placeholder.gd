extends Node2D
## 铁山进场占位演出：饥肠辘辘的莽汉剪影 + 头顶"……"聊天气泡
## 素材到位后可整体替换为真正的角色精灵

var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	add_to_group("guest")
	_base_y = position.y

func _process(delta: float) -> void:
	_t += delta
	# 轻微前后晃动，表现"饿得站不稳"
	position.y = _base_y + sin(_t * 2.2) * 3.0

func _draw() -> void:
	# —— 剪影身体（占位：圆头 + 粗壮躯干 + 短腿）——
	var skin := Color(0.75, 0.58, 0.42)
	var cloth := Color(0.42, 0.34, 0.3)
	var dark := Color(0.3, 0.24, 0.22)
	# 头
	draw_circle(Vector2(0, -46), 13.0, skin)
	# 胡茬/腮（粗犷） 
	draw_rect(Rect2(-13, -40, 26, 5), Color(0.5, 0.4, 0.34))
	# 躯干
	draw_rect(Rect2(-15, -36, 30, 58), cloth)
	draw_circle(Vector2(0, 20), 15.0, cloth)
	# 手臂（垂着）
	draw_rect(Rect2(-20, -30, 6, 40), dark)
	draw_rect(Rect2(14, -30, 6, 40), dark)
	# 腿
	draw_rect(Rect2(-12, 22, 11, 22), dark)
	draw_rect(Rect2(2, 22, 11, 22), dark)
	# —— 头顶聊天气泡"……" ——
	var bo := Vector2(22, -74)
	var bubble_w := 34.0
	var line_w := 16.0
	# 尾巴 + 主体
	draw_circle(bo + Vector2(0, 0), 4.0, Color(1, 1, 1))
	draw_circle(bo + Vector2(8, 8), 3.0, Color(1, 1, 1))
	var rect := Rect2(bo.x, bo.y - 30, bubble_w, 34)
	draw_rect(rect, Color(1, 1, 1), false, 2.5)
	# 椭圆“…”省略号
	var f: Font = ThemeDB.fallback_font
	var dots := "…"
	var fs := 24.0
	var dw: float = f.get_string_size(dots, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dx := rect.position.x + (rect.size.x - dw) * 0.5
	draw_string(f, Vector2(dx, rect.position.y + 27), dots, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.3, 0.24, 0.2))