extends Control
## 文字对话框：立绘 + 说话人名字 + 打字机文本；点击 / 空格 / Enter / E 推进

signal finished

@onready var speaker_name: Label = %SpeakerName
@onready var dialog_text: Label = %DialogText
@onready var next_icon = %NextIcon
@onready var portrait: Control = %Portrait
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var portrait_fallback: Label = %PortraitFallback

const CHARS_PER_SEC := 30.0

var _lines: Array = []
var _line_idx := 0
var _shown := 0.0

func start(speaker: String, lines: Array, ptex: Texture2D = null) -> void:
	visible = true
	_lines = lines.duplicate()
	_line_idx = 0
	_shown = 0.0
	dialog_text.text = ""
	next_icon.visible = false
	speaker_name.text = speaker
	if ptex != null:
		portrait_texture.texture = ptex
		portrait_texture.visible = true
		portrait_fallback.visible = false
	else:
		portrait_texture.visible = false
		portrait_fallback.visible = true
		portrait_fallback.text = speaker.substr(0, 1) if not speaker.is_empty() else "?"

func _process(delta: float) -> void:
	if not visible or _lines.is_empty() or _line_idx >= _lines.size():
		return
	var full: String = _lines[_line_idx]
	if _shown < full.length():
		# 限制单帧时长，避免后台掉帧时整句瞬出；按固定速率逐字显示
		_shown = minf(full.length(), _shown + CHARS_PER_SEC * minf(delta, 0.1))
		dialog_text.text = full.substr(0, int(_shown))
		next_icon.visible = false
	else:
		next_icon.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _lines.is_empty() or _line_idx >= _lines.size():
		return
	var advance := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance = true
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	_advance()

func _advance() -> void:
	if _line_idx >= _lines.size():
		visible = false
		return
	var full: String = _lines[_line_idx]
	if _shown < full.length():
		_shown = full.length()
		dialog_text.text = full
		return
	_line_idx += 1
	if _line_idx < _lines.size():
		_shown = 0.0
		dialog_text.text = ""
		next_icon.visible = false
	else:
		visible = false
		finished.emit()

func hide_box() -> void:
	visible = false
