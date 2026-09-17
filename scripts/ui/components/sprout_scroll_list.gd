class_name SproutScrollList
extends PanelContainer
## 可滚动选项列表，支持空状态；条目仅为预览数据。

signal item_selected(item_id: String)

var _scroll: ScrollContainer
var _items_box: VBoxContainer
var _empty_label: Label

func _ready() -> void:
	theme = SproutTheme.make_theme()
	custom_minimum_size = Vector2(300, 220)
	_ensure_built()

func _build() -> void:
	if is_instance_valid(_scroll):
		return
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 6)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_items_box)
	_empty_label = Label.new()
	_empty_label.text = "暂无模拟条目"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size.y = 150
	_items_box.add_child(_empty_label)

func set_items(items: Array) -> void:
	_ensure_built()
	for child in _items_box.get_children():
		if child != _empty_label:
			child.queue_free()
	if _empty_label.get_parent() == _items_box:
		_items_box.remove_child(_empty_label)
	if items.is_empty():
		_items_box.add_child(_empty_label)
		return
	for item in items:
		var row := SproutButton.new()
		row.configure(str(item.get("label", "未命名")), int(item.get("icon", 0)))
		row.custom_minimum_size = Vector2(0, 48)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(func() -> void: item_selected.emit(str(item.get("id", ""))))
		_items_box.add_child(row)

func _ensure_built() -> void:
	_build()
