class_name SproutCategoryTabs
extends PanelContainer
## 分类切换控件，维护当前分类并发出 category_changed 信号。

signal category_changed(category_id: String)

var _tabs_box: HBoxContainer
var _buttons: Array[Button] = []
var _categories: Array = []
var selected_id := ""

func _ready() -> void:
	theme = SproutTheme.make_theme()
	_build()

func _build() -> void:
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	_tabs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tabs_box)

func set_categories(categories: Array) -> void:
	if _tabs_box == null:
		_build()
	_categories = categories.duplicate()
	for child in _tabs_box.get_children():
		child.queue_free()
	_buttons.clear()
	if _categories.is_empty():
		selected_id = ""
		return
	for category in _categories:
		var button := Button.new()
		button.theme = SproutTheme.make_theme()
		button.text = str(category.get("label", "分类"))
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		var id := str(category.get("id", button.text))
		button.pressed.connect(func() -> void: select_category(id))
		_tabs_box.add_child(button)
		_buttons.append(button)
	select_category(str(_categories[0].get("id", "")))

func select_category(category_id: String) -> void:
	selected_id = category_id
	for i in _buttons.size():
		var id := str(_categories[i].get("id", ""))
		_buttons[i].add_theme_stylebox_override("normal", SproutTheme.selected_style() if id == selected_id else SproutTheme.unselected_style())
		_buttons[i].add_theme_stylebox_override("hover", SproutTheme.selected_style() if id == selected_id else SproutTheme.button_style(SproutTheme.GREEN_HOVER))
	category_changed.emit(selected_id)
