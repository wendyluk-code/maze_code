extends Control
## 所有章节共用：蒙层渐显 → 中央章名与“完” → 新按E继续。
signal continue_requested

var _veil: ColorRect
var _titles: Control
var _title: Label
var _prompt: HBoxContainer
var _error: Label
var _tween: Tween
var _ready_for_input := false
var _armed := false
var _e_held := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SproutTheme.make_theme()
	_veil = ColorRect.new()
	_veil.color = Color(0.025, 0.035, 0.03, 0.9)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_titles = Control.new()
	_titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles.size = Vector2(700, 310)
	_titles.pivot_offset = _titles.size * 0.5
	add_child(_titles)
	var flourish := preload("res://scripts/ui/components/chapter_title_flourish.gd").new()
	flourish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_titles.add_child(flourish)
	_title = _label("", 52)
	_style_title(_title, 7)
	_titles.add_child(_title)
	_title.position = Vector2(72, 32)
	_title.size = Vector2(556, 76)
	var ending := _label("完", 86)
	_style_title(ending, 8)
	_titles.add_child(ending)
	ending.position = Vector2(285, 159)
	ending.size = Vector2(130, 115)
	resized.connect(_layout_titles)
	_layout_titles()
	_prompt = preload("res://scripts/ui/components/continue_prompt.gd").new()
	add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -84
	_prompt.offset_bottom = -40
	_error = _label("", 17)
	add_child(_error)
	_error.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_error.offset_top = -118
	_error.offset_bottom = -88
	hide()

func _style_title(label: Label, outline: int) -> void:
	label.add_theme_color_override("font_color", Color("475b34"))
	label.add_theme_color_override("font_outline_color", Color("fff3da"))
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.10, 0.05, 0.8))
	label.add_theme_constant_override("shadow_outline_size", 5)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _layout_titles() -> void:
	if not is_instance_valid(_titles):
		return
	var factor := minf(1.0, minf((size.x - 48.0) / 700.0, (size.y - 200.0) / 310.0))
	_titles.scale = Vector2.ONE * maxf(0.3, factor)
	_titles.position = size * 0.5 - _titles.size * 0.5 - Vector2(0, 12)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SproutTheme.CREAM)
	return label

func present(chapter_title: String) -> void:
	cancel()
	_title.text = chapter_title
	# 章名仍为原生文字，后续长标题自动缩小，不把字嵌入图片。
	var font := _title.get_theme_font("font")
	var font_size := 52
	while font_size > 28 and font.get_string_size(chapter_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 552:
		font_size -= 1
	_title.add_theme_font_size_override("font_size", font_size)
	_error.text = ""
	_e_held = _e_held or Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E)
	_armed = false
	_veil.modulate.a = 0
	_titles.modulate.a = 0
	_prompt.modulate.a = 0
	modulate.a = 1
	show()
	_tween = create_tween()
	_tween.tween_property(_veil, "modulate:a", 1.0, 0.65)
	_tween.tween_property(_titles, "modulate:a", 1.0, 0.45)
	_tween.tween_property(_prompt, "modulate:a", 1.0, 0.2)
	_tween.tween_callback(func():
		_ready_for_input = true
		_armed = not _e_held)

func _input(event: InputEvent) -> void:
	if not visible:
		# 记录进入蒙层之前的E，避免跨对白/镜头阶段长按穿透。
		if event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E) and not event.echo:
			_e_held = event.pressed
		return
	# 蒙层期间所有键鼠事件在此消费，关闭的E不能传给地图。
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _ready_for_input:
			_armed = false
			continue_requested.emit()
		return
	if not event is InputEventKey or (event.keycode != KEY_E and event.physical_keycode != KEY_E):
		return
	if event.echo:
		return
	if not event.pressed:
		_e_held = false
		_armed = _ready_for_input
		return
	var was_held := _e_held
	_e_held = true
	if _ready_for_input and _armed and not was_held:
		_armed = false
		continue_requested.emit()

func show_error(message: String) -> void:
	_error.text = message

func dismiss() -> void:
	_ready_for_input = false
	_armed = false
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await _tween.finished
	hide()

func cancel() -> void:
	_ready_for_input = false
	_armed = false
	if is_instance_valid(_tween):
		_tween.kill()
	hide()
