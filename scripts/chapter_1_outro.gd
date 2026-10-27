extends CanvasLayer
## 入队与入口介绍；持久进度由SaveManager管理，镜头/输入由TutorialManager拥有。
const END_OVERLAY := preload("res://scripts/ui/chapter_end_overlay.gd")
const ENTRANCE_HIGHLIGHT := preload("res://scripts/ui/entrance_highlight.gd")
const PARTY_CARDS := preload("res://scripts/ui/party_cards_overlay.gd")
const HOME_LINE := "休息时，可以来冒险者之家找我们。"
const MAZE_LINE := "等你准备好了，就从这里进入迷宫吧。"
var _manager: Node
var _token := 0
var _cancelled := false
var _busy := true
var phase := ""
var _party: Control
var _ending: Control
var _tracker: Control
var _tracker_alpha := 1.0
var _tracker_disabled := false
var _entrance_highlight: Node2D

func _exit_tree() -> void:
	_clear_entrance_highlight()

func _clear_entrance_highlight() -> void:
	if is_instance_valid(_entrance_highlight):
		_entrance_highlight.hide()
		_entrance_highlight.queue_free()
	_entrance_highlight = null

func _highlight_entrance(which: String) -> void:
	_clear_entrance_highlight()
	_entrance_highlight = ENTRANCE_HIGHLIGHT.new()
	_entrance_highlight.name = "HomeEntranceHighlight" if which == "home" else "MazeEntranceHighlight"
	_entrance_highlight.configure_entrance(which)
	_entrance_highlight.background = get_tree().current_scene.get_node("BG")
	var guide = _manager.guide
	guide.add_child(_entrance_highlight)
	guide.move_child(_entrance_highlight, guide.dim.get_index() + 1)
	_entrance_highlight._process(0.0)

func _ready() -> void:
	layer = 80
	_build()

func _build() -> void:
	_party = PARTY_CARDS.new()
	add_child(_party)
	_party.continue_requested.connect(func(): _advance("party"))
	_party.reveal_finished.connect(func():
		if _valid() and phase == "party":
			_busy = false)
	_ending = END_OVERLAY.new()
	add_child(_ending)
	_ending.continue_requested.connect(_on_continue)

func start(manager: Node, token: int) -> void:
	_manager = manager
	_token = token
	_tracker = get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(_tracker):
		_tracker.collapse_details()
		_tracker_alpha = _tracker.modulate.a
		_tracker_disabled = _tracker._task_button.disabled
		_tracker.modulate.a = 0
		_tracker._task_button.disabled = true
	_manager.guide.dialog_done.connect(_on_dialog_done)
	_render_phase.call_deferred()

func _valid() -> bool:
	return not _cancelled and is_instance_valid(_manager) and _manager._run_is_valid(_token)

func _render_phase() -> void:
	if not _valid():
		return
	_busy = true
	_clear_entrance_highlight()
	phase = SaveManager.chapter_1_outro_state()
	_party.cancel()
	_manager.guide.hide_box()
	_manager.guide.setup({})
	match phase:
		"party":
			_party.present()
		"home", "maze":
			await _focus_entrance(phase)
			if not _valid():
				return
			_highlight_entrance(phase)
			_manager.guide.play_dialog("芽芽", [HOME_LINE if phase == "home" else MAZE_LINE], load("res://assets/characters/yaya_portrait.png"))
			_busy = false
		"title":
			await _manager._unpark_camera(_token)
			if not _valid():
				return
			_ending.present("第一章：第一顿饭", "你苏醒后，和芽芽一起结识了铁山，\n准备一同前往迷宫浅层探索")
			_busy = false
		"done":
			_manager._finish()

func _focus_entrance(which: String) -> void:
	var camera: Camera2D = _manager._get_camera()
	var root := get_tree().current_scene
	var target: Node2D = root.get_node_or_null("InteractPoints/AdventurerHomeDoor" if which == "home" else "DepartureEntrance")
	if not is_instance_valid(camera) or not is_instance_valid(target):
		push_error("章节收尾缺少镜头或入口：" + which)
		return
	if not _manager._base_zoom_captured:
		_manager._base_zoom = camera.zoom
		_manager._base_zoom_captured = true
	_manager._kill_camera_tween()
	camera.paused = true
	_manager._camera_cutscene_active = true
	_manager._camera_parked = true
	var tween := create_tween().set_parallel(true)
	_manager._camera_tween = tween
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", Vector2(1.65, 1.65), 0.85)
	tween.tween_property(camera, "global_position", target.global_position + Vector2(0, 70), 0.85)
	await tween.finished
	if _valid():
		_manager._camera_tween = null

func _on_dialog_done() -> void:
	if phase in ["home", "maze"]:
		_advance(phase)

func _advance(expected: String) -> void:
	if not _valid() or _busy or phase != expected:
		return
	_busy = true
	var result := SaveManager.advance_chapter_1_outro(expected)
	if not result.success:
		_busy = false
		if expected == "party":
			_party.show_error("进度未保存，请重试。")
		else:
			_manager.guide.show_toast("进度未保存，请重试。")
			_render_phase.call_deferred()
		return
	if result.created and not SaveManager._replaying:
		_manager.chapter_1_finished.emit()
	_render_phase.call_deferred()

func _on_continue() -> void:
	if not _valid() or _busy or phase != "title":
		return
	_busy = true
	var result := SaveManager.advance_chapter_1_outro("title")
	if not result.success:
		_ending.show_error("进度未保存，请再按 E 重试。")
		_busy = false
		return
	await _ending.dismiss()
	if _valid():
		_manager._finish()

func cancel() -> void:
	_cancelled = true
	_clear_entrance_highlight()
	if is_instance_valid(_ending):
		_ending.cancel()
	if is_instance_valid(_party):
		_party.cancel()
	if is_instance_valid(_tracker):
		_tracker.modulate.a = _tracker_alpha
		_tracker._task_button.disabled = _tracker_disabled
	if is_instance_valid(_manager) and is_instance_valid(_manager.guide) and _manager.guide.dialog_done.is_connected(_on_dialog_done):
		_manager.guide.dialog_done.disconnect(_on_dialog_done)
