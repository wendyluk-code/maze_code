extends Control
## CH1-10A 卡牌占位预览：独立场景，仅展示视觉组件和输入契约。

const DATA := preload("res://scripts/ui/components/sprout_card_data.gd")
const CARD := preload("res://scripts/ui/components/sprout_card.gd")

var _cards: Array[SproutCardData] = []
var _faction_index := 0
var _card_index := 0
var _card: SproutCard
var _progress: Label
var _hint: Label
var _sprout_button: SproutButton
var _tieshan_button: SproutButton
var _index_buttons: Array[SproutButton] = []
var _capture_path := ""

func _ready() -> void:
	theme = SproutTheme.make_theme()
	_cards = DATA.placeholder_set()
	_build()
	var args := OS.get_cmdline_args()
	var faction_arg := args.find("--card-preview-faction")
	if faction_arg >= 0 and faction_arg + 1 < args.size():
		_faction_index = 1 if args[faction_arg + 1].to_lower() == "tieshan" else 0
	var index_arg := args.find("--card-preview-index")
	if index_arg >= 0 and index_arg + 1 < args.size():
		_card_index = clampi(int(args[index_arg + 1]) - 1, 0, 7)
	_show_card()
	var capture_index := args.find("--card-preview-capture")
	if capture_index >= 0 and capture_index + 1 < args.size():
		_capture_path = args[capture_index + 1]
		_capture_after_render.call_deferred()

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("#294236")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := PanelContainer.new()
	header.custom_minimum_size.y = 76
	header.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff4dc")))
	page.add_child(header)
	var header_box := VBoxContainer.new()
	header.add_child(header_box)
	var heading := Label.new()
	heading.text = "CH1-10A · Sprout Lands 卡牌占位预览"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", SproutTheme.INK)
	_header_box_add(header_box, heading)
	_hint = Label.new()
	_hint.text = "所有名称、费用、类型、效果、数值与稀有度均为待配置占位内容"
	_hint.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	_header_box_add(header_box, _hint)

	var faction_row := HBoxContainer.new()
	faction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	faction_row.add_theme_constant_override("separation", 12)
	page.add_child(faction_row)
	_sprout_button = _make_button("芽芽 · 辅助", 0)
	_tieshan_button = _make_button("铁山 · 守卫", 1)
	_sprout_button.pressed.connect(func() -> void: _set_faction(0))
	_tieshan_button.pressed.connect(func() -> void: _set_faction(1))
	faction_row.add_child(_sprout_button)
	faction_row.add_child(_tieshan_button)

	var card_row := HBoxContainer.new()
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 28)
	page.add_child(card_row)
	var previous := _make_button("上一张", 2)
	previous.custom_minimum_size = Vector2(150, 54)
	previous.pressed.connect(func() -> void: _step(-1))
	card_row.add_child(previous)
	_card = CARD.new()
	card_row.add_child(_card)
	var next := _make_button("下一张", 3)
	next.custom_minimum_size = Vector2(150, 54)
	next.pressed.connect(func() -> void: _step(1))
	card_row.add_child(next)

	var index_row := HBoxContainer.new()
	index_row.alignment = BoxContainer.ALIGNMENT_CENTER
	index_row.add_theme_constant_override("separation", 6)
	page.add_child(index_row)
	for index in range(8):
		var button := _make_button("%02d" % (index + 1), 4)
		button.pressed.connect(func(i := index) -> void:
			_card_index = i
			_show_card()
		)
		_index_buttons.append(button)
		index_row.add_child(button)
		button.custom_minimum_size = Vector2(70, 42)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 18)
	_progress.add_theme_color_override("font_color", Color("#fff4dc"))
	page.add_child(_progress)
	var input_hint := Label.new()
	input_hint.text = "操作：点击按钮，或使用 ←/→ 翻页；1–8 直接跳转卡牌"
	input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_hint.add_theme_color_override("font_color", Color("#d8ead2"))
	page.add_child(input_hint)

func _header_box_add(box: VBoxContainer, node: Control) -> void:
	box.add_child(node)

func _make_button(text: String, icon: int) -> SproutButton:
	var button := SproutButton.new()
	button.configure(text, icon)
	button.set_focus_visual(false)
	return button

func _set_faction(value: int) -> void:
	_faction_index = value
	_card_index = 0
	_show_card()

func _step(delta: int) -> void:
	_card_index = posmod(_card_index + delta, 8)
	_show_card()

func _show_card() -> void:
	if not is_instance_valid(_card):
		return
	var data := _cards[_faction_index * 8 + _card_index]
	_card.configure(data)
	_progress.text = "%s · %s · 第 %d / 8 张" % [data.character_name, data.role, data.number]
	_sprout_button.disabled = _faction_index == 0
	_tieshan_button.disabled = _faction_index == 1
	for i in range(_index_buttons.size()):
		_index_buttons[i].disabled = i == _card_index

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_step(1)
		elif event.keycode == KEY_LEFT:
			_step(-1)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			_card_index = event.keycode - KEY_1
			_show_card()

func _capture_after_render() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(_capture_path)
	if result != OK:
		push_error("CARD_PREVIEW_CAPTURE_FAILED path=%s error=%d" % [_capture_path, result])
		get_tree().quit(1)
		return
	print("CARD_PREVIEW_CAPTURE_OK path=%s size=%dx%d" % [_capture_path, image.get_width(), image.get_height()])
	get_tree().quit()
