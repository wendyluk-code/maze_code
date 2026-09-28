extends Control
## 确认版原图与按钮共用同一个等比坐标系，窗口变化时热区不漂移。

const COVER := preload("res://assets/ui/start_screen/cover.png")
const SAVE_MODAL := preload("res://scripts/ui/save_selection_modal.gd")
const PROLOGUE := "res://scenes/prologue.tscn"
const ART_SIZE := Vector2(1672, 941)

var art: Control
var new_button: Button
var continue_button: Button
var save_modal: SproutModal
var _error_modal: SproutModal
var _busy := false
var _game_prepared := false

func _ready() -> void:
	add_to_group("start_screen")
	var background := ColorRect.new()
	background.color = Color("#f7f4e8")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	art = Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var picture := TextureRect.new()
	picture.texture = COVER
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.size = ART_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(picture)
	new_button = _hotspot("新游戏", Rect2(109, 579, 325, 70))
	continue_button = _hotspot("继续游戏", Rect2(109, 665, 325, 70))
	new_button.pressed.connect(_new_game)
	continue_button.pressed.connect(_continue_game)
	save_modal = SAVE_MODAL.new()
	add_child(save_modal)
	save_modal.slot_requested.connect(_load_game)
	save_modal.closed.connect(_modal_closed)
	_error_modal = SproutModal.new()
	add_child(_error_modal)
	_error_modal.closed.connect(_modal_closed)
	resized.connect(_layout)
	_layout()
	# 开发序章重播继续使用既有整次进程隔离规则。
	if SaveManager.is_prologue_preview():
		_enter_game.call_deferred()

func _layout() -> void:
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	art.scale = Vector2.ONE * factor
	art.size = ART_SIZE
	art.position = (size - ART_SIZE * factor) * 0.5
	if is_instance_valid(_error_modal):
		_error_modal._panel.position = (size - _error_modal._panel.size) * 0.5

func _hotspot(label: String, rectangle: Rect2) -> Button:
	var button := Button.new()
	button.name = "NewGame" if label == "新游戏" else "ContinueGame"
	button.tooltip_text = label
	button.position = rectangle.position
	button.size = rectangle.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _feedback(Color(1, 1, 1, 0.16)))
	button.add_theme_stylebox_override("pressed", _feedback(Color(0.2, 0.28, 0.14, 0.23)))
	var focus := _feedback(Color.TRANSPARENT)
	focus.set_border_width_all(3)
	focus.border_color = Color("#50653b")
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	button.add_theme_stylebox_override("focus", focus)
	art.add_child(button)
	return button

func _feedback(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(22)
	return style

func _set_buttons_disabled(value: bool) -> void:
	new_button.disabled = value
	continue_button.disabled = value

func _new_game() -> void:
	if _busy or save_modal.visible or _error_modal.visible:
		return
	_busy = true
	_set_buttons_disabled(true)
	# 转场失败后重试沿用刚创建的档，不重复创建空档。
	var result: Dictionary = {"success": true} if _game_prepared else SaveManager.create_new_game()
	if not result.success:
		_show_error(result.message)
		return
	_game_prepared = true
	_enter_game()

func _continue_game() -> void:
	if _busy or save_modal.visible or _error_modal.visible:
		return
	_game_prepared = false
	_set_buttons_disabled(true)
	save_modal.open_slots()

func _load_game(path: String) -> void:
	if _busy:
		return
	_busy = true
	save_modal.set_busy(true)
	var result := SaveManager.load_save_slot(path)
	if not result.success:
		_busy = false
		save_modal.show_problem(result.message)
		return
	_game_prepared = true
	save_modal.close_modal()
	_enter_game()

func _enter_game() -> void:
	_busy = true
	_set_buttons_disabled(true)
	var error := get_tree().change_scene_to_file(PROLOGUE)
	if error != OK:
		_show_error("序章加载失败，已保留存档，请重试。错误：" + str(error))

func _show_error(message: String) -> void:
	_busy = false
	_error_modal.show_modal("暂时无法进入游戏", message, "知道了")
	_error_modal._cancel_button.hide()

func _modal_closed() -> void:
	if not _busy:
		_set_buttons_disabled(false)
		continue_button.grab_focus()
