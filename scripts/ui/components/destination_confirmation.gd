extends ColorRect
## 场景通行的二次确认；调用方响应信号、关闭弹窗并恢复原输入状态。
signal confirmed
signal cancelled

var question: Label
var confirm_button: SproutButton
var cancel_button: SproutButton
var _armed := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	theme = SproutTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	question = Label.new()
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 24)
	column.add_child(question)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	cancel_button = SproutButton.new().configure("取消").set_icon_visible(false).set_focus_visual(false)
	confirm_button = SproutButton.new().configure("确认前往").set_icon_visible(false).set_focus_visual(false)
	buttons.add_child(cancel_button)
	buttons.add_child(confirm_button)
	cancel_button.pressed.connect(func(): cancelled.emit())
	confirm_button.pressed.connect(func(): confirmed.emit())
	hide()

func open_destination(destination: String) -> void:
	question.text = "是否前往%s？" % destination
	_armed = false
	show()
	cancel_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		_armed = true
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			cancelled.emit()
		KEY_E:
			if _armed:
				confirmed.emit()
		KEY_TAB, KEY_LEFT, KEY_RIGHT:
			if cancel_button.has_focus():
				confirm_button.grab_focus()
			else:
				cancel_button.grab_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if confirm_button.has_focus():
				confirmed.emit()
			else:
				cancelled.emit()
