extends SproutModal
## 组合现有弹窗、滚动列表、按钮和主题；业务状态由 SaveManager 管理。

signal slot_requested(path: String)

var slot_list: SproutScrollList
var _selected := ""
var _slots: Array = []

func _ready() -> void:
	super._ready()
	_body_label.custom_minimum_size.y = 50
	_body_label.size_flags_vertical = Control.SIZE_FILL
	slot_list = SproutScrollList.new()
	var outer := _body_label.get_parent()
	outer.add_child(slot_list)
	outer.move_child(slot_list, _body_label.get_index() + 1)
	slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_list._empty_label.text = "还没有存档\n选择“新游戏”开始新的冒险"
	slot_list.item_selected.connect(_select_slot)
	_confirm_button.set_focus_visual(true)
	_cancel_button.set_focus_visual(true)
	resized.connect(_fit_panel)
	_fit_panel()
	_panel.minimum_size_changed.connect(_fit_panel)

func _exit_tree() -> void:
	# 列表组件在有条目时暂时移除空提示；组合方负责释放这枚离树控件。
	if is_instance_valid(slot_list) and is_instance_valid(slot_list._empty_label) and slot_list._empty_label.get_parent() == null:
		slot_list._empty_label.free()

func _fit_panel() -> void:
	var panel_size := Vector2(minf(660, size.x - 32), minf(490, size.y - 32))
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.position = (size - _panel.size) * 0.5

func open_slots() -> void:
	_selected = ""
	var result := SaveManager.list_save_slots()
	_slots = result.slots
	slot_list._empty_label.text = "还没有存档\n选择“新游戏”开始新的冒险" if result.success else "存档列表暂时不可用\n请排除读取问题后重试"
	var items: Array = []
	for slot in _slots:
		items.append({"id": slot.id, "label": slot.name + "\n保存时间：" + slot.time_text + ("  · " + slot.problem if not slot.problem.is_empty() else "")})
	slot_list.set_items(items)
	for child in slot_list._items_box.get_children():
		if child is SproutButton and not child.is_queued_for_deletion():
			child.set_icon_visible(false)
			child.custom_minimum_size.y = 64
			child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	show_modal("继续游戏 · 选择存档", "请选择要继续的冒险" if result.success else result.message, "载入")
	_confirm_button.disabled = true
	_cancel_button.disabled = false
	_close_button.disabled = false
	_cancel_button.grab_focus()
	_fit_panel()

func _select_slot(path: String) -> void:
	_selected = path
	_confirm_button.disabled = false
	var index := 0
	for child in slot_list._items_box.get_children():
		if child is SproutButton and not child.is_queued_for_deletion():
			child.add_theme_stylebox_override("normal", SproutTheme.selected_style() if _slots[index].id == path else SproutTheme.unselected_style())
			index += 1
	for slot in _slots:
		if slot.id == path:
			_body_label.text = "已选择：" + slot.name + ("\n此存档" + slot.problem + "，载入时将显示详细原因。" if not slot.problem.is_empty() else "")

func set_busy(value: bool) -> void:
	_confirm_button.disabled = value or _selected.is_empty()
	_cancel_button.disabled = value
	_close_button.disabled = value

func show_problem(message: String) -> void:
	set_busy(false)
	_body_label.text = message

func _on_confirm_pressed() -> void:
	if not _selected.is_empty() and not _confirm_button.disabled:
		slot_requested.emit(_selected)
