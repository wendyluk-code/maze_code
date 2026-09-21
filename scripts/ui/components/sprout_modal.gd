class_name SproutModal
extends Control
## 局部通用弹窗：标题、内容、关闭、确认/取消与 Esc 关闭。

signal confirmed
signal cancelled
signal closed

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _confirm_button: SproutButton
var _cancel_button: SproutButton
var _close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.08, 0.12, 0.08, 0.48)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	_panel.custom_minimum_size = Vector2(500, 285)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-250, -142)
	_panel.size = Vector2(500, 285)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 38
	outer.add_child(heading)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_title_label)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.tooltip_text = "关闭弹窗"
	_close_button.custom_minimum_size = Vector2(42, 42)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.theme = SproutTheme.make_theme()
	_close_button.add_theme_font_size_override("font_size", 26)
	_close_button.pressed.connect(_on_close_pressed)
	heading.add_child(_close_button)

	_body_label = Label.new()
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(_body_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	outer.add_child(actions)
	_cancel_button = SproutButton.new()
	_cancel_button.configure("取消")
	_cancel_button.set_icon_visible(false)
	_cancel_button.set_focus_visual(false)
	_cancel_button.custom_minimum_size = Vector2(120, 48)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	actions.add_child(_cancel_button)
	_confirm_button = SproutButton.new()
	_confirm_button.configure("确认")
	_confirm_button.set_icon_visible(false)
	_confirm_button.set_focus_visual(false)
	_confirm_button.custom_minimum_size = Vector2(120, 48)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(_confirm_button)

func show_modal(title_text: String, body_text: String, confirm_text := "确认") -> void:
	_title_label.text = title_text
	_body_label.text = body_text
	_confirm_button.text = confirm_text
	visible = true
	_confirm_button.grab_focus()

func close_modal() -> void:
	if visible:
		visible = false
		closed.emit()

func _on_close_pressed() -> void:
	cancelled.emit()
	close_modal()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	close_modal()

func _on_confirm_pressed() -> void:
	confirmed.emit()
	close_modal()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_close_pressed()
