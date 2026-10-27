extends ColorRect
## 统一二次确认；调用方响应信号、关闭弹窗并恢复原输入状态。
signal confirmed
signal cancelled
signal secondary_selected

var question: Label
var confirm_button: SproutButton
var cancel_button: SproutButton
var _secondary_action := false
var _armed := false
var _exploration := false
var _cost_row: HBoxContainer
var _insufficient: Label

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
	_cost_row = HBoxContainer.new()
	_cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cost_row)
	var prefix := Label.new()
	prefix.text = "本次探索将消耗"
	_cost_row.add_child(prefix)
	var cost := preload("res://scripts/ui/components/resource_counter.gd").new()
	cost.configure(preload("res://assets/ui/hud_currency/stamina_rice.png"))
	cost.set_value(20)
	_cost_row.add_child(cost)
	var suffix := Label.new()
	suffix.text = "，是否确认前往？"
	_cost_row.add_child(suffix)
	_insufficient = Label.new()
	_insufficient.text = "体力不足"
	_insufficient.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_insufficient)
	_cost_row.hide()
	_insufficient.hide()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	cancel_button = SproutButton.new().configure("取消").set_icon_visible(false).set_focus_visual(false)
	confirm_button = SproutButton.new().configure("确认前往").set_icon_visible(false).set_focus_visual(false)
	buttons.add_child(cancel_button)
	buttons.add_child(confirm_button)
	cancel_button.pressed.connect(_select_secondary)
	confirm_button.pressed.connect(func(): confirmed.emit())
	hide()

func open_destination(destination: String) -> void:
	open_confirmation("是否前往%s？" % destination, "确认前往", "取消")

func open_confirmation(message: String, confirm_text := "确认", cancel_text := "取消") -> void:
	_secondary_action = false
	_exploration = false
	_cost_row.hide()
	_insufficient.hide()
	question.show()
	confirm_button.disabled = false
	question.text = message
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	_armed = false
	show()
	cancel_button.grab_focus()

func open_choice(message: String, confirm_text: String, secondary_text: String) -> void:
	open_confirmation(message, confirm_text, secondary_text)
	_secondary_action = true

func open_region_choice(region_name: String) -> void:
	open_choice("是否前往%s？" % region_name, "前往", "结束探索")

func _select_secondary() -> void:
	if _secondary_action:
		secondary_selected.emit()
	else:
		cancelled.emit()

func open_exploration() -> void:
	open_confirmation("", "是", "否")
	_exploration = true
	question.hide()
	_cost_row.show()
	_process(0)

func _process(_delta: float) -> void:
	if visible and _exploration:
		confirm_button.disabled = SaveManager.stamina() < SaveManager.STAMINA_COST
		_insufficient.visible = confirm_button.disabled

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
			if _armed and not confirm_button.disabled:
				confirmed.emit()
		KEY_TAB, KEY_LEFT, KEY_RIGHT:
			if cancel_button.has_focus():
				confirm_button.grab_focus()
			else:
				cancel_button.grab_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if confirm_button.has_focus() and not confirm_button.disabled:
				confirmed.emit()
			else:
				_select_secondary()
