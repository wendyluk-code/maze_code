extends Control
## 料理已保存后的独立结果展示；玩家确认后才返回场景。
signal confirmed
const RATING_STARS := preload("res://scripts/ui/cooking_rating_stars.gd")
var _panel: PanelContainer
var _icon: TextureRect
var _dish_name: Label
var _stars: Control
var _confirm_button: Button
var _tween: Tween
var _ready_for_input := false
var _e_held := false
var quality := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SproutTheme.make_theme()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(SproutTheme.CREAM))
	center.add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	_panel.add_child(rows)
	rows.add_child(_label("烹饪完成", 26, Color("#426044")))
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(156, 128)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rows.add_child(_icon)
	_dish_name = _label("", 26, SproutTheme.INK)
	rows.add_child(_dish_name)
	_stars = RATING_STARS.new()
	rows.add_child(_stars)
	_confirm_button = Button.new()
	_confirm_button.text = "确认"
	_confirm_button.custom_minimum_size = Vector2(224, 48)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.pressed.connect(_confirm)
	rows.add_child(_confirm_button)
	hide()

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func present(dish_name: String, icon: Texture2D, stars: int) -> void:
	cancel()
	quality = clampi(stars, 1, 3)
	_dish_name.text = dish_name
	_icon.texture = icon
	_stars.present(quality)
	_e_held = _e_held or Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E)
	_confirm_button.disabled = true
	modulate.a = 0.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.tween_callback(func():
		_ready_for_input = true
		_confirm_button.disabled = false)

func _input(event: InputEvent) -> void:
	var is_e: bool = event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E)
	var held_before := _e_held
	if is_e and not event.echo:
		_e_held = event.pressed
	if not visible or not event is InputEventKey:
		return
	# 空格只负责结束QTE；结果只由按钮或新的E确认，且不能穿透场景。
	get_viewport().set_input_as_handled()
	if is_e and event.pressed and not event.echo and not held_before:
		_confirm()

func _confirm() -> void:
	if not visible or not _ready_for_input:
		return
	_ready_for_input = false
	_confirm_button.disabled = true
	confirmed.emit()

func cancel() -> void:
	_ready_for_input = false
	if is_instance_valid(_stars):
		_stars.stop()
	if is_instance_valid(_tween):
		_tween.kill()
	hide()
