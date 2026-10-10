extends Control
## 所有章节共用：蒙层渐显 → 中央章名与“完” → 新按E继续。
signal continue_requested

var _veil: ColorRect
var _titles: VBoxContainer
var _title: Label
var _prompt: Label
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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_titles = VBoxContainer.new()
	_titles.add_theme_constant_override("separation", 28)
	center.add_child(_titles)
	_title = _label("", 38)
	_titles.add_child(_title)
	_titles.add_child(_label("完", 64))
	_prompt = _label("按 E 继续", 23)
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
