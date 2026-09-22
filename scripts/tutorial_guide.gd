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
@onready var chapter_title: Label = %ChapterTitle
@onready var chapter_stage: Label = %ChapterStage

var _target_world := Vector2.ZERO
var _target_node: Node2D = null
var _has_target := false
var _toast_tween: Tween = null
var _finish_tween: Tween = null
var _visual_token := 0
var _modal_suppressed := false
var _modal_hint_visible := false
var _modal_marker_visible := false

func _ready() -> void:
	add_to_group("tutorial_guide")
	if not skip_button.pressed.is_connected(_on_skip):
		skip_button.pressed.connect(_on_skip)
	if not dialog.finished.is_connected(_on_dialog_finished):
		dialog.finished.connect(_on_dialog_finished)
	# 只有正式餐厅入口负责自动启动。测试或其他场景临时实例化地图时，
	# 不抢占 TutorialManager，避免产生第二条异步教程流程。
	if get_tree().current_scene != _scene_root():
		visible = false
		return
	# 已完成第一章：直接隐藏整个引导层，不干扰正常游戏；开发重播参数例外
	if not should_start_chapter_1():
		visible = false
		return
	prepare_for_start()
	# 首次进入游戏自动开始新手教学
	TutorialManager.start()

func _scene_root() -> Node:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node

func should_start_chapter_1() -> bool:
	var replay := TutorialManager.has_method("is_replay_requested") and TutorialManager.is_replay_requested()
	if replay:
		return true
	return not SaveManager.has_method("is_chapter_1_done") or not SaveManager.is_chapter_1_done()

func prepare_for_start() -> void:
	_visual_token += 1
	if _finish_tween != null and _finish_tween.is_valid():
		_finish_tween.kill()
	_finish_tween = null
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	visible = true
	dim.visible = true
	dim.color.a = 0.5
	marker.visible = false
	hint_panel.visible = false
	toast.visible = false
	skip_button.visible = true
	chapter_title.text = "第一章：醒来与首单教程"
	chapter_title.visible = true
	chapter_stage.visible = true
	chapter_stage.text = "阶段 1/7 · 苏醒与失忆"
	dialog.hide_box()

func _on_skip() -> void:
	TutorialManager.skip_all()
	get_viewport().set_input_as_handled()

## 过场期间调整暗幕透明度（0=全亮，0.5=常规），保持画面观察
func set_dim(alpha: float) -> void:
	dim.color.a = clampf(alpha, 0.0, 1.0)

func set_modal_suppressed(value: bool) -> void:
	if value == _modal_suppressed:
		return
	_modal_suppressed = value
	if value:
		_modal_hint_visible = hint_panel.visible
		_modal_marker_visible = marker.visible
		hint_panel.visible = false
		marker.visible = false
	else:
		hint_panel.visible = _modal_hint_visible
		marker.visible = _modal_marker_visible

func setup(step: Dictionary) -> void:
	# 底部提示
	var hint := str(step.get("hint", ""))
	hint_panel.visible = not hint.is_empty()
	hint_label.text = hint
	# 高亮目标
	var target = step.get("target")
	_target_world = Vector2.ZERO
	_target_node = null
	_has_target = false
	if target != null:
		var node: Node2D = TutorialManager.resolve_target(target)
		if node:
			_target_node = node
			_target_world = node.global_position
			_has_target = true
		elif target is Vector2:
			_target_world = target
			_has_target = true
	marker.visible = _has_target

func set_chapter_stage(stage: int, title: String) -> void:
	if stage <= 0:
		return
	chapter_stage.text = "阶段 %d/7 · %s" % [stage, title]

func _process(_delta: float) -> void:
	if not marker.visible or not _has_target:
		return
	if is_instance_valid(_target_node):
		_target_world = _target_node.global_position
	# Canvas transform 包含相机缩放、位置和 limit 裁剪，避免地图边缘手算漂移
	var screen_position := get_viewport().get_canvas_transform() * _target_world
	marker.position = Vector2(
		roundi(screen_position.x - marker.size.x * 0.5),
		roundi(screen_position.y - marker.size.y)
	)

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
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)

func finish_all() -> void:
	_visual_token += 1
	var token := _visual_token
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	marker.visible = false
	_has_target = false
	_target_node = null
	hint_panel.visible = false
	dialog.hide_box()
	toast.visible = false
	skip_button.visible = false
	chapter_title.visible = false
	chapter_stage.visible = false
	_finish_tween = create_tween()
	_finish_tween.tween_property(dim, "color:a", 0.0, 0.5)
	await _finish_tween.finished
	_finish_tween = null
	if token != _visual_token:
		return
	dim.visible = false
	visible = false
