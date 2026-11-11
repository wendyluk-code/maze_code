extends "res://scripts/ui/components/loot_modal.gd"

const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
var _entrance: Tween
var _flipping := false

func show_loot(items: Dictionary) -> void:
	if _entrance != null and _entrance.is_valid(): _entrance.kill()
	_flipping = true
	_panel.scale = Vector2(0.01,1)
	_confirm_button.disabled = true
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.columns = 1
	var groups := Day.loot_groups(SaveManager, items)
	_add_group("捕获食材", groups.capture, Color("dceef4"))
	_add_group("任务食材", groups.task, Color("e3efd8"))
	if items.is_empty():
		var message := Label.new()
		message.name = "EmptyMessage"
		message.text = "本次探索未带回食材"
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.add_theme_font_size_override("font_size", 22)
		message.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
		_grid.add_child(message)
	show_modal("本次带回", "", "确认")
	_body_label.hide()
	_panel.add_theme_stylebox_override("panel", SproutTheme.thin_panel_style(SproutTheme.PANEL))
	_scroll.custom_minimum_size = Vector2(570, 64)
	_scroll.scroll_vertical = 0
	_content_center.custom_minimum_size = Vector2(570, 64)
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.offset_left = -310
	_panel.offset_right = 310
	_fit_content.call_deferred()
	_flip_in.call_deferred()

func _flip_in() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible: return
	_panel.pivot_offset = _panel.size * 0.5
	GameAudio.play_cue(&"cooking_complete")
	_entrance = create_tween()
	_entrance.tween_property(_panel,"scale:x",1.0,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _entrance.finished
	_flipping = false
	_confirm_button.disabled = false
	_confirm_button.grab_focus()

func _fit_content() -> void:
	if not visible: return
	var height := clampf(_grid.get_combined_minimum_size().y, 64.0, minf(350.0, get_viewport_rect().size.y - 240.0))
	_scroll.custom_minimum_size.y = height
	_content_center.custom_minimum_size.y = height
	_center_panel.call_deferred()

func _center_panel() -> void:
	if not visible: return
	var height := _panel.get_combined_minimum_size().y
	_panel.offset_top = -height / 2.0
	_panel.offset_bottom = height / 2.0
	_panel.size.y = height

func _add_group(title: String, items: Dictionary, tint: Color) -> void:
	if items.is_empty(): return
	var panel := PanelContainer.new()
	panel.name = "CaptureGroup" if title == "捕获食材" else "TaskGroup"
	panel.custom_minimum_size.x = 554
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	_grid.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	var tiles := GridContainer.new()
	tiles.columns = 4
	tiles.add_theme_constant_override("h_separation", 8)
	box.add_child(tiles)
	var root_grid := _grid
	_grid = tiles
	for id in items:
		_add_item({"name":str(Recipes.get_ingredient(id).get("name",id)),"quantity":int(items[id]),"icon":Recipes.item_texture(id),"tint":tint})
	_grid = root_grid
func _add_item(item: Dictionary) -> void:
	var tile := VBoxContainer.new()
	tile.custom_minimum_size = Vector2(126, 100)
	_grid.add_child(tile)
	var center := CenterContainer.new()
	tile.add_child(center)
	var background := PanelContainer.new()
	background.custom_minimum_size = Vector2(56, 56)
	var style := SproutTheme.thin_panel_style(item.get("tint", Color("fff8e9")))
	style.set_content_margin_all(8)
	background.add_theme_stylebox_override("panel", style)
	center.add_child(background)
	var icon := TextureRect.new()
	icon.texture = display_texture(item.get("icon") as Texture2D)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.add_child(icon)
	var label := Label.new()
	label.text = str(item.get("name", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	tile.add_child(label)
	var count := Label.new()
	count.text = "× %d" % int(item.get("quantity", 0))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(count)

func close_modal() -> void:
	if _flipping: return
	if not visible: return
	if Day.acknowledge_loot(SaveManager):
		super.close_modal()
	else:
		_body_label.text = "保存失败，请重试"
		_body_label.show()
		_fit_content.call_deferred()
