extends VBoxContainer
const Sources := preload("res://scripts/cooking/ingredient_sources.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
var book: Control
var items: Array = []

func _ready() -> void:
	add_theme_constant_override("separation",8)
	book = preload("res://scripts/ui/components/recipe_book_panel.gd").new()
	var tooltip_layer := CanvasLayer.new()
	tooltip_layer.layer = 100
	add_child(tooltip_layer)
	tooltip_layer.add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.panel.hide()
	for child in book.get_children():
		if child is ColorRect: child.hide()
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.z_index = 30

func rebuild(sm: Node) -> void:
	book.dismiss_hint()
	for child in get_children():
		if child is CanvasLayer: continue
		remove_child(child)
		child.queue_free()
	items = Sources.suggestions(sm)
	var heading := Label.new()
	heading.text = "建议补充"
	heading.add_theme_font_size_override("font_size",18)
	add_child(heading)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style())
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",4)
	panel.add_child(rows)
	if items.is_empty():
		var hint := Label.new()
		hint.text = "当前探索范围内暂无可补齐的营业料理"
		hint.custom_minimum_size.y = 80
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows.add_child(hint)
	for entry in items:
		var recipe := Recipes.get_recipe(entry.id)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 68
		rows.add_child(row)
		var icon := TextureRect.new()
		icon.texture = preload("res://scripts/ui/components/bag_icon_display.gd").texture(Recipes.item_texture(entry.id))
		icon.custom_minimum_size = Vector2(44,44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var title := Label.new()
		title.text = recipe.name
		title.custom_minimum_size.x = 255
		title.add_theme_font_size_override("font_size",18)
		row.add_child(title)
		for id in recipe.ingredients:
			var cell := Control.new()
			cell.custom_minimum_size = Vector2(184,68)
			row.add_child(cell)
			var slot := SproutItemSlot.new()
			slot.set_grid_mode(true)
			slot.configure(id,Recipes.get_ingredient(id).name,recipe.ingredients[id],0)
			slot.set_icon_texture(preload("res://scripts/ui/components/bag_icon_display.gd").texture(Recipes.item_texture(id)))
			var missing: bool = int(sm._state.get("warehouse_stock",{}).get(id,0))<int(recipe.ingredients[id])
			if missing: slot.source_background = Color("c9cac5")
			cell.add_child(slot)
			slot.position = Vector2(71,2)
			slot.scale = Vector2(0.75,0.75)
			var name_label := Label.new()
			name_label.text = "%s ×%d" % [Recipes.get_ingredient(id).name,recipe.ingredients[id]]
			name_label.position = Vector2(0,45)
			name_label.size.x = 184
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size",15)
			cell.add_child(name_label)
			if missing:
				var badge := Label.new()
				badge.text = "缺"
				badge.position = Vector2(41,-2)
				badge.add_theme_font_size_override("font_size",16)
				badge.add_theme_color_override("font_color",Color("874b3c"))
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(badge)
			book.bind_hint(slot._icon_button,Recipes.get_ingredient(id).name+"\n获取方式："+Sources.description(id))

func _exit_tree() -> void:
	if is_instance_valid(book): book.dismiss_hint()
