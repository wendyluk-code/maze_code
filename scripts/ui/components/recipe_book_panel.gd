extends Control
## 只读食谱组件。调用方提供展示数据；不访问经营单例，不写存档。
signal closed
const ModalStyle := preload("res://scripts/ui/components/modal_style.gd")
var rows: Array[Control] = []
var dish_targets: Array[Button] = []
var ingredient_targets: Array[Button] = []
var panel: PanelContainer
var scroll: ScrollContainer
var listing: VBoxContainer
var hint: PanelContainer
var hint_text: Label
var hint_title: Label
var close_button: Button
const Counter := preload("res://scripts/ui/components/resource_counter.gd")
const CATEGORIES := ["全部"]
var tabs: TabBar
var _entries: Array = []
var _anchor: Control
var _display_textures: Dictionary = {}

func display_texture(texture: Texture2D) -> Texture2D:
	# 正式素材与预览使用同一透明留白处理，不改源图或其他界面。
	if texture == null: return null
	if _display_textures.has(texture): return _display_textures[texture]
	var image := texture.get_image()
	if image == null or image.is_empty(): return texture
	# 原料理图存在极低透明度杂点；以可见轮廓定位，仍保留区域内原像素。
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.1:
				minimum = minimum.min(Vector2i(x, y))
				maximum = maximum.max(Vector2i(x, y))
	if maximum.x < 0: return texture
	var region := Rect2i(minimum, maximum - minimum + Vector2i.ONE).grow(3).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if not region.has_area(): return texture
	var result := ImageTexture.create_from_image(image.get_region(region))
	_display_textures[texture] = result
	return result

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = SproutTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = ModalStyle.BACKDROP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style(SproutTheme.PANEL))
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var heading := label("食谱", 32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	close_button = ModalStyle.close_button()
	# 奶油底上的关闭叉号使用深棕色，悬停保持清晰对比。
	close_button.add_theme_color_override("font_color", SproutTheme.INK)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		close_button.add_theme_color_override(state, Color("#402813"))
	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = Color("#e6c38c")
	close_hover.set_corner_radius_all(8)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, close_hover)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var table := PanelContainer.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table_style := SproutTheme.thin_panel_style()
	table_style.set_content_margin_all(2)
	table.add_theme_stylebox_override("panel", table_style)
	body.add_child(table)
	var table_body := VBoxContainer.new()
	table_body.add_theme_constant_override("separation", 0)
	table.add_child(table_body)
	tabs = preload("res://scripts/ui/components/sprout_tab_bar.gd").new()
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	tabs.custom_minimum_size.y = 26
	for category in CATEGORIES: tabs.add_tab(category)
	table_body.add_child(tabs)
	tabs.tab_changed.connect(func(_index): _render_recipes())
	var columns := HBoxContainer.new()
	var column_frame := PanelContainer.new()
	var column_style := SproutTheme.thin_panel_style()
	column_style.set_border_width_all(0)
	column_style.border_width_bottom = 1
	column_style.set_corner_radius_all(0)
	column_style.content_margin_top = 10
	column_style.content_margin_bottom = 10
	column_style.content_margin_right = 30
	column_frame.add_theme_stylebox_override("panel", column_style)
	table_body.add_child(column_frame)
	column_frame.add_child(columns)
	columns.add_theme_constant_override("separation", 20)
	var dish := label("料理", 17)
	dish.custom_minimum_size.x = 380
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columns.add_child(dish)
	var ingredients := label("所需食材", 17)
	ingredients.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ingredients.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columns.add_child(ingredients)
	var price := label("售价", 17)
	price.custom_minimum_size.x = 160
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columns.add_child(price)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	table_body.add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.add_theme_constant_override("separation", 0)
	scroll.add_child(listing)
	hint = PanelContainer.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style())
	add_child(hint)
	hint.z_index = 20
	var hint_column := VBoxContainer.new()
	hint_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(hint_column)
	hint_title = label("", 18, Color("#4e7839"))
	hint_column.add_child(hint_title)
	hint_text = label("", 18)
	hint_text.custom_minimum_size.x = 268
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_column.add_child(hint_text)
	hint.hide()
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): dismiss_hint())
	resized.connect(_layout)
	_layout()

func label(value: String, font_size: int, color := SproutTheme.INK) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _layout() -> void:
	if panel == null: return
	panel.size = Vector2(minf(1060, size.x - 64), minf(606, size.y - 48))
	panel.position = (size - panel.size) * 0.5
	dismiss_hint()

func set_recipes(entries: Array) -> void:
	_entries = entries
	_render_recipes()

