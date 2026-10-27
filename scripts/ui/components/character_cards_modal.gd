extends SproutModal
## 按拥有ID筛选的角色卡牌蒙层；不解锁卡牌、不写存档。
const DATA := preload("res://scripts/ui/components/sprout_card_data.gd")
const CARD := preload("res://scripts/ui/components/sprout_card.gd")
const CARD_SIZE := Vector2(300, 500)
const STEP := 330.0
var character_id := ""
var cards: Array[SproutCardData] = []
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
var _presentation := 0

func _build() -> void:
	theme = SproutTheme.make_theme()
	_overlay = ColorRect.new()
	_overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	design = Control.new()
	design.size = Vector2(1280, 720)
	add_child(design)
	var panel := Panel.new()
	panel.position = Vector2(48, 36)
	panel.size = Vector2(1184, 648)
	panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style())
	design.add_child(panel)
	_title_label = _label("", Vector2(120, 58), Vector2(1040, 44), 28)
	_close_button = preload("res://scripts/ui/components/modal_style.gd").close_button()
	design.add_child(_close_button)
	_close_button.position = Vector2(1144, 54)
	_close_button.size = Vector2(56, 48)
	_close_button.tooltip_text = "关闭卡牌"
	_close_button.pressed.connect(close_modal)
	viewport_area = Control.new()
	viewport_area.position = Vector2(88, 119)
	viewport_area.size = Vector2(1104, 464)
	viewport_area.clip_contents = true
	viewport_area.mouse_default_cursor_shape = Control.CURSOR_DRAG
	design.add_child(viewport_area)
	strip = Control.new()
	viewport_area.add_child(strip)
	empty_label = _label("尚未拥有该角色的卡牌", Vector2(200, 290), Vector2(880, 72), 25)
	previous_button = _button("← 上一张", Vector2(240, 610), Vector2(170, 48))
	next_button = _button("下一张 →", Vector2(870, 610), Vector2(170, 48))
	previous_button.pressed.connect(func(): step(-1))
	next_button.pressed.connect(func(): step(1))
	progress = _label("", Vector2(425, 595), Vector2(430, 40), 21)
	_label("左右滑动查看卡牌", Vector2(425, 637), Vector2(430, 28), 17)
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
	label.add_theme_color_override("font_color", SproutTheme.INK)
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

static func owned_cards(id: String, state: Dictionary) -> Array[SproutCardData]:
	var result: Array[SproutCardData] = []
	if not state.get("unlocked", false): return result
	var ids: Array = state.get("card_ids", [])
	for card in DATA.formal_set():
		if card.id.begins_with(id + "_") and ids.has(card.id): result.append(card)
	return result

func present(id: String, state: Dictionary) -> void:
	_presentation += 1
	character_id = id
	cards = owned_cards(id, state)
	card_index = 0
	_dragging = false
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	for index in cards.size():
		var card := CARD.new()
		card.configure(cards[index])
		strip.add_child(card)
		card.size = CARD_SIZE
		card.position = Vector2(index * STEP, 4)
		_ignore_mouse(card)
	_title_label.text = ("芽芽" if id == "yaya" else "铁山") + " · 我的卡牌"
	empty_label.visible = cards.is_empty()
	viewport_area.visible = not cards.is_empty()
	strip.modulate.a = 0.0
	_refresh()
	_snap(false)
	show()
	_close_button.grab_focus()
	_settle_cards(_presentation)

func _settle_cards(version: int) -> void:
	# 自动换行的最小高度在容器获得宽度后才稳定，重新收合初始布局撑开的高度。
	for pass_index in 8:
		await get_tree().process_frame
		if version != _presentation: return
		for card in strip.get_children(): card.size = CARD_SIZE
	for index in strip.get_child_count():
		var card: Control = strip.get_child(index)
		var fit := minf(1.0, 456.0 / card.size.y)
		card.scale = Vector2.ONE * fit
		card.position = Vector2(index * STEP + (CARD_SIZE.x - card.size.x * fit) * 0.5, 4)
	await get_tree().process_frame
	if version == _presentation: strip.modulate.a = 1.0

func _ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)

func step(direction: int) -> void:
	card_index = clampi(card_index + direction, 0, maxi(0, cards.size() - 1))
	_refresh()
	_snap(true)

func _refresh() -> void:
	previous_button.disabled = card_index <= 0
	next_button.disabled = card_index >= cards.size() - 1
	progress.text = "已拥有 %d 张" % cards.size() if cards.is_empty() else "%d / %d · %s" % [card_index + 1, cards.size(), cards[card_index].title]

func _snap(animated: bool) -> void:
	if is_instance_valid(_slide): _slide.kill()
	var target := (1104.0 - CARD_SIZE.x) * 0.5 - card_index * STEP
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
		if moving: strip.position.x = _start_x + clampf(local.x - _origin.x, -STEP, STEP)
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
		if not button.disabled: buttons.append(button)
	var index := buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + (-1 if reverse else 1), buttons.size())].grab_focus()

func close_modal() -> void:
	_dragging = false
	if is_instance_valid(_slide): _slide.kill()
	super.close_modal()
