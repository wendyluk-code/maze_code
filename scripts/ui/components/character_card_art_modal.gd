extends SproutModal
## 原图卡牌蒙层：只等比展示调用方传入的完整素材，不拼装或重绘卡面。
const STEP := 234.0
const CARD_SIZE := Vector2(218, 364)
const HAND_SLOTS := 4
var character_id := ""
var cards: Array[Dictionary] = []
var hand_cards: Array[Dictionary] = []
var role_card: TextureRect
var role_nameplate: Panel
var role_name: Label
var quantity_labels: Array[Label] = []
var card_index := 0
var design: Control
var viewport_area: Control
var strip: Control
var previous_button: Button
var next_button: Button
var progress: Label
var empty_label: Label
var _dragging := false
var _pointer := -2
var _origin := Vector2.ZERO
var _start_x := 0.0
var _slide: Tween

func _build() -> void:
	theme = SproutTheme.make_theme()
	_overlay = ColorRect.new()
	_overlay.color = Color(0.08, 0.06, 0.04, 0.72)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	design = Control.new()
	design.size = Vector2(1280, 720)
	add_child(design)
	_close_button = _button("×", Vector2(1160, 28), Vector2(56, 48))
	(_close_button as SproutButton).set_focus_visual(false)
	_close_button.tooltip_text = "关闭卡牌"
	_close_button.pressed.connect(close_modal)
	viewport_area = Control.new()
	role_card = _card_texture()
	role_card.position = Vector2(48, 170)
	design.add_child(role_card)
	role_nameplate = Panel.new()
	role_nameplate.position = Vector2(91, 538)
	role_nameplate.size = Vector2(132, 38)
	role_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nameplate_style := SproutTheme.thin_panel_style(SproutTheme.PANEL)
	nameplate_style.set_border_width_all(0)
	nameplate_style.set_corner_radius_all(3)
	role_nameplate.add_theme_stylebox_override("panel", nameplate_style)
	design.add_child(role_nameplate)
	role_name = _label("", Vector2.ZERO, role_nameplate.size, 24)
	role_name.add_theme_color_override("font_color", SproutTheme.INK)
	role_name.reparent(role_nameplate, false)
	viewport_area.position = Vector2(298, 170)
	viewport_area.size = Vector2(STEP * HAND_SLOTS - (STEP - CARD_SIZE.x), 408)
	viewport_area.clip_contents = true
	viewport_area.mouse_default_cursor_shape = Control.CURSOR_DRAG
	design.add_child(viewport_area)
	strip = Control.new()
	viewport_area.add_child(strip)
	empty_label = _label("尚未获得手牌", Vector2(320, 280), Vector2(860, 72), 25)
	previous_button = _button("←", Vector2(600, 612), Vector2(56, 48))
	next_button = _button("→", Vector2(856, 612), Vector2(56, 48))
	previous_button.pressed.connect(func(): step(-1))
	next_button.pressed.connect(func(): step(1))
	progress = _label("", Vector2(664, 615), Vector2(184, 40), 21)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(design): return
	var fit := minf(size.x / 1280.0, size.y / 720.0)
	design.scale = Vector2.ONE * fit
	design.position = (size - design.size * fit) * 0.5
	_dragging = false
	if is_instance_valid(strip): _snap(false)

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SproutTheme.CREAM)
	design.add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := SproutButton.new()
	button.configure(value).set_icon_visible(false)
	design.add_child(button)
	button.custom_minimum_size = dimensions
	button.position = at
	button.size = dimensions
	return button

