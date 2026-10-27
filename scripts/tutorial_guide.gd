extends Control
## 教程引导层（放到 CanvasLayer 下，全屏覆盖）
## 组成：对白暗幕 + 顶部操作提示 + 对话框 + Toast

const HINT_TOP := 16.0
const TASK_CUTOUT := preload("res://scripts/ui/tutorial_task_cutout.gdshader")
const DIALOG_DIM_ALPHA := 0.72

signal dialog_done

@onready var dim: ColorRect = %Dim
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var skip_button: Button = %SkipButton
@onready var dialog = %DialogBox
@onready var toast: Label = %Toast
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var chapter_title: Label = %ChapterTitle
@onready var chapter_stage: Label = %ChapterStage

var external_cutouts: Array[Rect2] = []
var external_operation := false
var external_circles := false
var external_owner := false

var _toast_tween: Tween = null
var _modal_suppressed := false
var _modal_hint_visible := false

func _ready() -> void:
	add_to_group("tutorial_guide")
	var cutout := ShaderMaterial.new()
	cutout.shader = TASK_CUTOUT
	dim.material = cutout
	dim.gui_input.connect(_on_dim_gui_input)
	if not dialog.finished.is_connected(_on_dialog_finished):
		dialog.finished.connect(_on_dialog_finished)
	# 只有正式餐厅入口负责自动启动。测试或其他场景临时实例化地图时，
	# 不抢占 TutorialManager，避免产生第二条异步教程流程。
	if external_owner or get_tree().current_scene != _scene_root():
		finish_all()
		return
	# 已完成第一章：直接隐藏整个引导层，不干扰正常游戏；开发重播参数例外
	if not should_start_chapter_1():
		finish_all()
		return
	prepare_for_start()
	# 首次进入游戏自动开始新手教学
	TutorialManager.start()

func _on_dim_gui_input(event: InputEvent) -> void:
	# 暗幕拦住任务栏等背景控件，仍保留点击任意位置继续对白的操作。
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dialog._gui_input(event)

func _scene_root() -> Node:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node

func should_start_chapter_1() -> bool:
	var replay := TutorialManager.has_method("is_replay_requested") and TutorialManager.is_replay_requested()
	if replay:
		return true
	if SaveManager.has_pending_chapter_1_outro():
		return true
	if SaveManager.is_ready_to_depart():
		return false
	return not SaveManager.has_method("is_chapter_1_done") or not SaveManager.is_chapter_1_done()

func prepare_for_start() -> void:
	_modal_suppressed = false
	_modal_hint_visible = false
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	visible = true
	dim.visible = false
	dim.color = Color(0.08, 0.06, 0.04, DIALOG_DIM_ALPHA)
	hint_panel.visible = false
	_hide_toast()
	skip_button.visible = false
	chapter_title.text = "第一章：醒来与首单教程"
	chapter_title.visible = false
	chapter_stage.visible = false
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
		hint_panel.visible = false
	else:
		hint_panel.visible = _modal_hint_visible
	_sync_dialog_mask()

func setup(step: Dictionary) -> void:
	# 操作提示置顶居中，章节与阶段信息仅供内部流程记录。
	var hint := str(step.get("hint", ""))
	hint_panel.visible = not hint.is_empty()
	hint_label.text = hint
	_position_hint_panel()
	_position_toast()
	_sync_dialog_mask()

func set_chapter_stage(stage: int, title: String) -> void:
	if stage <= 0:
		return
	chapter_stage.text = "阶段 %d/7 · %s" % [stage, title]

func _process(_delta: float) -> void:
	_sync_dialog_mask()
	_position_hint_panel()
	_position_toast()
	_position_skip_button()

func _position_toast() -> void:
	if not toast.visible:
		return
	var box_size := _compact_hint_size(toast, 64.0)
	toast_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast_panel.size = box_size
	toast_panel.position = Vector2((get_viewport_rect().size.x - toast_panel.size.x) * 0.5,
		hint_panel.get_rect().end.y + 8.0 if hint_panel.visible else HINT_TOP)

