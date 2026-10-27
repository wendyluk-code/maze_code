extends ColorRect
signal closed
signal feedback(message: String)
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")
const Store := preload("res://scripts/restaurant/freezer_store.gd")
const Stars := preload("res://scripts/ui/cooking_rating_stars.gd")
const Icon := preload("res://scripts/ui/components/freezer_action_icon.gd")
const Display := preload("res://scripts/ui/components/bag_icon_display.gd")
const ModalStyle := preload("res://scripts/ui/components/modal_style.gd")
var panel: PanelContainer
var tabs: TabBar
var capacity: Label
var left_scroll: ScrollContainer
var right_scroll: ScrollContainer
var recipes: VBoxContainer
var batches: VBoxContainer
var held: HBoxContainer
var confirmation: Control
var selected := ""
var held_index := 0
var pending := {}
var _signature := ""
var _tick := 0.0
var _timers: Array = []

func _ready() -> void:
	name = "FreezerModal"
	add_to_group("freezer_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = ModalStyle.BACKDROP
	theme = SproutTheme.make_theme()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(SproutTheme.PANEL, 18))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("冰柜", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := ModalStyle.close_button()
	header.add_child(close)
	close.pressed.connect(dismiss)
	var table := PanelContainer.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", _style(SproutTheme.CREAM, 2))
	column.add_child(table)
	var table_column := VBoxContainer.new()
	table_column.add_theme_constant_override("separation", 0)
	table.add_child(table_column)
	var tab_row := HBoxContainer.new()
	table_column.add_child(tab_row)
	tabs = preload("res://scripts/ui/components/sprout_tab_bar.gd").new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	for text in ["全部", "临近到期", "已腐坏"]: tabs.add_tab(text)
	tab_row.add_child(tabs)
	capacity = _label("", 18)
	capacity.custom_minimum_size.x = 155
	tab_row.add_child(capacity)
	var divider := HSeparator.new()
	table_column.add_child(divider)
	var inset := MarginContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: inset.add_theme_constant_override(side, 8)
	table_column.add_child(inset)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	inset.add_child(columns)
	left_scroll = _scroll(columns)
	recipes = VBoxContainer.new()
	recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(recipes)
	right_scroll = _scroll(columns)
	batches = VBoxContainer.new()
	batches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batches.add_theme_constant_override("separation", 10)
	right_scroll.add_child(batches)
	column.add_child(_label("存入料理", 22))
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _style(Color("faedce"), 10))
	column.add_child(bottom)
	held = HBoxContainer.new()
	held.custom_minimum_size.y = 44
	held.add_theme_constant_override("separation", 12)
	bottom.add_child(held)
	confirmation = preload("res://scripts/ui/components/destination_confirmation.gd").new()
	add_child(confirmation)
	confirmation.cancelled.connect(func(): confirmation.hide(); pending.clear())
	confirmation.confirmed.connect(_confirm_discard)
	tabs.tab_changed.connect(func(_index): _refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

static func _style(bg: Color, margin: int) -> StyleBoxFlat:
	var style := SproutTheme.thin_panel_style(bg)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, margin)
	return style

func _layout() -> void:
	var viewport := get_viewport_rect().size
	panel.size = Vector2(minf(1060, viewport.x - 48), minf(608, viewport.y - 48))
	panel.position = (viewport - panel.size) / 2.0

func _scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	parent.add_child(scroll)
	return scroll

