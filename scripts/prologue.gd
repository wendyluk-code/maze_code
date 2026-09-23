extends Control
## 唯一游戏入口：新档先播序章，已看/稳定旧档直接进入正式餐厅。

const TRANSITION := preload("res://scripts/prologue_transition.gd")
const RESTAURANT := "res://scenes/restaurant_map_2d.tscn"
const STALL_TIMEOUT := 8.0

@export_file("*.ogv") var video_path := "res://assets/video/prologue/prologue_opening_zh.ogv"
@onready var video: VideoStreamPlayer = %Video
@onready var skip_button: Button = %SkipPrologue
@onready var status: Label = %Status

var _leaving := false
var _last_position := 0.0
var _stalled_for := 0.0

func _ready() -> void:
	add_to_group("prologue")
	skip_button.set_icon_visible(false)
	skip_button.pressed.connect(request_exit.bind("skip_button"))
	video.finished.connect(_on_finished)
	if SaveManager.is_prologue_done() and not SaveManager.is_prologue_preview():
		request_exit.call_deferred("already_seen")
		return
	if SaveManager.is_prologue_preview():
		status.text = "序章重播 · 本次游戏不保存进度"
	_start_video.call_deferred()

func _start_video() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(video_path, "VideoStream"):
		_playback_failed("资源缺失：" + video_path)
		return
	video.stream = load(video_path) as VideoStream
	if video.stream == null:
		_playback_failed("无法加载视频：" + video_path)
		return
	video.play()
	print("PROLOGUE playback_started: ", video_path)

func _process(delta: float) -> void:
	if _leaving or video.stream == null:
		return
	var position := video.stream_position
	if position > _last_position + 0.01:
		_last_position = position
		_stalled_for = 0.0
	else:
		_stalled_for += delta
	if _stalled_for >= STALL_TIMEOUT:
		_playback_failed("播放进度停滞超过 8 秒，位置=" + str(position))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		request_exit("skip_key")

func _on_finished() -> void:
	request_exit("finished")

func _playback_failed(message: String) -> void:
	push_warning("PROLOGUE 播放失败，安全进入第一章：" + message)
	status.text = "序章暂时无法播放，正在进入第一章……"
	request_exit("playback_failed")

## 在任何 await 前取得唯一转场权；按钮、按键、finished 竞态共用此入口。
func request_exit(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	skip_button.disabled = true
	set_process(false)
	print("PROLOGUE exit_requested: ", reason, " position=", video.stream_position)
	var transition := TRANSITION.new()
	transition.failed.connect(_on_transition_failed)
	get_tree().root.add_child(transition)
	transition.enter_restaurant(RESTAURANT, reason != "already_seen", video)

func _on_transition_failed() -> void:
	_leaving = false
	skip_button.disabled = false
	status.text = "餐厅加载失败，请重试进入（详见日志）"
