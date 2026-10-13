extends Control
## 复用组件库按钮、齿轮图标与确认框；仅在菜单打开期间暂停战斗。
signal opened
signal action_confirmed(action: String)

const Action = preload("res://scripts/ui/components/sprout_button.gd")
const Modal = preload("res://scripts/ui/components/sprout_modal.gd")
const ThemeLibrary = preload("res://scripts/ui/components/sprout_theme.gd")
var gear: Button
var shield: ColorRect
var dropdown: PanelContainer
var restart_button: Button
var finish_button: Button
var confirmation: Control
var pending_action := ""
var accepted_action := ""
var is_open := false
var previous_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	shield = ColorRect.new()
	shield.size = size
	shield.color = Color(0, 0, 0, 0.12)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shield)
	shield.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: close_menu())
	shield.hide()
	gear = Action.new().configure("", 3).set_focus_visual(false)
	add_child(gear)
	gear.name = "BattleSettings"
	gear.tooltip_text = "战斗设置"
	gear.custom_minimum_size = Vector2.ZERO
	gear.position = Vector2(1212, 20)
	gear.size = Vector2(48, 48)
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.add_theme_constant_override("icon_max_width", 28)
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		gear.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	gear.add_theme_color_override("icon_hover_color", Color("#f5d993"))
	gear.add_theme_color_override("icon_pressed_color", Color("#d5ad5e"))
	# 与按钮使用同一个组件库图标；只画偏移阴影，不增加底框。
	var shadow := TextureRect.new()
	shadow.texture = ThemeLibrary.icon(3)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.position = Vector2(12, 13)
	shadow.size = Vector2(28, 28)
	shadow.modulate = Color(0.02, 0.06, 0.07, 0.8)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	gear.add_child(shadow)
	gear.pressed.connect(_toggle)
	dropdown = PanelContainer.new()
	dropdown.theme = ThemeLibrary.make_theme()
	dropdown.add_theme_stylebox_override("panel", ThemeLibrary.thin_panel_style())
	dropdown.position = Vector2(1030, 78)
	add_child(dropdown)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	dropdown.add_child(rows)
	restart_button = Action.new().configure("重开战斗").set_icon_visible(false).set_focus_visual(false)
	finish_button = Action.new().configure("结束战斗").set_icon_visible(false).set_focus_visual(false)
	rows.add_child(restart_button)
	rows.add_child(finish_button)
	restart_button.pressed.connect(_ask.bind("restart"))
	finish_button.pressed.connect(_ask.bind("finish"))
	dropdown.hide()
	confirmation = Modal.new()
	confirmation.z_index = 20
	add_child(confirmation)
	# 战斗确认窗的说明与操作组居中，保留公共弹窗默认布局。
	confirmation._body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation._body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var confirmation_actions := confirmation._cancel_button.get_parent() as HBoxContainer
	confirmation_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	confirmation.confirmed.connect(func(): accepted_action = pending_action)
	confirmation.closed.connect(_confirmation_closed)

func _toggle() -> void:
	if is_open:
		close_menu()
		return
	opened.emit()
	previous_pause = get_tree().paused
	is_open = true
	shield.show()
	dropdown.show()
	get_tree().paused = true
	restart_button.grab_focus()

func _ask(action: String) -> void:
	pending_action = action
	accepted_action = ""
	dropdown.hide()
	if action == "restart":
		confirmation.show_modal("重开战斗", "确定重新开始本场战斗吗？\n当前战斗进度将被清空。", "重开战斗")
	else:
		confirmation.show_modal("结束战斗", "确定结束本场战斗吗？\n本场将按失败结算，演出结束后按 E 返回上一级页面。", "结束战斗")
	confirmation._cancel_button.grab_focus()

func _confirmation_closed() -> void:
	var action := accepted_action
	accepted_action = ""
	pending_action = ""
	close_menu()
	if not action.is_empty(): action_confirmed.emit(action)

func close_menu() -> void:
	if confirmation.visible: return
	if not is_open: return
	is_open = false
	shield.hide()
	dropdown.hide()
	get_tree().paused = previous_pause
	gear.grab_focus()

func _exit_tree() -> void:
	if is_open: get_tree().paused = previous_pause

func _input(event: InputEvent) -> void:
	if not is_open or not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	if confirmation.visible:
		var buttons: Array[Control] = [confirmation._cancel_button, confirmation._confirm_button, confirmation._close_button]
		if event.keycode == KEY_ESCAPE:
			confirmation._on_cancel_pressed()
		elif event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var index := buttons.find(get_viewport().gui_get_focus_owner())
			buttons[posmod(index + (-1 if event.shift_pressed or event.keycode in [KEY_LEFT, KEY_UP] else 1), buttons.size())].grab_focus()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if confirmation._confirm_button.has_focus(): confirmation._on_confirm_pressed()
			else: confirmation._on_cancel_pressed()
	else:
		if event.keycode == KEY_ESCAPE: close_menu()
		elif event.keycode in [KEY_TAB, KEY_UP, KEY_DOWN]:
			(finish_button if restart_button.has_focus() else restart_button).grab_focus()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_ask("finish" if finish_button.has_focus() else "restart")
