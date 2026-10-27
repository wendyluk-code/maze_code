extends Control
## 章末展示：暗幕、标题、说明、继续提示依次渐显。
signal continue_requested
const FONT_CN := preload("res://assets/ui/game_font.tres")
var _veil: ColorRect
var _titles: Control
var _title: Label
var _description: Label
var _prompt: HBoxContainer
var _error: Label
var _tween: Tween
var _generation := 0
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
	_titles.size = Vector2(760, 80)
	add_child(_titles)
	_title = _label("", 60)
	_title.add_theme_font_override("font", FONT_CN)
	_title.add_theme_constant_override("outline_size", 0)
	_title.add_theme_color_override("font_color", Color("e8ba62"))
	_title.position = Vector2(108, 0)
	_title.size = Vector2(544, 80)
	_titles.add_child(_title)
	_description = _label("", 26)
	_description.size = Vector2(760, 92)
	_description.add_theme_constant_override("line_spacing", 10)
	add_child(_description)
	_prompt = preload("res://scripts/ui/components/continue_prompt.gd").new()
	add_child(_prompt)
	for child in _prompt.get_children():
		if child is Label:
			child.add_theme_font_override("font", FONT_CN)
			child.add_theme_constant_override("outline_size", 0)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -84
	_prompt.offset_bottom = -40
	_error = _label("", 17)
	add_child(_error)
	_error.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_error.offset_top = -118
	_error.offset_bottom = -88
	resized.connect(_layout_titles)
	_layout_titles()
	hide()

func _layout_titles() -> void:
	if not is_instance_valid(_titles): return
	var factor := minf(1.0, (size.x - 48.0) / 760.0)
	_titles.scale = Vector2.ONE * factor
	_titles.position = Vector2((size.x - 760.0 * factor) * 0.5, size.y * 0.385 - 40.0 * factor)
	_description.scale = Vector2.ONE * factor
	_description.position = Vector2((size.x - 760.0 * factor) * 0.5, size.y * 0.475)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT_CN)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff4dc"))
	return label

func present(chapter_title: String, description := "") -> void:
	cancel()
	_title.text = chapter_title
	var font_size := 60
	while font_size > 28 and FONT_CN.get_string_size(chapter_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 544:
		font_size -= 1
	_title.add_theme_font_size_override("font_size", font_size)
	_description.text = description
	_error.text = ""
	_e_held = _e_held or Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E)
	_veil.modulate.a = 0
	_titles.modulate.a = 0
	_description.modulate.a = 0
	_prompt.modulate.a = 0
	modulate.a = 1
	show()
	var generation := _generation
	_tween = create_tween()
	_tween.tween_property(_veil, "modulate:a", 1.0, 0.65)
	_tween.tween_property(_titles, "modulate:a", 1.0, 0.6)
	_tween.tween_interval(0.2)
	_tween.tween_property(_description, "modulate:a", 1.0, 0.6)
	_tween.tween_interval(0.2)
	_tween.tween_property(_prompt, "modulate:a", 1.0, 0.4)
	_tween.tween_callback(func():
		if generation == _generation:
			_ready_for_input = true
			_armed = not _e_held)

func _input(event: InputEvent) -> void:
	if not visible:
		if event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E) and not event.echo:
			_e_held = event.pressed
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _ready_for_input:
			_armed = false
			continue_requested.emit()
		return
	if not event is InputEventKey or (event.keycode != KEY_E and event.physical_keycode != KEY_E): return
	if event.echo: return
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
	_stop_animation()
	var generation := _generation
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	# 不等待可能被kill的Tween信号；取消和重复dismiss均能结束旧协程。
	while generation == _generation and _tween.is_running():
		await get_tree().process_frame
	if generation == _generation: hide()

func _stop_animation() -> void:
	_generation += 1
	_ready_for_input = false
	_armed = false
	if is_instance_valid(_tween): _tween.kill()
	_tween = null

func cancel() -> void:
	_stop_animation()
	hide()
