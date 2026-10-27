extends "res://scripts/ui/components/destination_confirmation.gd"
## 入口仅维护草稿；入场、体力及记忆仍由原保存事务负责。
const Progression := preload("res://scripts/characters/character_progression.gd")
const Details := preload("res://scripts/ui/components/character_details_modal.gd")
const Catalog := preload("res://data/maze/capture_catalog.gd")
const SkillList := preload("res://scripts/ui/components/team_entry_skill_list.gd")
const Chart := preload("res://scripts/ui/components/team_entry_element_chart.gd")
const ModalStyle := preload("res://scripts/ui/components/modal_style.gd")
const Run := preload("res://scripts/maze/capture_run.gd")
const FILTERS := ["", "grass", "earth", "thunder", "water", "wind", "fire"]
var selected: Array = []
var slots: Array[Button] = []
var mini_slots: Array[Button] = []
var slot_names: Array[Button] = []
var slot_name_labels: Array[Label] = []
var slot_level_labels: Array[Label] = []
var slot_stats: Array[Label] = []
var checks: Dictionary = {}
var name_buttons: Dictionary = {}
var portrait_buttons: Dictionary = {}
var row_panels: Dictionary = {}
var food_labels: Dictionary = {}
var team_panel: PanelContainer
var selector: ColorRect
var selection_panel: PanelContainer
var details: Control
var power_value: Label
var health_value: Label
var defense_value: Label
var selection_totals: Array[Label] = []
var food_value: Label
var warning: Label
var skills_text: VBoxContainer
var basic_content: VBoxContainer
var skills_scroll: ScrollContainer
var skill_count: Label
var selection_notice: Label
var selection_done: Button
var selection_rows: VBoxContainer
var selection_scroll: ScrollContainer
var tabs: TabBar
var chart: Control
var team_count: Label
var selection_count: Label
var close_button: Button
var selection_close: Button
var recommendations: Array = []
var _original_center: Control
var _original_column: Node
var _original_actions: Node
var _team_column: Node
var _team_actions: Node
var _return_focus: Control
var _team_mode := false
var _timer := 0.0

