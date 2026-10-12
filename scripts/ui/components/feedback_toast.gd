extends Label
## 餐厅与探索共用的顶部短暂提示；不锁输入、不改变业务状态。
var _remaining := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SproutTheme.make_theme()
	add_theme_color_override("font_color", SproutTheme.CREAM)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.03, 0.82)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("normal", style)
	hide()

static func attach_to(root: Control):
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 22
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var toast = load("res://scripts/ui/components/feedback_toast.gd").new()
	center.add_child(toast)
	return toast

func show_message(message: String, seconds: float = 3.5) -> void:
	text = message
	_remaining = seconds
	show()

func dismiss() -> void:
	_remaining = 0.0
	hide()

func _process(delta: float) -> void:
	_remaining = maxf(0, _remaining - delta)
	visible = _remaining > 0