func _position_hint_panel() -> void:
	if not hint_panel.visible:
		return
	var box_size := _compact_hint_size(hint_label)
	hint_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint_panel.size = box_size
	hint_panel.position = Vector2((get_viewport_rect().size.x - box_size.x) * 0.5, HINT_TOP)

func _compact_hint_size(label: Label, horizontal_padding := 40.0) -> Vector2:
	var viewport_width := get_viewport_rect().size.x
	var max_width := minf(640.0, viewport_width - 48.0)
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("expanded_panel_rect"):
		var task_rect: Rect2 = tracker.expanded_panel_rect()
		if task_rect.has_area():
			var center_x := viewport_width * 0.5
			var available_half := task_rect.position.x - center_x if task_rect.get_center().x >= center_x else center_x - task_rect.end.x
			max_width = minf(max_width, maxf(120.0, (available_half - 16.0) * 2.0))
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var natural_width := 0.0
	for line in label.text.split("\n"):
		natural_width = maxf(natural_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var width := minf(max_width, ceilf(natural_width) + horizontal_padding)
	var text_size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width - horizontal_padding, font_size)
	return Vector2(width, ceilf(text_size.y) + 20.0)

func _position_skip_button() -> void:
	var viewport_width := get_viewport_rect().size.x
	var left := viewport_width - 134.0
	skip_button.anchor_left = 0.0
	skip_button.anchor_right = 0.0
	skip_button.anchor_top = 0.0
	skip_button.anchor_bottom = 0.0
	skip_button.offset_left = left
	skip_button.offset_right = left + 118.0
	skip_button.offset_top = 16.0
	skip_button.offset_bottom = 58.0

func _sync_dialog_mask() -> void:
	if is_instance_valid(dim):
		if external_owner and external_operation:
			dim.visible = false
			return
		# 外部教学对白的遮罩与对白同步，不能被业务弹窗抑制或遗留透明度覆盖。
		if external_owner and (dialog.visible or external_operation):
			dim.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
			dim.visible = true
			_sync_task_cutouts()
			return
		dim.visible = (dialog.visible or external_operation) and not _modal_suppressed
		_sync_task_cutouts()

func _sync_task_cutouts() -> void:
	# 仅改变暗幕像素透明度；原 ColorRect 仍全屏拦截输入。
	var cutout := dim.material as ShaderMaterial
	var rects: Array[Rect2] = []
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if dim.visible and is_instance_valid(tracker) and tracker.has_method("explanation_cutout_rects"):
		rects = tracker.explanation_cutout_rects()
	if external_owner: rects = external_cutouts
	cutout.set_shader_parameter("overlay_size", dim.size)
	cutout.set_shader_parameter("circle_cutouts", external_owner and external_circles)
	for index in range(2):
		var rect := Rect2()
		if index < rects.size():
			rect = dim.get_global_transform().affine_inverse() * rects[index]
		cutout.set_shader_parameter("ingredients_rect" if index == 0 else "cooking_rect",
			Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))

func play_dialog(speaker: String, lines: Array, ptex: Texture2D = null) -> void:
	dialog.visible = true
	dim.color = Color(0.08, 0.06, 0.04, DIALOG_DIM_ALPHA)
	_sync_dialog_mask()
	dialog.start(speaker, lines, ptex)

func hide_box() -> void:
	if dialog:
		dialog.hide_box()

func _on_dialog_finished() -> void:
	_sync_dialog_mask()
	dialog_done.emit()

func show_toast(text: String) -> void:
	toast_panel.modulate.a = 1.0
	toast.text = text
	toast.visible = true
	toast_panel.visible = true
	_position_toast()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_hide_toast)

func _hide_toast() -> void:
	toast.visible = false
	toast_panel.visible = false
	toast_panel.modulate.a = 1.0

func finish_all() -> void:
	_modal_suppressed = false
	_modal_hint_visible = false
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	hint_panel.visible = false
	dialog.hide_box()
	_hide_toast()
	skip_button.visible = false
	chapter_title.visible = false
	chapter_stage.visible = false
	dim.visible = false
	_sync_task_cutouts()
	visible = false
