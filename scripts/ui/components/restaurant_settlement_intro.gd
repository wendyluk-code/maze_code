extends TextureRect
## 标题展开与结算翻面；只负责显示，不修改账目。
signal finished
var motion: Tween
var reveal := 0.08
var opacity := 0.0
var panel_reveal := 0.0
var modal: Control

func start(owner_modal: Control, closed_day: bool) -> void:
	modal = owner_modal
	var audio := get_node_or_null("/root/GameAudio")
	if audio: audio.play_cue(&"restaurant_closed" if closed_day else &"cooking_complete")
	texture = load("res://assets/ui/restaurant_day/closed_title.png" if closed_day else "res://assets/ui/restaurant_day/complete_title.png")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	modal._panel.hide()
	motion = create_tween()
	motion.set_parallel(true)
	motion.tween_property(self,"reveal",1.0,0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(self,"opacity",1.0,0.25)
	motion.chain().tween_interval(0.8)
	motion.chain().tween_property(self,"reveal",0.02,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	motion.chain().tween_callback(func(): hide(); modal._panel.show())
	motion.chain().tween_property(self,"panel_reveal",1.0,0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.chain().tween_callback(func():
		modal._panel.pivot_offset = Vector2.ZERO
		modal._layout()
		finished.emit()
		queue_free())
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(modal): return
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x/1280.0,viewport_size.y/720.0)
	size = Vector2(640,320)*factor
	pivot_offset = size*0.5
	position = (viewport_size-size)*0.5
	scale = Vector2(reveal,lerpf(0.85,1.0,clampf(reveal,0,1)))
	modulate.a = opacity
	if modal._panel.visible:
		modal._panel.pivot_offset = modal._panel.size*0.5
		modal._panel.position = (viewport_size-modal._panel.size)*0.5
		modal._panel.scale = Vector2(maxf(0.02,panel_reveal),lerpf(0.3,1.0,panel_reveal))*factor

func _exit_tree() -> void:
	if motion: motion.kill()
