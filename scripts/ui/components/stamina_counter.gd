extends HBoxContainer
## 餐厅与迷宫共用体力显示；时间及消耗由 SaveManager 负责。
const Counter := preload("res://scripts/ui/components/resource_counter.gd")
const ICON := preload("res://assets/ui/hud_currency/stamina_rice.png")
var counter: HBoxContainer
var info: TextureRect

var hint_panel: PanelContainer

func _ready() -> void:
	name = "StaminaCounter"
	add_to_group("stamina_counter")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -190
	offset_right = -16
	offset_top = 16
	offset_bottom = 52
	add_theme_constant_override("separation", 8)
	counter = Counter.new()
	counter.configure(ICON)
	add_child(counter)
	info = TextureRect.new()
	info.texture = preload("res://assets/ui/hud_currency/stamina_info.svg")
	info.custom_minimum_size = Vector2(18, 18)
	info.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(info)
	_build_hint()
	info.mouse_entered.connect(func(): hint_panel.visible = is_visible_in_tree())
	info.mouse_exited.connect(func(): hint_panel.hide())
	_process(0)

func _build_hint() -> void:
	# 固定对齐图标，避免原生工具提示随鼠标位置覆盖数字。
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hint_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.25, 0.78)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hint_panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.theme = SproutTheme.make_theme()
	label.add_theme_color_override("font_color", SproutTheme.CREAM)
	label.text = "每5分钟恢复1点"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(label)
	hint_panel.hide()

func _process(_delta: float) -> void:
	visible = SaveManager.is_chapter_1_complete() and SaveManager.chapter_1_outro_state() == "done"
	if not visible:
		hint_panel.hide()
		return
	counter.value_label.text = "%d/100" % SaveManager.stamina()
	hint_panel.size = hint_panel.get_combined_minimum_size()
	hint_panel.global_position = Vector2(info.get_global_rect().end.x - hint_panel.size.x, get_global_rect().end.y + 8)
