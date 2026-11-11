extends ColorRect
signal closed
signal feedback(message: String)
const Service := preload("res://scripts/restaurant/ganlu_service.gd")
const Style := preload("res://scripts/ui/components/modal_style.gd")
var panel: PanelContainer
var view: Control
var hold: Button
var take: Button
var close_button: Button
var started := false
var finished := false
var committed := false
var amount := 0.0
var source := ""
var result_popup: Control
var transition: Tween
var transitioning := false
var settling_time := 0.0
var pour_audio: AudioStreamPlayer

func _ready() -> void:
	pour_audio = AudioStreamPlayer.new()
	pour_audio.stream = preload("res://assets/audio/sfx/ganlu_pour.ogg")
	pour_audio.stream.loop = true
	pour_audio.volume_db = -6.0
	add_child(pour_audio)
	GameAudio.bind_volume(pour_audio, &"ganlu_pour")
	visibility_changed.connect(func():
		if not is_visible_in_tree(): pour_audio.stop())
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	color = Style.BACKDROP
	theme = SproutTheme.make_theme()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("fff2d4")))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var balance := Control.new()
	balance.custom_minimum_size = Vector2(44, 44)
	header.add_child(balance)
	var title := Label.new()
	title.text = "甘露水"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	close_button = Style.close_button(true)
	header.add_child(close_button)
	close_button.pressed.connect(dismiss)
	view = preload("res://scripts/ui/components/ganlu_pour_view.gd").new()
	view.custom_minimum_size = Vector2(560,350)
	view.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(view)
	hold = SproutButton.new()
	hold.set_icon_visible(false)
	hold.text = "按住倒水"
	hold.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(hold)
	hold.button_down.connect(func(): start_pour("mouse"))
	hold.button_up.connect(func(): stop_pour())
	take = SproutButton.new()
	take.set_icon_visible(false)
	take.text = "端起"
	take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(take)
	take.pressed.connect(dismiss)
	result_popup = preload("res://scripts/ui/components/ganlu_result_popup.gd").new()
	add_child(result_popup)
	result_popup.confirmed.connect(_result_confirmed)
	get_viewport().size_changed.connect(_layout)
	get_window().focus_exited.connect(stop_pour)
	hide()

func _layout() -> void:
	panel.size = Vector2(600, 490)
	panel.position = (get_viewport_rect().size - panel.size) * 0.5

func _exit_tree() -> void:
	if is_instance_valid(pour_audio): pour_audio.stop()

func open() -> void:
	pour_audio.stop()
	if is_instance_valid(transition): transition.kill()
	transitioning = false
	transition = null
	settling_time = 0.0
	panel.scale = Vector2.ONE
	hold.disabled = false
	close_button.disabled = false
	result_popup.cancel()
	panel.show()
	started = false
	finished = false
	committed = false
	amount = 0
	view.amount = 0
	view.drops.clear()
	view.reset_motion()
	view.pouring = false
	hold.show()
	take.hide()
	show()
	_layout()
	close_button.grab_focus()

func start_pour(input_source := "mouse") -> void:
	if not visible or started or finished: return
	if not Service.begin(SaveManager).success:
		feedback.emit("杯子未准备好或保存失败，请重试")
		return
	started = true
	source = input_source
	view.pouring = true
	pour_audio.play()

func _process(delta: float) -> void:
	if not visible or not started: return
	if finished:
		if transitioning and not is_instance_valid(transition):
			settling_time += delta
			if settling_time>=1.0 and not view.has_airborne_water(): _flip_to_result()
		return
	var emitted := minf(delta*0.22,1.2-amount)
	amount += emitted
	view.emit_water(emitted)
	if amount>=1.2: stop_pour()

func stop_pour() -> void:
	pour_audio.stop()
	if not visible or not started or finished: return
	finished = true
	view.pouring = false
	transitioning = true
	hold.disabled = true
	close_button.disabled = true
	settling_time = 0.0

func _flip_to_result() -> void:
	# 已倒出的余水全部入杯后才展示最终量；不再凭固定延迟猜测落水完成。
	transition = create_tween()
	transition.tween_callback(func(): panel.pivot_offset = panel.size*0.5)
	transition.tween_property(panel,"scale:x",0.02,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	transition.tween_callback(func():
		panel.hide()
		result_popup.present_water(amount)
		result_popup.flip_in()
		if Service.pour_factor(amount) > 0:
			GameAudio.play_cue(&"cooking_complete")
		elif amount < 0.65:
			GameAudio.play_cue(&"failure")
		transitioning = false)

func _result_confirmed() -> void:
	if transitioning: return
	if Service.pour_factor(amount) <= 0:
		if not Service.discard(SaveManager).success:
			feedback.emit("保存失败，请重试")
			result_popup.retry_save()
			return
		open()
		return
	if not _save_result():
		result_popup.retry_save()
		return
	result_popup.cancel()
	hide()
	closed.emit()

func _save_result() -> bool:
	committed = Service.finish(SaveManager, amount).success
	take.text = "端起" if committed else "重试保存"
	if not committed: feedback.emit("倒水结果未保存，请重试保存")
	return committed

func dismiss() -> void:
	if not visible: return
	if started and not finished:
		stop_pour()
		return
	if finished: return
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible: return
	if finished: return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.pressed: start_pour("key")
			elif source == "key": stop_pour()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and event.pressed:
			dismiss()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and source == "mouse":
		stop_pour()
