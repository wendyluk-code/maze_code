extends CanvasLayer
## 临时根节点跨场景保留黑幕；完成后自销毁，不改变暂停、镜头或玩家锁。

signal failed
signal covered
signal revealed

const FADE_SECONDS := 0.5
var curtain: ColorRect
var _started := false

func _ready() -> void:
	add_to_group("prologue_transition")
	layer = 100
	curtain = ColorRect.new()
	curtain.name = "Curtain"
	curtain.color = Color(0, 0, 0, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func enter_restaurant(path: String, record_completion: bool, video: VideoStreamPlayer) -> void:
	if _started:
		return
	_started = true
	var fade := create_tween().set_parallel(true)
	fade.tween_property(curtain, "color:a", 1.0, FADE_SECONDS)
	if is_instance_valid(video):
		fade.tween_property(video, "volume", 0.0, FADE_SECONDS)
	await fade.finished
	covered.emit()
	# 至少呈现一帧完整黑幕，再同步装载目标，避免最后一帧闪回。
	await get_tree().process_frame
	if is_instance_valid(video):
		video.stop()
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("PROLOGUE 餐厅场景切换失败：" + str(error))
		await _reveal()
		failed.emit()
		queue_free()
		return
	await get_tree().scene_changed
	if record_completion:
		SaveManager.complete_prologue()
	print("PROLOGUE restaurant_entered")
	await _reveal()
	# Input.parse_input_event / 系统按键可能在当前帧缓冲；遮罩销毁前消耗，
	# 避免淡出最后一帧的 Enter/空格落到新餐厅的首句对白。
	Input.flush_buffered_events()
	revealed.emit()
	queue_free()

func _reveal() -> void:
	var fade := create_tween()
	fade.tween_property(curtain, "color:a", 0.0, FADE_SECONDS)
	await fade.finished
