extends Control
## 唯一游戏入口：新档先播序章，已看/稳定旧档直接进入正式餐厅。

const TRANSITION := preload("res://scripts/prologue_transition.gd")
const RESTAURANT := "res://scenes/restaurant_map_2d.tscn"
const STALL_TIMEOUT := 8.0

@export_file("*.ogv") var video_path := "res://assets/video/prologue/prologue_opening_zh.ogv"
@export_file("*.png") var end_card_path := "res://assets/video/prologue/prologue_end_card.png"
@export var end_card_time := 197.5
@onready var video: VideoStreamPlayer = %Video
@onready var end_card: TextureRect = %EndCard
@onready var skip_button: Button = %SkipPrologue
@onready var status: Label = %Status

var _leaving := false
var _last_position := 0.0
var _stalled_for := 0.0
var playback_state := "playing"
var _e_held := false
var _continue_armed := false
var _end_key: TextureRect

func _ready() -> void:
	add_to_group("prologue")
	# 片尾字幕已烘焙进图片；只覆盖原 E 键帽，保留原字幕与画面。
	_end_key = TextureRect.new()
	_end_key.name = "ContinueKeyIcon"
	_end_key.texture = preload("res://scripts/ui/components/continue_prompt.gd").key_texture()
	_end_key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_end_key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_end_key.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_end_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_card.add_child(_end_key)
	end_card.resized.connect(_layout_end_key)
	skip_button.focus_mode = Control.FOCUS_NONE
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
	if ResourceLoader.exists(end_card_path, "Texture2D"):
		end_card.texture = load(end_card_path) as Texture2D
	if end_card.texture == null:
		_playback_failed("片尾画面缺失：" + end_card_path)
		return
	_layout_end_key()
	video.play()
	print("PROLOGUE playback_started: ", video_path)

func _layout_end_key() -> void:
	if not is_instance_valid(_end_key) or end_card.texture == null:
		return
	var source := end_card.texture.get_size()
	var factor := minf(end_card.size.x / source.x, end_card.size.y / source.y)
	var origin := (end_card.size - source * factor) * 0.5
	_end_key.position = origin + Vector2(531, 554) * factor
	_end_key.size = Vector2(27, 29) * factor

func _process(delta: float) -> void:
	if _leaving or playback_state != "playing" or video.stream == null:
		return
	var position := video.stream_position
	if end_card_time > 0.0 and position >= end_card_time:
		_enter_awaiting_continue()
		return
	if position > _last_position + 0.01:
		_last_position = position
		_stalled_for = 0.0
	else:
		_stalled_for += delta
	if _stalled_for >= STALL_TIMEOUT:
		_playback_failed("播放进度停滞超过 8 秒，位置=" + str(position))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or (event.keycode != KEY_E and event.physical_keycode != KEY_E):
		return
	get_viewport().set_input_as_handled()
	if event.echo:
		return
	if not event.pressed:
		_e_held = false
		if playback_state == "awaiting_continue":
			_continue_armed = true
		return
	var was_held := _e_held
	_e_held = true
	if playback_state == "awaiting_continue" and _continue_armed and not was_held:
		_continue_armed = false
		request_exit("end_card_continue")

func _on_finished() -> void:
	_enter_awaiting_continue()

func _enter_awaiting_continue() -> void:
	if _leaving or playback_state != "playing":
		return
	playback_state = "awaiting_continue"
	video.paused = true
	end_card.show()
	# 跨越片尾边界一直按住 E 时，必须先释放再按，重复事件不能穿透。
	_continue_armed = not _e_held and not Input.is_key_pressed(KEY_E) and not Input.is_physical_key_pressed(KEY_E)
	print("PROLOGUE awaiting_continue: position=", video.stream_position)

func _playback_failed(message: String) -> void:
	push_warning("PROLOGUE 播放失败，安全进入第一章：" + message)
	status.text = "序章暂时无法播放，正在进入第一章……"
	request_exit("playback_failed")

## 在任何 await 前取得唯一转场权；按钮、按键、finished 竞态共用此入口。
func request_exit(reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	playback_state = "leaving"
	skip_button.disabled = true
	set_process(false)
	print("PROLOGUE exit_requested: ", reason, " position=", video.stream_position)
	var transition := TRANSITION.new()
	transition.failed.connect(_on_transition_failed)
	get_tree().root.add_child(transition)
	var destination := SaveManager.resume_scene_path() if reason == "already_seen" else RESTAURANT
	transition.enter_restaurant(destination, reason != "already_seen", video)

func _on_transition_failed() -> void:
	_leaving = false
	playback_state = "awaiting_continue"
	_continue_armed = not _e_held and not Input.is_key_pressed(KEY_E) and not Input.is_physical_key_pressed(KEY_E)
	if end_card.texture != null:
		end_card.show()
	skip_button.disabled = false
	status.text = "餐厅加载失败，请重试进入（详见日志）"
