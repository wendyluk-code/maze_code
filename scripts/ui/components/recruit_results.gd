extends Control
## 只播放已保存快照；单一Tween统一取消，任何展示操作都不发奖。
signal closed
const Face = preload("res://scripts/ui/components/party_character_face.gd")
const Growth = preload("res://scripts/characters/character_progression.gd")
const Loot = preload("res://scripts/ui/components/loot_modal.gd")
var results: Array = []
var index := 0
var design: Control
var content: Control
var title: Label
var caption: Label
var draw_line: Label
var outcome_line: Label
var next_button: Button
var skip_button: Button
var loot: Loot
var overview := false
var flipping := false
var dust_shown := false
var flip: Tween
var stage := ""
var displayed_rank := 1
var current_face: Control
var grouped: Array[Dictionary] = []
var _generation := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = SproutTheme.make_theme()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.06, 0.04, 0.86)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.size = Vector2(1280, 720)
	add_child(design)
	title = _label("恭喜获得", Rect2(0, 16, 1280, 48), 32)
	content = Control.new()
	design.add_child(content)
	caption = _label("", Rect2(240, 458, 800, 36), 28)
	draw_line = _label("", Rect2(240, 502, 800, 30), 20)
	draw_line.add_theme_color_override("font_color", Color("#cbeeff"))
	outcome_line = _label("", Rect2(240, 510, 800, 36), 26)
	outcome_line.add_theme_color_override("font_color", Color("#ffe0a0"))
	next_button = _button("下一张", Rect2(0, 658, 160, 48), _advance)
	skip_button = _button("确认", Rect2(0, 658, 160, 48), _show_overview)
	loot = Loot.new()
	add_child(loot)
	loot._overlay.hide() # 共用父层遮罩，只保留宝箱原样奖励面板。
	loot.mouse_filter = Control.MOUSE_FILTER_IGNORE # 面板外的招募跳过按钮仍可点击。
	loot.closed.connect(_loot_closed)
	_warm_button(loot._confirm_button)
	# 奖励窗期间也能直接跳过十连，按钮位于其鼠标遮罩上层。
	design.z_index = 1
	loot.z_index = 2
	skip_button.z_index = 3
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	_layout()
	hide()

func _layout() -> void:
	var fit := minf(size.x / 1280.0, size.y / 720.0)
	design.scale = Vector2.ONE * fit
	design.position = (size - Vector2(1280, 720) * fit) * 0.5

func _label(text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SproutTheme.CREAM)
	design.add_child(label)
	return label

func _button(text: String, rect: Rect2, action: Callable) -> Button:
	var button := SproutButton.new()
	button.set_icon_visible(false).set_focus_visual(false)
	button.text = text
	button.position = rect.position
	design.add_child(button)
	button.custom_minimum_size = Vector2.ZERO
	button.size = rect.size
	_warm_button(button)
	button.pressed.connect(action)
	return button

func _buttons() -> void:
	if next_button.visible and skip_button.visible:
		var left := (1280.0 - next_button.size.x - skip_button.size.x - 32.0) / 2.0
		skip_button.position.x = left
		next_button.position.x = left + skip_button.size.x + 32.0
	elif next_button.visible:
		next_button.position.x = (1280.0 - next_button.size.x) / 2.0
	elif skip_button.visible:
		skip_button.position.x = (1280.0 - skip_button.size.x) / 2.0

func present(saved_results: Array) -> void:
	_clear()
	results = saved_results.duplicate(true)
	index = 0
	overview = false
	if results.is_empty(): return
	show()
	_show_card()

func _clear() -> void:
	_generation += 1
	if is_instance_valid(flip): flip.kill()
	flipping = false
	if is_instance_valid(loot): loot.hide()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	current_face = null
	draw_line.hide()
	outcome_line.hide()

func _visibility_changed() -> void:
	if not visible and is_instance_valid(content): _clear()

