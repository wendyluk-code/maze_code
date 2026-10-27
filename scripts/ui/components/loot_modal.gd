extends SproutModal
## 通用获得物品展示；调用方先完成领取事务，再传入展示数据。
const COIN := preload("res://assets/ui/chests/gold_coin.png")
const INK := SproutTheme.INK
var item_row_height := 106.0
var item_views: Array[Dictionary] = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _content_center: CenterContainer
var _display_textures: Dictionary = {}

func display_texture(texture: Texture2D) -> Texture2D:
	if texture == null: return null
	if _display_textures.has(texture): return _display_textures[texture]
	var image := texture.get_image()
	if image == null or image.is_empty(): return texture
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.1:
				minimum = minimum.min(Vector2i(x, y))
				maximum = maximum.max(Vector2i(x, y))
	if maximum.x < 0: return texture
	# 与金币一样按可见轮廓等比显示；只裁展示副本，不改源素材。
	var region := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	var result := ImageTexture.create_from_image(image.get_region(region))
	_display_textures[texture] = result
	return result

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 20)
	_panel.add_child(outer)
	var heading := HBoxContainer.new()
	outer.add_child(heading)
	_title_label = Label.new()
	_title_label.text = "获得物品"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", INK)
	heading.add_child(_title_label)
	_body_label = Label.new()
	_body_label.hide()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_body_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)
	_content_center = CenterContainer.new()
	_content_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_center)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_content_center.add_child(_grid)
	var actions := CenterContainer.new()
	outer.add_child(actions)
	_confirm_button = SproutButton.new()
	_confirm_button.set_icon_visible(false)
	actions.add_child(_confirm_button)
	_confirm_button.custom_minimum_size = Vector2(144, 40)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button = SproutButton.new()
	_cancel_button.hide()
	add_child(_cancel_button)
	_confirm_button.set_focus_visual(false)
	_confirm_button.focus_next = NodePath(".")
	_confirm_button.focus_previous = NodePath(".")

static func coin_texture() -> Texture2D:
	var region := AtlasTexture.new()
	region.atlas = COIN
	region.region = Rect2(252, 259, 750, 733)
	return region

func show_reward(amount: int, _total: int = 0) -> void:
	show_items([{"name": "金币", "quantity": amount, "icon": coin_texture()}])

## items: [{name: String, quantity: int, icon: Texture2D}]，只展示，不写库存或存档。
func show_items(items: Array[Dictionary]) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	item_views.clear()
	for item in items:
		_add_item(item)
	_grid.columns = clampi(items.size(), 1, 3)
	var rows := mini(2, ceili(float(items.size()) / 3.0))
	_scroll.custom_minimum_size.y = maxf(item_row_height, rows * item_row_height + (rows - 1) * 12)
	_scroll.scroll_vertical = 0
	var width := maxf(340, _grid.columns * 112 + (_grid.columns - 1) * 12 + 64)
	var height := _scroll.custom_minimum_size.y + 140
	_scroll.custom_minimum_size.x = width - 64
	_content_center.custom_minimum_size = Vector2(width - 64, _scroll.custom_minimum_size.y)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.offset_left = -width / 2
	_panel.offset_right = width / 2
	_panel.offset_top = -height / 2
	_panel.offset_bottom = height / 2
	show_modal("获得物品", "", "收下")

func _add_item(item: Dictionary) -> void:
	var tile := VBoxContainer.new()
	tile.custom_minimum_size = Vector2(112, item_row_height)
	tile.add_theme_constant_override("separation", 6)
	_grid.add_child(tile)
	var center := CenterContainer.new()
	tile.add_child(center)
	var icon := TextureRect.new()
	icon.texture = display_texture(item.get("icon") as Texture2D)
	icon.custom_minimum_size = Vector2(43, 43)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	var label := Label.new()
	label.text = str(item.get("name", ""))
	label.custom_minimum_size = Vector2(112, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 18)
	tile.add_child(label)
	var count := Label.new()
	count.text = "×%d" % int(item.get("quantity", 1))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_override("font", ThemeDB.fallback_font)
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_color", Color("#69755b"))
	tile.add_child(count)
	item_views.append({"name": label, "quantity": count, "icon": icon})

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		close_modal()
	elif event.keycode == KEY_TAB:
		_confirm_button.grab_focus()

func _unhandled_input(_event: InputEvent) -> void:
	pass