func _ready() -> void:
	super._ready()
	_original_center = get_child(0)
	_original_column = _cost_row.get_parent()
	_original_actions = cancel_button.get_parent()
	team_panel = _panel_box(self)
	var column := _column(team_panel, 8)
	var heading := _header(column, "探索准备")
	close_button = heading.close
	close_button.pressed.connect(func(): cancelled.emit())
	var recommended := HBoxContainer.new()
	recommended.add_theme_constant_override("separation", 18)
	column.add_child(recommended)
	recommended.add_child(_label("当前区域推荐", 18, SproutTheme.INK_MUTED))
	recommendations = region_recommendations(Catalog.all())
	for element in recommendations:
		var item := HBoxContainer.new()
		recommended.add_child(item)
		item.add_child(_icon(_element_texture(element), 24))
		item.add_child(_label(Catalog.ELEMENTS[element] + "系", 17, SproutTheme.INK_MUTED))
	var cream := _cream(column)
	var body := _column(cream, 6)
	var team_heading := HBoxContainer.new()
	body.add_child(team_heading)
	var title := _label("本次队伍", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_heading.add_child(title)
	team_count = _label("", 18, SproutTheme.INK_MUTED)
	team_heading.add_child(team_count)
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 32)
	body.add_child(slot_row)
	for i in 4:
		var identity := _column(slot_row, 4)
		identity.custom_minimum_size.x = 156
		var slot := _slot(identity, 64)
		slot.pressed.connect(_open_selector)
		slots.append(slot)
		var name_button := Button.new()
		identity.add_child(name_button)
		name_button.custom_minimum_size = Vector2(72, 26)
		_flat_button(name_button)
		name_button.pressed.connect(func():
			if i < selected.size(): _show_details(str(selected[i]), name_button))
		slot_names.append(name_button)
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_button.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var caption := HBoxContainer.new()
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_constant_override("separation", 8)
		center.add_child(caption)
		var name_label := _label("", 20, SproutTheme.INK)
		caption.add_child(name_label)
		slot_name_labels.append(name_label)
		var level_label := _label("", 14, SproutTheme.INK_MUTED)
		level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caption.add_child(level_label)
		slot_level_labels.append(level_label)
		var stats := _label("", 16, SproutTheme.INK_MUTED)
		stats.custom_minimum_size.x = 156
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.hide()
		identity.add_child(stats)
		slot_stats.append(stats)
	body.add_child(_rule())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var basic := _column(columns, 12)
	basic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic.size_flags_stretch_ratio = 0.8
	var basic_title := _label("基础属性", 22)
	basic_title.custom_minimum_size.y = 28
	basic.add_child(basic_title)
	basic_content = _column(basic, 12)
	power_value = _stat_row(basic_content, "总攻击", "attack")
	health_value = _stat_row(basic_content, "总生命", "health_syringe")
	defense_value = _stat_row(basic_content, "总防御", "defense")
	food_value = _stat_row(basic_content, "饱腹", "satiety")
	warning = _label("当前团队饱腹度为0，将无法捕获任何魔物食材", 17, Color("#b52e29"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	basic_content.add_child(warning)
	columns.add_child(_rule(true))
	var attributes := _column(columns, 12)
	attributes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var attribute_title := _label("队伍属性", 22)
	attribute_title.custom_minimum_size.y = 28
	attributes.add_child(attribute_title)
	chart = Chart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attributes.add_child(chart)
	chart.custom_minimum_size.y = 160
	columns.add_child(_rule(true))
	var skills := _column(columns, 12)
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skills_header := HBoxContainer.new()
	skills_header.custom_minimum_size.y = 28
	skills.add_child(skills_header)
	var skills_title := _label("技能加成", 22)
	skills_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_header.add_child(skills_title)
	skill_count = _label("", 16, SproutTheme.INK_MUTED)
	skills_header.add_child(skill_count)
	# 为滚动条保留同等宽度，使计数右边界与正文一致。
	var reserve := Control.new()
	reserve.custom_minimum_size.x = 6
	skills_header.add_child(reserve)
	skills_scroll = ScrollContainer.new()
	skills_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skills_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	skills_scroll.custom_minimum_size.y = 145
	skills_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills.add_child(skills_scroll)
	skills_text = SkillList.new()
	skills_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_text.custom_minimum_size.y = 145
	skills_scroll.add_child(skills_text)
	_style_scroll(skills_scroll.get_v_scroll_bar())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	column.add_child(footer)
	_team_column = footer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 20)
	footer.add_child(actions)
	_team_actions = actions
	selector = ColorRect.new()
	selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selector.color = Color.TRANSPARENT
	add_child(selector)
	selection_panel = _panel_box(selector)
	var list_column := _column(selection_panel, 14)
	var selection_header := _header(list_column, "选择角色")
	selection_count = _label("", 18, SproutTheme.INK_MUTED)
	selection_header.row.add_child(selection_count)
	selection_header.row.move_child(selection_count, 1)
	selection_close = selection_header.close
	selection_close.pressed.connect(_close_selector)
	var table := _cream(list_column)
	var table_style := SproutTheme.thin_panel_style()
	table_style.set_content_margin_all(2)
	table.add_theme_stylebox_override("panel", table_style)
	var table_body := _column(table, 0)
	tabs = preload("res://scripts/ui/components/sprout_tab_bar.gd").new()
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	tabs.focus_mode = Control.FOCUS_ALL
	for category in ["全部", "草系", "土系", "雷系", "水系", "风系", "火系"]: tabs.add_tab(category)
	table_body.add_child(tabs)
	tabs.tab_changed.connect(func(_index): _render_rows())
	var header_frame := MarginContainer.new()
	header_frame.add_theme_constant_override("margin_left", 18)
	header_frame.add_theme_constant_override("margin_right", 28)
	header_frame.add_theme_constant_override("margin_top", 12)
	header_frame.add_theme_constant_override("margin_bottom", 12)
	table_body.add_child(header_frame)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	header_frame.add_child(header)
	for item in [["角色 / 等级", 0], ["攻击 / 生命 / 防御", 180], ["饱腹 / 上限", 160], ["入队", 130]]:
		var label := _label(item[0], 18, SproutTheme.INK_MUTED)
		label.custom_minimum_size.x = item[1]
		if item[1] == 0: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	selection_scroll = ScrollContainer.new()
	selection_scroll.name = "CharacterScroll"
	selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	table_body.add_child(selection_scroll)
	_style_scroll(selection_scroll.get_v_scroll_bar())
	selection_rows = _column(selection_scroll, 0)
	selection_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 24)
	list_column.add_child(summary)
	for title_text in ["总攻击", "总生命", "总防御", "饱腹 / 上限"]:
		var value := _label(title_text, 18)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_child(value)
		selection_totals.append(value)
	var selection_footer := HBoxContainer.new()
	selection_footer.add_theme_constant_override("separation", 14)
	list_column.add_child(selection_footer)
	selection_footer.add_child(_label("本次队伍", 18, SproutTheme.INK_MUTED))
	for i in 4:
		var mini := _slot(selection_footer, 44)
		mini.focus_mode = Control.FOCUS_NONE
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini_slots.append(mini)
	selection_notice = _label("最多携带4名角色", 18, SproutTheme.INK_MUTED)
	selection_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_footer.add_child(selection_notice)
	selection_done = SproutButton.new().configure("确认").set_icon_visible(false).set_focus_visual(false)
	selection_footer.add_child(selection_done)
	selection_done.custom_minimum_size = Vector2(184, 44)
	selection_done.add_theme_stylebox_override("normal", SproutTheme.selected_style())
	selection_done.pressed.connect(_close_selector)
	details = Details.new()
	add_child(details)
	details.closed.connect(_details_closed)
	selector.hide()
	team_panel.hide()
	resized.connect(_layout)
	# 首次载入已记忆的零饱腹队伍时，提示在列宽确定前会暂时逐字换行。
	# 容器最小高度收敛后重新应用目标尺寸，避免面板保留临时撑大的高度。
	team_panel.minimum_size_changed.connect(_layout.call_deferred)
	_layout()

