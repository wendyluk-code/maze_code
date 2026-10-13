extends Control
## 两张独立透明角色卡：叠放入场、扇形展开、新按E继续。
signal continue_requested
signal reveal_finished
var cards: Array[TextureRect] = []
const CardArtCatalog = preload("res://scripts/ui/components/card_art_catalog.gd")
var _veil: ColorRect
var _join_message: Label
var _prompt: HBoxContainer
var _error: Label
var _tween: Tween
var _progress := 0.0
var _ready_for_input := false
var _armed := false
var _e_held := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SproutTheme.make_theme()
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.025, 0.035, 0.03, 0.70)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	var records := CardArtCatalog.display_records()
	for index in 2:
		var card := TextureRect.new()
		card.name = "YayaCard" if index == 0 else "TieshanCard"
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cards.append(card)
		add_child(card)
		var role_id := "yaya" if index == 0 else "tieshan"
		for record in records:
			if str(record.get("id", "")) != role_id:
				continue
			var values: Dictionary = record.duplicate(true)
			values["illustration_path"] = CardArtCatalog.path_for(role_id)
			var template := SproutCard.new()
			template.name = "TemplateCard"
			template.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(template)
			template.configure(SproutCardData.new(values))
			template.size = SproutCard.CARD_SIZE
			# 正文复用公共可读布局，其对称内边距由共享组件负责。
			if template.has_method("set_readable_battle_text"):
				template.call("set_readable_battle_text", true)
			break
	_join_message = _label("芽芽、铁山加入队伍", 30)
	_join_message.add_theme_color_override("font_color", Color("fff1cd"))
	_join_message.add_theme_color_override("font_outline_color", Color("493626"))
	_join_message.add_theme_constant_override("outline_size", 6)
	_join_message.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.04, 0.6))
	_join_message.add_theme_constant_override("shadow_offset_y", 3)
	_prompt = preload("res://scripts/ui/components/continue_prompt.gd").new()
	add_child(_prompt)
	_error = _label("", 17)
	resized.connect(_layout)
	hide()

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SproutTheme.CREAM)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.06, 0.7))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label

func _layout() -> void:
	if cards.size() != 2:
		return
	var height := minf(540.0, minf(size.y * 0.70, size.x * 0.58))
	var card_size := Vector2(height * 0.6, height)
	for index in 2:
		var card := cards[index]
		var direction := -1.0 if index == 0 else 1.0
		card.size = card_size
		var template := card.get_node_or_null("TemplateCard") as SproutCard
		if template:
			template.scale = Vector2.ONE * (height / 500.0)
		card.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
		var spread := lerpf(10.0, card_size.x * 0.56, _progress)
		var anchor := Vector2(size.x * 0.5 + direction * spread, minf(size.y * 0.81, size.y - 124.0) + (1.0 - _progress) * 25.0)
		card.position = anchor - card.pivot_offset
		card.rotation = direction * lerpf(0.018, 0.075, _progress)
		card.scale = Vector2.ONE * lerpf(0.92, 1.0, _progress)
		card.modulate.a = clampf(_progress * 5.0, 0.0, 1.0)
	if is_instance_valid(_prompt):
		_join_message.position = Vector2(0, size.y - 110)
		_join_message.size = Vector2(size.x, 42)
		_prompt.position = Vector2(0, size.y - 60)
		_prompt.size = Vector2(size.x, 36)
		_error.position = Vector2(0, size.y - 28)
		_error.size = Vector2(size.x, 24)

func _set_progress(value: float) -> void:
	_progress = value
	_layout()

func present() -> void:
	cancel()
	_error.text = ""
	_e_held = _e_held or Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E)
	_set_progress(0.0)
	_veil.modulate.a = 0.0
	_join_message.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	show()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_veil, "modulate:a", 1.0, 0.30)
	_tween.tween_method(_set_progress, 0.0, 1.0, 0.78).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(_prompt, "modulate:a", 1.0, 0.18)
	_tween.parallel().tween_property(_join_message, "modulate:a", 1.0, 0.18)
	_tween.chain().tween_callback(_finish_reveal)

func _finish_reveal() -> void:
	_tween = null
	_ready_for_input = true
	_armed = not _e_held
	reveal_finished.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _ready_for_input and not _e_held:
			continue_requested.emit()
		return
	var is_e: bool = event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E)
	if not visible:
		if is_e and not event.echo:
			_e_held = event.pressed
		return
	get_viewport().set_input_as_handled()
	if not is_e or event.echo:
		return
	if not event.pressed:
		_e_held = false
		_armed = _ready_for_input
		return
	var held := _e_held
	_e_held = true
	if _ready_for_input and _armed and not held:
		_armed = false
		continue_requested.emit()

func show_error(message: String) -> void:
	_error.text = message

func cancel() -> void:
	_ready_for_input = false
	_armed = false
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	hide()

func _exit_tree() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