func _render_recipes() -> void:
	scroll.scroll_vertical = 0
	dismiss_hint()
	for child in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	rows.clear()
	dish_targets.clear()
	ingredient_targets.clear()
	for entry in _entries:
		var row := PanelContainer.new()
		var row_style := SproutTheme.thin_panel_style()
		row_style.set_corner_radius_all(0)
		row_style.set_border_width_all(0)
		row_style.border_width_bottom = 1
		row_style.border_color = Color("#dfcba5")
		row.add_theme_stylebox_override("panel", row_style)
		listing.add_child(row)
		rows.append(row)
		var line := HBoxContainer.new()
		line.custom_minimum_size.y = 118
		line.add_theme_constant_override("separation", 20)
		row.add_child(line)
		var dish_area := HBoxContainer.new()
		dish_area.custom_minimum_size.x = 380
		dish_area.add_theme_constant_override("separation", 14)
		line.add_child(dish_area)
		var identity := VBoxContainer.new()
		identity.custom_minimum_size.x = 174
		dish_area.add_child(identity)
		var dish := Button.new()
		dish.icon = display_texture(entry.icon)
		dish.expand_icon = true
		dish.add_theme_constant_override("icon_max_width", 88)
		dish.custom_minimum_size = Vector2(100, 86)
		dish.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for state in ["normal", "pressed"]:
			dish.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		dish.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		dish.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		dish.focus_mode = Control.FOCUS_NONE
		dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
		identity.add_child(dish)
		dish.set_meta("recipe_id", str(entry.id))
		dish_targets.append(dish)
		var name_label := label(entry.name, 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity.add_child(name_label)
		var effect := label(str(entry.get("description", "")), 17, SproutTheme.INK_MUTED)
		effect.name = "DishEffect"
		effect.custom_minimum_size.x = 180
		effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dish_area.add_child(effect)
		var materials := HBoxContainer.new()
		materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		materials.alignment = BoxContainer.ALIGNMENT_CENTER
		materials.add_theme_constant_override("separation", 12)
		line.add_child(materials)
		for index in entry.ingredients.size():
			var material := Control.new()
			material.custom_minimum_size = Vector2(120, 88)
			material.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			materials.add_child(material)
			var item: Dictionary = entry.ingredients[index]
			var slot := SproutItemSlot.new()
			slot.set_grid_mode(true)
			slot.configure(item.id, item.name, item.quantity, 0)
			slot.set_icon_texture(display_texture(item.icon))
			material.add_child(slot)
			slot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			slot.offset_left = -28
			slot.offset_right = 28
			slot._icon_button.tooltip_text = ""
			slot._icon_button.set_meta("ingredient_id", str(item.id))
			slot._icon_button.set_meta("recipe_id", str(entry.id))
			ingredient_targets.append(slot._icon_button)
			bind_hint(slot._icon_button, str(item.name) + "\n获取方式：" + str(item.source).trim_prefix("获取方式：").trim_prefix("获取："))
			var item_name := label("%s ×%d" % [item.name, item.quantity], 17)
			material.add_child(item_name)
			item_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			item_name.offset_top = 60
			item_name.offset_bottom = 88
			item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var reward := Counter.new()
		reward.custom_minimum_size.x = 160
		reward.alignment = BoxContainer.ALIGNMENT_CENTER
		reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		reward.configure(Counter.GOLD)
		reward.set_value(entry.gold)
		reward.value_label.add_theme_color_override("font_color", SproutTheme.INK)
		reward.value_label.add_theme_constant_override("outline_size", 0)
		reward.value_label.add_theme_constant_override("shadow_offset_x", 0)
		reward.value_label.add_theme_constant_override("shadow_offset_y", 0)
		reward.value_label.add_theme_font_size_override("font_size", 24)
		line.add_child(reward)
		if entry.get("uses",["订单"])==["探索"]:
			reward.hide()
			var category := label("探索 · "+str(entry.get("exploration_category","")),18)
			category.custom_minimum_size.x=160
			category.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			line.add_child(category)

func bind_hint(target: Button, text: String) -> void:
	target.mouse_entered.connect(func(): show_hint(target, text))
	target.mouse_exited.connect(dismiss_hint)

func show_hint(target: Control, text: String) -> void:
	if not is_visible_in_tree(): return
	_anchor = target
	var parts := text.split("\n", true, 1)
	hint_title.text = parts[0]
	hint_text.text = parts[1] if parts.size() > 1 else ""
	hint.size = Vector2(304, 0)
	hint.reset_size()
	var rect := target.get_global_rect()
	hint.position = Vector2(clampf(rect.end.x + 12, 12, size.x - hint.size.x - 12), clampf(rect.position.y, 12, size.y - hint.size.y - 12))
	hint.show()

func dismiss_hint() -> void:
	if is_instance_valid(hint): hint.hide()
	_anchor = null

func close() -> void:
	dismiss_hint()
	hide()
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