static func _label(text: String, font_size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SproutTheme.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _food(parent: Node, recipe_id: String, width := 64) -> void:
	var image := TextureRect.new()
	image.texture = Display.texture(Catalog.item_texture(recipe_id))
	image.custom_minimum_size = Vector2(width, width)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func _stars(parent: Node, quality: int) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(96, 36)
	parent.add_child(holder)
	var stars := Stars.new()
	stars.uniform = true
	holder.add_child(stars)
	stars.scale = Vector2.ONE * 0.36
	stars.quality = quality
	stars.elapsed = 2.0
	stars.queue_redraw()

static func _tags(parent: Node, recipe_id: String) -> void:
	var recipe := Catalog.get_recipe(recipe_id)
	# 允许同时属于订单与探索；只展示实际配方元数据，不把示例效果写入正式料理。
	var tags: Array = recipe.get("uses", ["订单"])
	for text in tags:
		if text in ["订单", "探索"]: _tag(parent, text, Color("e9d1a0") if text == "订单" else Color("c5dfa9"), false)
	if "探索" in tags and recipe.get("exploration_category", "") in ["攻击", "生命", "防御", "饱腹", "特殊"]:
		var category: String = recipe.exploration_category
		var colors := {"攻击":"edb69b", "生命":"e8b7bc", "防御":"b7d1e3", "饱腹":"f2df9c", "特殊":"d9c3e5"}
		_tag(parent, category, Color(colors[category]), true)

static func _tag(parent: Node, text: String, bg: Color, small: bool) -> void:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(bg, 4)
	style.set_border_width_all(0)
	style.set_corner_radius_all(12 if small else 4)
	style.content_margin_left = 9
	style.content_margin_right = 9
	tag.add_theme_stylebox_override("panel", style)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := _label(text, 14 if small else 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(label)
	parent.add_child(tag)

func open() -> void:
	if not SaveManager.freezer_unlocked():
		feedback.emit("完成【初遇御风】剧情后解锁")
		closed.emit()
		return
	show()
	_refresh()
	_layout()

func dismiss() -> void:
	if not visible or confirmation.visible: return
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or confirmation.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _matches(unit: Dictionary, now: int) -> bool:
	var remaining := int(unit.expires_at) - now
	return tabs.current_tab == 0 or (tabs.current_tab == 1 and remaining > 0 and remaining <= Store.NEAR_EXPIRY) or (tabs.current_tab == 2 and remaining <= 0)

func _refresh() -> void:
	var left_y := left_scroll.scroll_vertical
	var right_y := right_scroll.scroll_vertical
	_clear(recipes)
	_clear(batches)
	_clear(held)
	_timers.clear()
	var ledger := SaveManager.freezer_snapshot()
	if ledger.is_empty():
		capacity.text = ""
		recipes.add_child(_label("料理记录异常，请保留存档"))
		return
	capacity.text = "存放 %d / %d" % [ledger.stored.size(), Store.CAPACITY]
	var now := int(Time.get_unix_time_from_system())
	var groups := {}
	for unit in ledger.stored:
		if _matches(unit, now):
			if not groups.has(unit.recipe_id): groups[unit.recipe_id] = []
			groups[unit.recipe_id].append(unit)
	if not groups.has(selected): selected = str(groups.keys()[0]) if not groups.is_empty() else ""
	for recipe_id in groups:
		_recipe_row(recipe_id, groups[recipe_id].size())
	if groups.is_empty():
		recipes.add_child(_empty_label(["冰柜里还没有料理", "暂无临近到期的料理", "暂无已腐坏的料理"][tabs.current_tab]))
		batches.add_child(_empty_label("暂无料理详情"))
	else:
		for unit in groups[selected]: _batch(unit, now)
	_held_row(ledger, now)
	left_scroll.set_deferred("scroll_vertical", left_y)
	right_scroll.set_deferred("scroll_vertical", right_y)
	_signature = _state_signature()

func _recipe_row(recipe_id: String, count: int) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 82
	var row_style := _style(Color("eef0d5") if recipe_id == selected else SproutTheme.CREAM, 8)
	if recipe_id != selected:
		row_style.set_border_width_all(0)
		row_style.border_width_bottom = 1
		row_style.border_color = Color("dfcba5")
		row_style.set_corner_radius_all(0)
	button.add_theme_stylebox_override("normal", row_style)
	recipes.add_child(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	_food(row, recipe_id, 64)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_row)
	name_row.add_child(_label(Catalog.get_recipe(recipe_id).name, 19))
	_tags(name_row, recipe_id)
	column.add_child(_label("共 %d份" % count, 17))
	button.pressed.connect(func(): selected = recipe_id; right_scroll.scroll_vertical = 0; _refresh())

func _batch(unit: Dictionary, now: int) -> void:
	var expired := int(unit.expires_at) <= now
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 102
	card.add_theme_stylebox_override("panel", _style(Color("e8dfc8") if expired else SproutTheme.CREAM, 10))
	batches.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	_food(row, unit.recipe_id, 64)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var rating := HBoxContainer.new()
	body.add_child(rating)
	_stars(rating, int(unit.quality))
	rating.add_child(_label("1份"))
	var timer := _label(_remaining(int(unit.expires_at)), 17)
	if expired: timer.add_theme_color_override("font_color", Color("b45e37"))
	body.add_child(timer)
	_timers.append({"label": timer, "expires_at": int(unit.expires_at)})
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(actions)
	if not expired:
		var withdraw := Icon.new()
		withdraw.name = "Withdraw_%d" % int(unit.id)
		actions.add_child(withdraw)
		withdraw.pressed.connect(func(): _act("withdraw", unit))
	var trash := Icon.new()
	trash.trash = true
	trash.name = "Discard_%d" % int(unit.id)
	actions.add_child(trash)
	trash.pressed.connect(func(): _ask_discard("discard", unit))

func _held_row(ledger: Dictionary, now: int) -> void:
	var options := SaveManager.freezer_carried_options()
	if options.is_empty():
		var empty := _empty_label("暂无可存入的料理")
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		held.add_child(empty)
		var disabled_button := SproutButton.new().configure("存入冰柜").set_icon_visible(false)
		disabled_button.disabled = true
		held.add_child(disabled_button)
		return
	held_index = clampi(held_index, 0, options.size() - 1)
	var unit: Dictionary = options[held_index]
	_food(held, unit.recipe_id, 44)
	if options.size() > 1:
		var selector := OptionButton.new()
		for option in options: selector.add_item(Catalog.get_recipe(option.recipe_id).name)
		selector.select(held_index)
		held.add_child(selector)
		selector.item_selected.connect(func(index): held_index = index; _refresh())
	else:
		held.add_child(_label(Catalog.get_recipe(unit.recipe_id).name, 19))
	_tags(held, unit.recipe_id)
	_stars(held, int(unit.quality))
	held.add_child(_label("%d份" % int(unit.count)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	held.add_child(spacer)
	var expired := int(unit.expires_at) > 0 and int(unit.expires_at) <= now
	if int(unit.expires_at) > 0:
		var timer := _label(_remaining(int(unit.expires_at)), 16)
		held.add_child(timer)
		_timers.append({"label": timer, "expires_at": int(unit.expires_at)})
	if expired:
		var trash := Icon.new()
		trash.trash = true
		held.add_child(trash)
		trash.pressed.connect(func(): _ask_discard("discard_carried", unit))
	else:
		var insert := SproutButton.new().configure("存入冰柜").set_icon_visible(false)
		insert.name = "StoreDish"
		insert.disabled = ledger.stored.size() >= Store.CAPACITY
		held.add_child(insert)
		insert.pressed.connect(func(): _act("store", unit))

static func _remaining(deadline: int) -> String:
	var seconds := deadline - int(Time.get_unix_time_from_system())
	if seconds <= 0: return "已腐坏"
	if seconds < 3600: return "剩余 %d分钟" % maxi(1, ceili(seconds / 60.0))
	var hours := floori(seconds / 3600.0)
	return "剩余 %d天%d小时" % [hours / 24, hours % 24]

func _ask_discard(action: String, unit: Dictionary) -> void:
	pending = {"action": action, "unit": unit.duplicate(true)}
	confirmation.open_confirmation("丢弃这份%s？" % Catalog.get_recipe(unit.recipe_id).name, "丢弃", "取消")

func _confirm_discard() -> void:
	if pending.is_empty(): return
	var request := pending.duplicate(true)
	pending.clear()
	confirmation.hide()
	_act(request.action, request.unit)

func _act(action: String, unit: Dictionary) -> void:
	var result := SaveManager.freezer_action(action, int(unit.id), str(unit.recipe_id), int(unit.quality))
	var messages := {"full":"冰柜已满", "expired":"这份料理已腐坏", "hands_full":"请先存放或处理携带的料理", "changed":"料理已变化，请重新选择", "save_failed":"保存失败，料理未移动，请重试", "invalid_state":"料理记录异常，请保留存档", "busy":"请先完成烹饪", "chapter_locked":"请先完成第一章"}
	feedback.emit({"store":"料理已存入冰柜", "withdraw":"料理已取出", "discard":"料理已丢弃", "discard_carried":"料理已丢弃"}.get(action, "操作完成") if result.success else messages.get(result.get("reason", ""), "操作未完成"))
	_refresh()

func _state_signature() -> String:
	var ledger := SaveManager.freezer_snapshot()
	var now := int(Time.get_unix_time_from_system())
	var status: Array = []
	for unit in ledger.get("stored", []) + ledger.get("carried", []): status.append([int(unit.expires_at) <= now, int(unit.expires_at) - now <= Store.NEAR_EXPIRY])
	return JSON.stringify([ledger, SaveManager.prepared_dishes_snapshot(), status])

func _process(delta: float) -> void:
	if not visible: return
	_tick += delta
	if _tick < 1.0: return
	_tick = 0.0
	if _signature != _state_signature(): _refresh()
	for timer in _timers:
		if is_instance_valid(timer.label): timer.label.text = _remaining(timer.expires_at)

func _empty_label(value: String) -> Label:
	var label := _label(value, 16)
	label.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	return label