func _exit_tree() -> void:
	if is_instance_valid(flip): flip.kill()

func _face(result: Dictionary, at: Vector2, factor: float) -> Control:
	var face := Face.new()
	content.add_child(face)
	face.configure(result.id, int(result.rank))
	face.scale = Vector2.ONE * factor
	face.position = at
	return face

func _show_card() -> void:
	_clear()
	dust_shown = false
	var result: Dictionary = results[index]
	current_face = _face({"id": result.id, "rank": 1}, Vector2(536.6, 125), 0.44)
	displayed_rank = 1
	stage = "enter"
	title.text = "恭喜获得"
	title.show()
	caption.hide()
	caption.text = Growth.CHARACTERS[result.id].name
	draw_line.text = ""
	outcome_line.text = ""
	next_button.show()
	next_button.disabled = true
	next_button.text = "确认" if index == results.size() - 1 else "下一张"
	skip_button.visible = results.size() > 1
	_buttons()
	flipping = true
	var generation := _generation
	flip = create_tween()
	# 同一补间链：纸纹卡背收拢后展开正面，再依次显示文字。
	current_face.hide()
	var back := TextureRect.new()
	back.texture = preload("res://scripts/ui/components/bag_icon_display.gd").texture(preload("res://assets/ui/recruitment/card_back_sprout.png"))
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back.position = Vector2(536.6,125)
	back.size = Vector2(206.8,316.8)
	back.pivot_offset = back.size * 0.5
	content.add_child(back)
	current_face.pivot_offset = Vector2(235,360)
	current_face.position -= current_face.pivot_offset * 0.56
	current_face.scale.x = 0.0
	flip.tween_interval(0.2)
	flip.tween_property(back,"scale:x",0.0,0.25)
	flip.tween_callback(func():
		back.hide()
		current_face.show())
	flip.tween_property(current_face,"scale:x",0.44,0.25)
	caption.modulate.a = 0.0
	outcome_line.modulate.a = 0.0
	flip.tween_callback(func():
		stage = "name"
		caption.show())
	flip.tween_property(caption, "modulate:a", 1.0, 0.4)
	flip.tween_interval(0.2)
	flip.tween_callback(func():
		if generation != _generation: return
		displayed_rank = int(result.rank)
		current_face.display_rank(displayed_rank)
		stage = "upgrade"
		outcome_line.text = "升至%d星" % displayed_rank
		outcome_line.show())
	flip.tween_property(outcome_line, "modulate:a", 1.0, 0.4)
	flip.tween_interval(0.35)
	if result.kind == "stardust":
		flip.tween_callback(func(): stage = "flipping")
		flip.tween_property(current_face, "scale:x", 0.0, 0.3)
		flip.tween_callback(func():
			if generation == _generation: _show_dust(result))
		return
	flip.tween_callback(func():
		if generation != _generation: return
		stage = "ready"
		flipping = false
		next_button.disabled = false
		next_button.grab_focus())

func _show_dust(result: Dictionary) -> void:
	current_face.hide()
	caption.hide()
	draw_line.hide()
	outcome_line.hide()
	title.hide()
	next_button.hide()
	flipping = false
	dust_shown = true
	stage = "dust"
	loot.show_items([{"name": "星尘", "quantity": int(result.stardust), "icon": preload("res://assets/ui/recruitment/stardust.png")}])
	# 调用方已有标题接口；不扩展或改变公共宝箱默认行为。
	loot.show_modal("恭喜获得", "", "收下")
	_buttons()

func _loot_closed() -> void:
	if visible and stage == "dust" and not overview: _advance()

func _advance() -> void:
	if not visible or flipping: return
	if overview or results.size() == 1:
		hide()
		closed.emit()
		return
	if index == results.size() - 1: _show_overview()
	else:
		index += 1
		_show_card()

