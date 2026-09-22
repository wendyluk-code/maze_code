extends Control
## 教程引导层（放到 CanvasLayer 下，全屏覆盖）
## 组成：对白暗幕 + 顶部阶段提示 + 跳过按钮 + 对话框 + Toast

signal dialog_done

@onready var dim: ColorRect = %Dim
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var skip_button: Button = %SkipButton
@onready var dialog = %DialogBox
@onready var toast: Label = %Toast
@onready var chapter_title: Label = %ChapterTitle
@onready var chapter_stage: Label = %ChapterStage

var _toast_tween: Tween = null
var _modal_suppressed := false
var _modal_hint_visible := false

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
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	visible = true
	dim.visible = false
	dim.color.a = 0.5
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
		hint_panel.visible = false
	else:
		hint_panel.visible = _modal_hint_visible
	_sync_dialog_mask()

func setup(step: Dictionary) -> void:
	# 阶段提示放在章节信息下方，并避开当前角色、目标和交互按钮。
	var hint := str(step.get("hint", ""))
	hint_panel.visible = not hint.is_empty()
	hint_label.text = hint
	_sync_dialog_mask()

func set_chapter_stage(stage: int, title: String) -> void:
	if stage <= 0:
		return
	chapter_stage.text = "阶段 %d/7 · %s" % [stage, title]

func _process(_delta: float) -> void:
	_sync_dialog_mask()
	_position_hint_panel()
	_position_skip_button()

func _position_hint_panel() -> void:
	var viewport_width := get_viewport_rect().size.x
	var obstacles: Array[Rect2] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		var player_screen := get_viewport().get_canvas_transform() * player.global_position
		obstacles.append(Rect2(player_screen + Vector2(-55.0, -155.0), Vector2(110.0, 180.0)))
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.visible:
		obstacles.append(tracker.get("_panel").get_global_rect())
	var tm := get_node_or_null("/root/TutorialManager")
	if tm != null and tm.active and tm.idx >= 0 and tm.idx < tm.steps.size():
		var step: Dictionary = tm.steps[tm.idx]
		var target: Node2D = tm.resolve_target(step.get("target")) if tm.has_method("resolve_target") else null
		if is_instance_valid(target):
			var target_screen := get_viewport().get_canvas_transform() * target.global_position
			obstacles.append(Rect2(target_screen + Vector2(-130.0, -165.0), Vector2(260.0, 210.0)))
	var ui := get_tree().get_first_node_in_group("ui_layer")
	if is_instance_valid(ui):
		for button in ui.get("_buttons").values():
			if is_instance_valid(button) and button.visible:
				obstacles.append(button.get_global_rect())
	if dialog.visible:
		obstacles.append(dialog.get_global_rect())
	var candidates: Array[float] = [20.0, (viewport_width - 380.0) * 0.5, viewport_width - 400.0]
	var left := candidates[1]
	var best_score := INF
	for candidate in candidates:
		var score := _overlap_score(Rect2(candidate, 94.0, 380.0, 64.0), obstacles)
		if score < best_score:
			best_score = score
			left = candidate
	hint_panel.anchor_left = 0.0
	hint_panel.anchor_right = 0.0
	hint_panel.anchor_top = 0.0
	hint_panel.anchor_bottom = 0.0
	hint_panel.offset_left = left
	hint_panel.offset_right = left + 380.0
	hint_panel.offset_top = 94.0
	hint_panel.offset_bottom = 158.0

func _overlap_score(rect: Rect2, obstacles: Array[Rect2]) -> float:
	var score := 0.0
	for obstacle in obstacles:
		if rect.intersects(obstacle):
			score += rect.intersection(obstacle).get_area()
	return score

func _position_skip_button() -> void:
	var viewport_width := get_viewport_rect().size.x
	var left_rect := Rect2(12.0, 12.0, 118.0, 44.0)
	var right_rect := Rect2(viewport_width - 130.0, 12.0, 118.0, 44.0)
	var left_score := 0.0
	var right_score := 0.0
	var ui := get_tree().get_first_node_in_group("ui_layer")
	if is_instance_valid(ui):
		for button in ui.get("_buttons").values():
			if not is_instance_valid(button) or not button.visible:
				continue
			var button_rect: Rect2 = button.get_global_rect()
			if left_rect.intersects(button_rect):
				left_score += left_rect.intersection(button_rect).get_area()
			if right_rect.intersects(button_rect):
				right_score += right_rect.intersection(button_rect).get_area()
	var left := 12.0 if left_score <= right_score else viewport_width - 130.0
	skip_button.anchor_left = 0.0
	skip_button.anchor_right = 0.0
	skip_button.anchor_top = 0.0
	skip_button.anchor_bottom = 0.0
	skip_button.offset_left = left
	skip_button.offset_right = left + 118.0
	skip_button.offset_top = 12.0
	skip_button.offset_bottom = 56.0

func _sync_dialog_mask() -> void:
	if is_instance_valid(dim):
		dim.visible = dialog.visible and not _modal_suppressed

func play_dialog(speaker: String, lines: Array, ptex: Texture2D = null) -> void:
	dialog.visible = true
	dim.color.a = 0.32
	_sync_dialog_mask()
	dialog.start(speaker, lines, ptex)

func hide_box() -> void:
	if dialog:
		dialog.hide_box()

func _on_dialog_finished() -> void:
	_sync_dialog_mask()
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
	_toast_tween.tween_callback(_hide_toast)

func _hide_toast() -> void:
	toast.visible = false
	toast.modulate.a = 1.0

func finish_all() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	hint_panel.visible = false
	dialog.hide_box()
	toast.visible = false
	skip_button.visible = false
	chapter_title.visible = false
	chapter_stage.visible = false
	dim.visible = false
	visible = false
