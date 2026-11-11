extends Control

signal closed
signal menu_prepared(snapshot: Dictionary)

const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const BagIcon := preload("res://scripts/ui/components/bag_icon_display.gd")
const ResourceCounter := preload("res://scripts/ui/components/resource_counter.gd")
var draft := {}
var list: VBoxContainer
var scroll: ScrollContainer
var summary: Label
var message: Label
var confirm_button: Button
var day_label: Label
var column_header: Control
var headers: Array[Label] = []
var empty_panel: PanelContainer
var cancel_button: Button
var forced := false
var first_day_required := false
var restock: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SproutTheme.make_theme()
	var overlay := ColorRect.new()
	overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style(SproutTheme.PANEL))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -234
	panel.offset_bottom = 234
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var heading := Label.new()
	heading.text = "今日可做菜单"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	outer.add_child(heading)
	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 16)
	day_label.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	outer.add_child(day_label)
	column_header = Control.new()
	column_header.custom_minimum_size.y = 22
	outer.add_child(column_header)
	for title in ["料理", "每份食材", "每份售价", "备售份数"]:
		var label := Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", 15)
		column_header.add_child(label)
		headers.append(label)
	resized.connect(func(): _align_headers.call_deferred())
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 228)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	empty_panel = PanelContainer.new()
	empty_panel.custom_minimum_size = Vector2(0, 48)
	var empty_style := SproutTheme.thin_panel_style()
	empty_style.content_margin_top = 8
	empty_style.content_margin_bottom = 8
	empty_panel.add_theme_stylebox_override("panel", empty_style)
	outer.add_child(empty_panel)
	var empty_label := Label.new()
	empty_label.text = "暂无可做料理"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 20)
	empty_panel.add_child(empty_label)
	empty_panel.hide()
	restock = preload("res://scripts/ui/components/menu_restock.gd").new()
	outer.add_child(restock)
	restock.hide()
	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(scroll_margin)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll_margin.add_child(list)
	summary = Label.new()
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message = Label.new()
	message.add_theme_font_size_override("font_size", 15)
	message.hide()
	outer.add_child(message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(actions)
	actions.add_child(summary)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	var cancel := Button.new()
	cancel_button = cancel
	cancel.text = "稍后"
	cancel.custom_minimum_size = Vector2(150, 42)
	cancel.pressed.connect(_cancel_or_skip)
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm_button = confirm
	confirm.text = "开始营业"
	confirm.custom_minimum_size = Vector2(170, 42)
	confirm.add_theme_stylebox_override("normal", SproutTheme.selected_style())
	confirm.pressed.connect(_confirm)
	actions.add_child(confirm)
	hide()

func open() -> void:
	first_day_required = int(Day.snapshot(SaveManager).get("day",1)) == 1 and SaveManager._state.get("first_exploration_gate_v1","") == "done"
	forced = preload("res://scripts/restaurant/preparation.gd").expired(SaveManager)
	day_label.text = "第 %d 天" % int(Day.snapshot(SaveManager).get("day", 1))
	var saved = Day.snapshot(SaveManager).get("menu", {})
	draft = saved.duplicate(true) if saved is Dictionary else {}
	message.text = ""
	_rebuild()
	show()

func close() -> void:
	if forced or first_day_required: return
	if visible:
		restock.book.dismiss_hint()
		hide()
		closed.emit()

func _process(_delta: float) -> void:
	message.visible = not message.text.is_empty()
	if visible and not forced and preload("res://scripts/restaurant/preparation.gd").expired(SaveManager):
		forced = true
		_rebuild()

func _cancel_or_skip() -> void:
	if first_day_required: return
	if not forced:
		close()
		return
	var result := preload("res://scripts/restaurant/preparation.gd").skip(SaveManager)
	if result.success:
		forced = false
		close()
	else: message.text = "保存失败或已有可做料理，请重试"

func _confirm() -> void:
	var result := preload("res://scripts/restaurant/service_cycle.gd").open_with_menu(SaveManager, draft)
	if not result.success:
		if result.reason == "save_failed": message.text = "保存失败，请重试"
		elif result.reason in ["already_prepared", "already_open"]: message.text = "今日已经开业"
		elif result.reason == "customers_pending": message.text = "请先完成店内现有顾客的订单"
		else: message.text = "材料不足或菜单无效"
		return
	menu_prepared.emit(result)
	first_day_required = false
	forced = false
	close()

func _rebuild() -> void:
	# Reconcile a saved draft against today's stock, including shared ingredients.
	var requested := draft.duplicate(true)
	draft.clear()
	for id in requested:
		if id not in SaveManager.unlocked_recipe_ids() or Recipes.order_gold(id) <= 0: continue
		for portion in mini(10, int(requested[id])):
			if not _can_add(id): break
			draft[id] = int(draft.get(id, 0)) + 1
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for recipe_id in SaveManager.unlocked_recipe_ids():
		if Recipes.order_gold(recipe_id) <= 0: continue
		if not draft.has(recipe_id) and not _can_add(recipe_id): continue
		_add_row(recipe_id)
	var amount := 0
	for quantity in draft.values(): amount += int(quantity)
	summary.text = "%d 道 / %d 份" % [draft.size(), amount]
	confirm_button.disabled = draft.is_empty() or not Day.validate_menu(SaveManager, draft).success
	var is_empty := list.get_child_count() == 0
	empty_panel.visible = is_empty
	restock.visible = is_empty
	summary.visible = not is_empty
	if is_empty: restock.rebuild(SaveManager)
	else: restock.book.dismiss_hint()
	scroll.visible = not is_empty
	message.text = ""
	cancel_button.text = "跳过今日" if forced else "稍后"
	cancel_button.visible = not first_day_required and (not forced or is_empty)
	_align_headers.call_deferred()

func _can_add(recipe_id: String) -> bool:
	var proposed := draft.duplicate(true)
	proposed[recipe_id] = int(proposed.get(recipe_id, 0)) + 1
	return bool(Day.validate_menu(SaveManager, proposed).success)

func _align_headers() -> void:
	if list.get_child_count() == 0:
		column_header.hide()
		return
	column_header.show()
	var row := list.get_child(0).get_node("RecipeRow")
	var anchors := [row.get_child(1), row.get_node("Ingredients"), row.get_node("Price"), row.get_node("Decrease")]
	for i in headers.size():
		var anchor: Control = anchors[i]
		headers[i].position.x = anchor.global_position.x - column_header.global_position.x
		headers[i].size.x = anchor.size.x
		if i == 2: headers[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == 3:
			headers[i].size.x = row.get_node("Increase").global_position.x + row.get_node("Increase").size.x - anchor.global_position.x
			headers[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _add_row(recipe_id: String, recipe_override: Dictionary = {}) -> void:
	var recipe := Recipes.get_recipe(recipe_id) if recipe_override.is_empty() else recipe_override
	var panel := PanelContainer.new()
	panel.name = "Recipe_" + recipe_id
	panel.custom_minimum_size = Vector2(0, 70)
	panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style(Color("eef0da")))
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.name = "RecipeRow"
	row.resized.connect(func(): _align_headers.call_deferred())
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var check := CheckBox.new()
	check.name = "Selected"
	check.button_pressed = draft.has(recipe_id)
	check.toggled.connect(func(checked: bool):
		if checked and _can_add(recipe_id): draft[recipe_id] = 1
		elif not checked: draft.erase(recipe_id)
		_rebuild())
	row.add_child(check)
	row.add_child(_icon(recipe_id, 40))
	var name_label := Label.new()
	name_label.text = str(recipe.name)
	name_label.custom_minimum_size.x = 155
	name_label.add_theme_font_size_override("font_size", 16)
	row.add_child(name_label)
	var ingredients := HBoxContainer.new()
	ingredients.name = "Ingredients"
	ingredients.custom_minimum_size.x = 205
	row.add_child(ingredients)
	var ingredient_index := 0
	for item_id in recipe.ingredients:
		if ingredient_index > 0:
			var separator := Label.new()
			separator.text = "+"
			separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ingredients.add_child(separator)
		var holder := Control.new()
		holder.name = "Ingredient_" + str(item_id)
		holder.custom_minimum_size = Vector2(43, 40)
		var icon := _icon(item_id, 35)
		holder.add_child(icon)
		var count := Label.new()
		count.text = "×%d" % int(recipe.ingredients[item_id])
		count.add_theme_font_size_override("font_size", 13)
		count.position = Vector2(24, 23)
		holder.add_child(count)
		ingredients.add_child(holder)
		ingredient_index += 1
	var price := HBoxContainer.new()
	price.name = "Price"
	price.custom_minimum_size.x = 90
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(price)
	var coin := TextureRect.new()
	coin.name = "Coin"
	coin.texture = ResourceCounter.GOLD
	coin.custom_minimum_size = Vector2(28, 28)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	price.add_child(coin)
	var price_label := Label.new()
	price_label.name = "Amount"
	price_label.text = str(Recipes.order_gold(recipe_id))
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_child(price_label)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	var minus := Button.new()
	minus.name = "Decrease"
	minus.text = "−"
	minus.disabled = not draft.has(recipe_id) or int(draft.get(recipe_id, 0)) <= 1
	minus.pressed.connect(func(): draft[recipe_id] -= 1; _rebuild())
	row.add_child(minus)
	var count := Label.new()
	count.text = str(int(draft.get(recipe_id, 0)))
	count.custom_minimum_size.x = 24
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count)
	var plus := Button.new()
	plus.name = "Increase"
	plus.text = "+"
	plus.disabled = not draft.has(recipe_id) or not _can_add(recipe_id)
	plus.pressed.connect(func():
		if _can_add(recipe_id): draft[recipe_id] += 1
		_rebuild())
	row.add_child(plus)

func _icon(item_id: String, side: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.texture = BagIcon.texture(Recipes.item_texture(item_id))
	var info := Recipes.get_ingredient(item_id) if Recipes.is_ingredient(item_id) else Recipes.get_recipe(item_id)
	icon.tooltip_text = str(info.get("name", item_id))
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
