extends "res://scripts/ui/components/destination_confirmation.gd"
## 复用统一确认框；丢弃不接受 E，名称数量在限高区域内滚动。
var item_list: Label
var item_scroll: ScrollContainer

func _ready() -> void:
	super._ready()
	question.add_theme_font_size_override("font_size", 20)
	item_scroll = ScrollContainer.new()
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := question.get_parent()
	column.add_child(item_scroll)
	column.move_child(item_scroll, 1)
	item_list = Label.new()
	item_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.add_child(item_list)

func present(items: Dictionary) -> void:
	var lines := PackedStringArray()
	var catalog := preload("res://scripts/cooking/recipe_catalog.gd")
	for id in items:
		var config: Dictionary = catalog.INGREDIENTS.get(id, catalog.RECIPES.get(id, {}))
		lines.append("%s × %d" % [config.get("name", id), items[id]])
	item_list.text = "\n".join(lines)
	item_scroll.custom_minimum_size = Vector2(440, minf(240, items.size() * 30))
	item_scroll.scroll_vertical = 0
	open_confirmation("丢弃以下物品？丢弃后无法找回。", "确认丢弃", "取消")

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		get_viewport().set_input_as_handled()
		return
	super._input(event)