func _column(parent: Node, separation: int) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

func _panel_box(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style(SproutTheme.PANEL))
	return panel

func _layout() -> void:
	if not is_instance_valid(selection_panel): return
	for panel in [team_panel, selection_panel]:
		panel.size = Vector2(minf(1060, size.x - 64), minf(624, size.y - 48))
		panel.position = (size - panel.size) * 0.5

func _cream(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style())
	parent.add_child(panel)
	return panel

func _header(parent: Node, value: String) -> Dictionary:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := _label(value, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close := ModalStyle.close_button()
	close.add_theme_color_override("font_color", SproutTheme.INK)
	row.add_child(close)
	return {"row": row, "close": close}

func _label(value: String, font_size := 20, color_value := SproutTheme.INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_value)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _rule(vertical := false) -> ColorRect:
	var node := ColorRect.new()
	node.color = Color("#dfcba5")
	node.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _icon(texture: Texture2D, dimension: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * dimension
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _stat_row(parent: Node, value: String, icon_name: String) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var stat_icon := _icon(null if icon_name.is_empty() else load("res://assets/ui/character_details/%s.png" % icon_name), 24)
	if icon_name == "health_syringe":
		var cropped := AtlasTexture.new()
		cropped.atlas = stat_icon.texture
		cropped.region = stat_icon.texture.get_image().get_used_rect()
		stat_icon.texture = cropped
	stat_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(stat_icon)
	var label := _label(value, 18, SproutTheme.INK_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var amount := _label("0", 26)
	row.add_child(amount)
	return amount

func _slot(parent: Node, dimension: int) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.custom_minimum_size = Vector2.ONE * dimension
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 30)
	var style := SproutTheme.thin_panel_style(Color("#f6e9cd"))
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _flat_button(button: Button) -> void:
	for state in ["normal", "pressed", "hover", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_pressed_color", SproutTheme.INK)

func _style_scroll(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#ead9b7")
	track.set_corner_radius_all(5)
	track.content_margin_left = 5
	track.content_margin_right = 5
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var style := track.duplicate() as StyleBoxFlat
		style.bg_color = Color("#b39a6b")
		bar.add_theme_stylebox_override(state, style)
	for icon_name in ["increment", "decrement", "increment_highlight", "decrement_highlight", "increment_pressed", "decrement_pressed"]:
		bar.add_theme_icon_override(icon_name, ImageTexture.new())

static func canonical_element(id: String) -> String:
	return "thunder" if id == "lightning" else id

static func region_recommendations(monsters: Array) -> Array:
	var counts := {}
	for row in monsters:
		var target := canonical_element(str(row.get("element", "")))
		for element in Catalog.COUNTERS:
			if Catalog.COUNTERS[element] == target: counts[element] = int(counts.get(element, 0)) + 1
	# 字典顺序沿用捕获配置：火、草、土、雷、水、风；并列不依赖排序稳定性。
	var order: Array = Catalog.ELEMENTS.keys()
	order.sort_custom(func(a, b):
		var first := int(counts.get(a, 0))
		var second := int(counts.get(b, 0))
		return first > second if first != second else Catalog.ELEMENTS.keys().find(a) < Catalog.ELEMENTS.keys().find(b))
	return order.filter(func(id): return counts.get(id, 0) > 0).slice(0, 2)

func _element_texture(id: String) -> Texture2D:
	return load("res://assets/ui/factions/%s.png" % ("lightning" if canonical_element(id) == "thunder" else id))

# 只读查询独立封装，隔离验收可覆盖这些查询，不修改生产角色或存档契约。
func _owned() -> Array:
	return SaveManager.owned_characters()

func _config(id: String) -> Dictionary:
	return Progression.CHARACTERS.get(id, {})

func _record(id: String) -> Dictionary:
	return Progression.record(SaveManager, id)

func _food_snapshot() -> Dictionary:
	return Progression.satiety_snapshot(SaveManager)

func _mount_shared_controls(team_mode: bool) -> void:
	var column := _team_column if team_mode else _original_column
	var actions := _team_actions if team_mode else _original_actions
	for control in [_cost_row, _insufficient]:
		if control.get_parent() != column: control.reparent(column)
	for button in [cancel_button, confirm_button]:
		if button.get_parent() != actions: button.reparent(actions)
		button.custom_minimum_size = Vector2(184, 44) if team_mode else Vector2(190, 52)
	_cost_row.get_child(0).text = "本次探索消耗" if team_mode else "本次探索将消耗"
	_cost_row.get_child(2).visible = not team_mode
	var cost_label: Label = _cost_row.get_child(1).value_label
	cost_label.add_theme_font_size_override("font_size", 26 if team_mode else 18)
	cost_label.add_theme_color_override("font_color", SproutTheme.INK if team_mode else SproutTheme.CREAM)
	for pair in [["outline_size", 4], ["shadow_offset_x", 1], ["shadow_offset_y", 2]]: cost_label.add_theme_constant_override(pair[0], 0 if team_mode else pair[1])
	if not team_mode: confirm_button.remove_theme_stylebox_override("normal")
	if team_mode:
		column.move_child(_cost_row, 0)
		column.move_child(_insufficient, 1)
	else:
		column.move_child(_cost_row, 1)
		column.move_child(_insufficient, 2)
	selector.hide()
	details.hide()
	color = ModalStyle.BACKDROP
	team_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func open_confirmation(message: String, confirm_text := "确认", cancel_text := "取消") -> void:
	_team_mode = false
	_mount_shared_controls(false)
	team_panel.hide()
	_original_center.show()
	super.open_confirmation(message, confirm_text, cancel_text)

func open_exploration() -> void:
	_team_mode = true
	_mount_shared_controls(true)
	_exploration = false
	_original_center.hide()
	team_panel.show()
	selected = SaveManager.remembered_maze_party()
	_armed = false
	_cost_row.show()
	confirm_button.text = "进入迷宫"
	confirm_button.add_theme_stylebox_override("normal", SproutTheme.selected_style())
	cancel_button.text = "取消"
	show()
	_refresh()
	_layout()
	cancel_button.grab_focus()

func _portrait(button: Button, id: String, dimension: float) -> void:
	var config := _config(id)
	var portrait := _icon(load(config.portrait), 0)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.position = Vector2(3, 3)
	portrait.size = Vector2.ONE * (dimension - 6)
	portrait.clip_contents = true
	button.add_child(portrait)
	var icon := _icon(_element_texture(config.faction), 0)
	icon.position = Vector2(-4, -4)
	icon.size = Vector2(24, 24)
	button.add_child(icon)
	var badge := preload("res://scripts/ui/components/rarity_badge.gd").attach(button, id, Rect2(dimension - 28, dimension - 18, 28, 18))
	if badge.texture != null:
		# 本组件所有头像：按字标可见轮廓贴右下，外伸3像素。
		var bounds := badge.texture.get_image().get_used_rect()
		if bounds.has_area():
			var cropped := AtlasTexture.new()
			cropped.atlas = badge.texture
			cropped.region = bounds
			badge.texture = cropped
			var scale_factor := minf(32.0 / bounds.size.x, 18.0 / bounds.size.y)
			badge.size = Vector2(bounds.size) * scale_factor
			badge.position = Vector2.ONE * (dimension + 3) - badge.size
		badge.name = "TeamRarityBadge"

func set_selected(id: String, enabled: bool) -> bool:
	if not update_selection(selected, id, enabled, _owned()):
		selection_notice.text = "最多选择4名已拥有角色"
		return false
	selection_notice.text = "最多携带4名角色"
	_refresh()
	return true

static func update_selection(party: Array, id: String, enabled: bool, owned: Array) -> bool:
	if not owned.has(id): return false
	if enabled and not party.has(id):
		if party.size() >= 4: return false
		party.append(id)
	elif not enabled: party.erase(id)
	return true

func _refresh() -> void:
	var power := 0
	var health := 0
	var defense := 0
	var food_max := 0
	var members: Array = []
	var food := 0.0
	var lines: PackedStringArray = []
	var elements: Array = []
	var food_state := _food_snapshot()
	var valid: bool = food_state.valid
	for id in selected:
		var record := _record(id)
		if not record.valid:
			valid = false
			continue
		var config := _config(id)
		power += int(record.attack)
		health += int(record.health)
		defense += int(record.defense)
		food_max += int(record.satiety_max)
		members.append({"id":id,"rank":record.rank,"element":canonical_element(config.faction)})
		food += float(food_state.get("values", {}).get(id, 0.0))
		var element := canonical_element(config.faction)
		if not elements.has(element): elements.append(element)
		for index in mini(int(record.rank), config.skills.size()):
			lines.append("[color=#5b3b20][font_size=20]%s · %s[/font_size][/color]\n%s" % [config.name, config.skills[index][0], config.skills[index][1]])
	power_value.text = str(Run.team_power(power, members))
	health_value.text = str(health)
	defense_value.text = str(defense)
	# 当前饱腹度按角色分别取整后再汇总；不足 1 的角色不能互相拼成 1 点。
	var whole_food := 0
	for id in selected:
		whole_food += floori(float(food_state.get("values", {}).get(id, 0.0)))
	food_value.text = str(whole_food)
	var totals := ["总攻击  " + power_value.text, "总生命  " + health_value.text, "总防御  " + defense_value.text, "饱腹 / 上限  %d / %d" % [whole_food, food_max]]
	for i in selection_totals.size(): selection_totals[i].text = totals[i]
	warning.visible = not selected.is_empty() and whole_food == 0 and valid
	skills_text.set_entries(lines)
	skill_count.text = "已解锁 %d 项" % lines.size()
	chart.set_elements(elements)
	team_count.text = "已选择  %d / 4" % selected.size()
	selection_count.text = team_count.text
	confirm_button.disabled = selected.is_empty() or not valid or SaveManager.stamina() < SaveManager.STAMINA_COST
	_insufficient.text = "体力不足" if SaveManager.stamina() < SaveManager.STAMINA_COST else ("请选择至少1名角色" if selected.is_empty() else "角色状态异常")
	_insufficient.visible = confirm_button.disabled
	for i in slots.size():
		var id: String = str(selected[i]) if i < selected.size() else ""
		_update_slot(slots[i], id, 64, "+")
		_update_slot(mini_slots[i], id, 44, "—")
		slot_names[i].text = ""
		slot_name_labels[i].text = "" if id.is_empty() else str(_config(id).name)
		slot_level_labels[i].text = ""
		slot_names[i].disabled = id.is_empty()
		slot_stats[i].text = ""
		if not id.is_empty():
			var record := _record(id)
			if record.valid:
				slot_level_labels[i].text = "Lv.%d" % record.level
	for id in checks:
		checks[id].set_pressed_no_signal(selected.has(id))
		checks[id].text = "√ 已入队" if selected.has(id) else "+ 入队"
		checks[id].add_theme_stylebox_override("normal", SproutTheme.selected_style() if selected.has(id) else SproutTheme.unselected_style())
		_paint_row(id)
		var record := _record(id)
		food_labels[id].text = "%d / %d" % [floori(float(food_state.get("values", {}).get(id, 0.0))), int(record.get("satiety_max", 0))]

func _update_slot(button: Button, id: String, dimension: int, empty: String) -> void:
	if button.get_meta("character", "unset") == id: return
	for child in button.get_children():
		button.remove_child(child)
		child.queue_free()
	button.set_meta("character", id)
	button.text = empty if id.is_empty() else ""
	button.tooltip_text = "选择角色" if id.is_empty() else str(_config(id).name)
	if not id.is_empty(): _portrait(button, id, dimension)

func _open_selector() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	tabs.set_current_tab(0)
	_render_rows()
	selection_notice.text = "最多携带4名角色"
	selector.show()
	team_panel.hide()
	selection_done.grab_focus()

func _render_rows() -> void:
	for child in selection_rows.get_children():
		selection_rows.remove_child(child)
		child.queue_free()
	checks.clear()
	name_buttons.clear()
	portrait_buttons.clear()
	row_panels.clear()
	food_labels.clear()
	selection_scroll.scroll_vertical = 0
	for id in _owned():
		var config := _config(id)
		if config.is_empty(): continue
		if tabs.current_tab > 0 and canonical_element(config.faction) != FILTERS[tabs.current_tab]: continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 126
		selection_rows.add_child(panel)
		row_panels[id] = panel
		panel.mouse_entered.connect(_paint_row.bind(id, true))
		panel.mouse_exited.connect(_paint_row.bind(id, false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		panel.add_child(row)
		var identity := HBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_theme_constant_override("separation", 24)
		row.add_child(identity)
		var portrait := _slot(identity, 72)
		_portrait(portrait, id, 72)
		portrait.pressed.connect(_show_details.bind(id, portrait))
		portrait_buttons[id] = portrait
		var name_button := Button.new()
		name_button.text = ""
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.add_theme_font_size_override("font_size", 22)
		_flat_button(name_button)
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_child(name_button)
		var name_column := VBoxContainer.new()
		name_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_button.add_child(name_column)
		name_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_column.alignment = BoxContainer.ALIGNMENT_CENTER
		name_column.add_theme_constant_override("separation", 12)
		var name_label := _label(config.name, 24)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_column.add_child(name_label)
		name_column.add_child(_label("等级 %d · 查看详情" % int(_record(id).get("level", 1)), 17, SproutTheme.INK_MUTED))
		name_button.pressed.connect(_show_details.bind(id, name_button))
		name_buttons[id] = name_button
		var record := _record(id)
		var attack := _label("%s / %s / %s" % [record.get("attack", "—"), record.get("health", "—"), record.get("defense", "—")], 27)
		attack.custom_minimum_size.x = 180
		attack.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(attack)
		var food := _label("", 24)
		food.custom_minimum_size.x = 160
		food.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(food)
		food_labels[id] = food
		var check := SproutButton.new().configure("").set_icon_visible(false).set_focus_visual(false)
		check.toggle_mode = true
		check.add_theme_stylebox_override("pressed", SproutTheme.selected_style())
		check.add_theme_stylebox_override("hover_pressed", SproutTheme.selected_style())
		check.add_theme_color_override("font_pressed_color", SproutTheme.INK)
		row.add_child(check)
		check.custom_minimum_size = Vector2(130, 44)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		checks[id] = check
		check.toggled.connect(func(enabled: bool):
			if not set_selected(id, enabled): check.set_pressed_no_signal(selected.has(id)))
	if checks.is_empty():
		var empty := _label("暂无该属性的已拥有角色", 20, SproutTheme.INK_MUTED)
		empty.custom_minimum_size.y = 120
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_rows.add_child(empty)
	var end := CenterContainer.new()
	end.name = "ListEnd"
	end.custom_minimum_size.y = 90
	selection_rows.add_child(end)
	var end_row := HBoxContainer.new()
	end_row.add_theme_constant_override("separation", 20)
	end.add_child(end_row)
	for i in 3:
		if i == 1:
			end_row.add_child(_label("- 已经到底了 -", 17, SproutTheme.INK_MUTED))
		else:
			var line := _rule()
			line.custom_minimum_size.x = 165
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			end_row.add_child(line)
	_refresh()

func _paint_row(id: String, hover: bool = false) -> void:
	if not row_panels.has(id): return
	var panel: PanelContainer = row_panels[id]
	if not hover: hover = panel.get_global_rect().has_point(get_global_mouse_position())
	var style := SproutTheme.thin_panel_style(Color("#eff0d7") if selected.has(id) or hover else SproutTheme.CREAM)
	style.set_corner_radius_all(0)
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.border_color = Color("#dfcba5")
	style.content_margin_left = 18
	style.content_margin_right = 18
	panel.add_theme_stylebox_override("panel", style)

func _close_selector() -> void:
	selector.hide()
	team_panel.show()
	if is_instance_valid(_return_focus): _return_focus.grab_focus()
	else: cancel_button.grab_focus()

func _show_details(id: String, source: Control) -> void:
	details.set_meta("return_focus", source)
	color.a = 0.0
	details.present(id)

func _details_closed() -> void:
	color = ModalStyle.BACKDROP
	var source: Control = details.get_meta("return_focus", null)
	if is_instance_valid(source): source.grab_focus()
	_refresh()

func _process(delta: float) -> void:
	if not _team_mode:
		super._process(delta)
		return
	if not visible: return
	_timer += delta
	if _timer >= 0.2:
		_timer = 0.0
		_refresh()

func _focusables(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		if child is Control and not child.is_visible_in_tree(): continue
		if child is BaseButton and not child.disabled and child.focus_mode != Control.FOCUS_NONE: result.append(child)
		elif child is TabBar: result.append(child)
		result.append_array(_focusables(child))
	return result

func _input(event: InputEvent) -> void:
	if not _team_mode:
		super._input(event)
		return
	if not visible or not event is InputEventKey: return
	if not event.pressed and event.keycode == KEY_E: _armed = true
	if not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if details.visible: details.close_modal()
		elif selector.visible: _close_selector()
		else: cancelled.emit()
	elif event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		var controls := _focusables(details if details.visible else (selection_panel if selector.visible else team_panel))
		if not controls.is_empty():
			var index := controls.find(get_viewport().gui_get_focus_owner())
			controls[posmod(index + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
	elif event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		if _armed and not selector.visible and not details.visible and not confirm_button.disabled: confirmed.emit()
