extends Control
## 教程引导层（放到 CanvasLayer 下，全屏覆盖）
## 组成：暗幕 + 目标高亮 + 底部提示 + 跳过按钮 + 对话框 + Toast

signal dialog_done

@onready var dim: ColorRect = %Dim
@onready var marker: Control = %TargetMarker
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var skip_button: Button = %SkipButton
@onready var dialog = %DialogBox
@onready var toast: Label = %Toast

var _target_world := Vector2.ZERO
var _toast_tween: Tween = null

func _ready() -> void:
	add_to_group("tutorial_guide")
	# 已完成教学：直接隐藏整个引导层，不干扰正常游戏
	if SaveManager.is_tutorial_done():
		visible = false
		return
	dim.visible = true
	marker.visible = false
	hint_panel.visible = false
	toast.visible = false
	dialog.hide_box()
	skip_button.pressed.connect(_on_skip)
	if not dialog.finished.is_connected(_on_dialog_finished):
		dialog.finished.connect(_on_dialog_finished)
	# 首次进入游戏自动开始新手教学
	TutorialManager.start()

func _on_skip() -> void:
	TutorialManager.skip_all()

## 过场期间调整暗幕透明度（0=全亮，0.5=常规），保持画面观察
func set_dim(alpha: float) -> void:
	dim.color.a = clampf(alpha, 0.0, 1.0)

func setup(step: Dictionary) -> void:
	# 底部提示
	var hint := str(step.get("hint", ""))
	hint_panel.visible = not hint.is_empty()
	hint_label.text = hint
	# 高亮目标
	var target = step.get("target")
	_target_world = Vector2.ZERO
	if target != null:
		var node: Node2D = TutorialManager.resolve_target(target)
		if node:
			_target_world = node.global_position
		elif target is Vector2:
			_target_world = target
	marker.visible = _target_world != Vector2.ZERO

func _process(_delta: float) -> void:
	if not marker.visible or _target_world == Vector2.ZERO:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var rel := (_target_world - cam.global_position) * cam.zoom
	var sp := rel + get_viewport().get_visible_rect().size * 0.5
	# 标记底部中心对准目标
	marker.position = Vector2(roundi(sp.x) - marker.size.x * 0.5, roundi(sp.y) - marker.size.y)

func play_dialog(speaker: String, lines: Array, ptex: Texture2D = null) -> void:
	dialog.visible = true
	dialog.start(speaker, lines, ptex)

func hide_box() -> void:
	if dialog:
		dialog.hide_box()

func _on_dialog_finished() -> void:
	dialog_done.emit()

func show_toast(text: String) -> void:
	toast.modulate.a = 1.0
	toast.text = text
	toast.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)

func finish_all() -> void:
	marker.visible = false
	hint_panel.visible = false
	dialog.hide_box()
	toast.visible = false
	skip_button.visible = false
	var t := create_tween()
	t.tween_property(dim, "color:a", 0.0, 0.5)
	await t.finished
	dim.visible = false
	visible = false