func present(id: String, artwork: Array[Dictionary]) -> void:
	character_id = id
	# 相同ID合并数量，未知/零数量不显示；角色牌与手牌使用独立容器。
	cards.clear()
	hand_cards.clear()
	quantity_labels.clear()
	var by_id := {}
	for item in artwork:
		var quantity := int(item.get("quantity", 0))
		if quantity <= 0: continue
		if by_id.has(item.id): by_id[item.id].quantity += quantity
		else:
			var copy: Dictionary = item.duplicate(true)
			copy.quantity = quantity
			by_id[item.id] = copy
			cards.append(copy)
	role_card.hide()
	role_nameplate.hide()
	for item in cards:
		if item.get("role", false):
			role_card.texture = load(item.path)
			role_card.show()
			role_name.text = str({"yaya": "芽芽", "tieshan": "铁山"}.get(id, "角色"))
			role_nameplate.show()
		else: hand_cards.append(item)
	card_index = 0
	_dragging = false
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	for index in hand_cards.size():
		var slot := Control.new()
		slot.position = Vector2(index * STEP, 0)
		slot.size = Vector2(CARD_SIZE.x, 408)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(slot)
		var card := _card_texture()
		card.texture = load(hand_cards[index].path)
		slot.add_child(card)
		var quantity := _label("x%d" % int(hand_cards[index].quantity), Vector2(0, 368), Vector2(CARD_SIZE.x, 34), 24)
		quantity.reparent(slot, false)
		quantity_labels.append(quantity)
	empty_label.visible = hand_cards.is_empty()
	viewport_area.visible = not hand_cards.is_empty()
	_refresh()
	_snap(false)
	show()
	_close_button.grab_focus()

func _card_texture() -> TextureRect:
	var card := TextureRect.new()
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = CARD_SIZE
	return card

func last_index() -> int:
	return maxi(0, hand_cards.size() - HAND_SLOTS)

func step(direction: int) -> void:
	card_index = clampi(card_index + direction, 0, last_index())
	_refresh()
	_snap(true)

func _refresh() -> void:
	previous_button.disabled = card_index <= 0
	next_button.disabled = card_index >= last_index()
	previous_button.visible = hand_cards.size() > HAND_SLOTS
	next_button.visible = hand_cards.size() > HAND_SLOTS
	progress.text = "%d–%d / %d" % [card_index + 1, mini(card_index + HAND_SLOTS, hand_cards.size()), hand_cards.size()] if hand_cards.size() > HAND_SLOTS else ""

func _snap(animated: bool) -> void:
	if is_instance_valid(_slide): _slide.kill()
	var target := -card_index * STEP
	if animated and visible:
		_slide = create_tween()
		_slide.tween_property(strip, "position:x", target, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		strip.position.x = target

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo: return
		match event.keycode:
			KEY_ESCAPE: close_modal()
			KEY_LEFT: step(-1)
			KEY_RIGHT: step(1)
			KEY_ENTER, KEY_SPACE:
				var focused := get_viewport().gui_get_focus_owner()
				if focused is Button and is_ancestor_of(focused) and not focused.disabled: focused.pressed.emit()
			KEY_TAB: _cycle_focus(event.shift_pressed)
		return
	var at := Vector2.ZERO
	var pressed := false
	var released := false
	var moving := false
	var pointer := -1
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		at = event.position
		moving = true
	elif event is InputEventScreenTouch:
		at = event.position
		pointer = event.index
		pressed = event.pressed and not event.canceled
		released = not event.pressed or event.canceled
	elif event is InputEventScreenDrag:
		at = event.position
		pointer = event.index
		moving = true
	else: return
	var local := viewport_area.get_global_transform_with_canvas().affine_inverse() * at
	if pressed and not _dragging and viewport_area.visible and Rect2(Vector2.ZERO, viewport_area.size).has_point(local):
		_dragging = true
		_pointer = pointer
		_origin = local
		_start_x = strip.position.x
		if is_instance_valid(_slide): _slide.kill()
	elif _dragging and pointer == _pointer:
		if moving: strip.position.x = clampf(_start_x + clampf(local.x - _origin.x, -STEP, STEP), -last_index() * STEP, 0.0)
		if released:
			_dragging = false
			var delta := local - _origin
			if absf(delta.x) >= 55 and absf(delta.x) > absf(delta.y) and not (event is InputEventScreenTouch and event.canceled):
				step(1 if delta.x < 0 else -1)
			else: _snap(true)
	else: return
	get_viewport().set_input_as_handled()

func _cycle_focus(reverse: bool) -> void:
	var buttons: Array[Control] = [_close_button]
	for button in [previous_button, next_button]:
		if button.visible and not button.disabled: buttons.append(button)
	var index := buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + (-1 if reverse else 1), buttons.size())].grab_focus()

func close_modal() -> void:
	_dragging = false
	if is_instance_valid(_slide): _slide.kill()
	super.close_modal()