static func aggregate(saved_results: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var positions: Dictionary = {}
	for result in saved_results:
		var id: String = result.id
		if not positions.has(id):
			positions[id] = entries.size()
			entries.append({"id": id, "rank": 1, "count": 0, "duplicates": 0, "stardust": 0})
		var entry: Dictionary = entries[positions[id]]
		entry.rank = maxi(int(entry.rank), int(result.rank))
		entry.count += 1
		entry.duplicates += 0 if result.kind == "new" else 1
		entry.stardust += int(result.stardust)
	return entries

func _show_overview() -> void:
	if not visible: return
	_clear()
	overview = true
	stage = "overview"
	title.text = "恭喜获得"
	title.show()
	caption.hide()
	skip_button.hide()
	next_button.show()
	next_button.disabled = false
	next_button.text = "确认"
	_buttons()
	grouped = _overview_entries()
	var count := grouped.size()
	var factor := 0.22 if count > 5 else (0.44 if count <= 3 else 0.38)
	var spacing := 310.0 if count <= 3 else 240.0
	var width := (count - 1) * spacing + 470.0 * factor
	for i in count:
		var entry: Dictionary = grouped[i]
		var at := Vector2((1280.0 - width) * 0.5 + i * spacing, 125)
		if count > 5:
			var row_count := mini(5, count - (i / 5) * 5)
			var row_width := (row_count - 1) * 240.0 + 470.0 * factor
			at = Vector2((1280.0 - row_width) * 0.5 + (i % 5) * 240.0, 76 + (i / 5) * 280)
		_face(entry, at, factor)
		_summary(entry, Vector2(at.x + 470.0 * factor * 0.5, at.y + 720 * factor + 10), count > 5)

	next_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if overview: _advance()
		else: _show_overview()

func _overview_entries() -> Array[Dictionary]:
	return aggregate(results)

func _warm_button(button: SproutButton) -> void:
	button.set_focus_visual(false)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set_icon_visible(false)
	button.add_theme_constant_override("h_separation", 0)
	for state in ["normal", "hover", "pressed"]:
		var color := SproutTheme.PANEL
		if state == "hover": color = Color("#ffe3a3")
		if state == "pressed": color = Color("#c99a54")
		button.add_theme_stylebox_override(state, SproutTheme.button_style(color))

func _summary(entry: Dictionary, center: Vector2, compact: bool) -> void:
	var box := VBoxContainer.new()
	box.position = center - Vector2(115, 0)
	box.size = Vector2(230, 0)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(box)
	var rank_label := Label.new()
	rank_label.name = "Rank"
	rank_label.text = "升至%d星" % entry.rank
	rank_label.add_theme_font_size_override("font_size", 24 if compact else 28)
	rank_label.add_theme_color_override("font_color", Color("#ffe0a0"))
	box.add_child(rank_label)
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.text = "本次获得%d张 · 重复%d次" % [entry.count,entry.duplicates]
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", SproutTheme.CREAM)
	box.add_child(count_label)
	for label in [rank_label,count_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", SproutTheme.FONT_CN)
		label.add_theme_color_override("font_outline_color", Color("#56351e"))
		label.add_theme_constant_override("outline_size", 3)
	if entry.stardust > 0:
		var row := HBoxContainer.new()
		row.name = "Dust"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var icon := TextureRect.new()
		icon.texture = preload("res://scripts/ui/components/bag_icon_display.gd").texture(preload("res://assets/ui/recruitment/stardust.png"))
		icon.custom_minimum_size = Vector2(24,24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var amount := Label.new()
		amount.text = "+%d" % entry.stardust
		amount.add_theme_font_override("font", SproutTheme.FONT_CN)
		amount.add_theme_font_size_override("font_size", 22)
		amount.add_theme_color_override("font_color", Color("#a4e6ff"))
		amount.add_theme_color_override("font_outline_color", Color("#244b66"))
		amount.add_theme_constant_override("outline_size", 3)
		row.add_child(amount)
