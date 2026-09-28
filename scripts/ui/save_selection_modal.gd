extends SproutModal
## 组合现有弹窗、滚动列表、按钮和主题；业务状态由 SaveManager 管理。

signal slot_requested(path: String)

var slot_list: SproutScrollList
var _selected := ""
var _slots: Array = []
var _mode := "list"
var _busy := false
var _name_edit: LineEdit
var _manage_actions: HBoxContainer
var _rename_button: SproutButton
var _delete_button: SproutButton

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
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "输入存档名称（最多 40 字）"
	_name_edit.max_length = 40
	_name_edit.custom_minimum_size.y = 48
	outer.add_child(_name_edit)
	outer.move_child(_name_edit, slot_list.get_index() + 1)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_confirm_pressed())
	_manage_actions = HBoxContainer.new()
	_manage_actions.add_theme_constant_override("separation", 10)
	outer.add_child(_manage_actions)
	outer.move_child(_manage_actions, _name_edit.get_index() + 1)
	_rename_button = _management_button("重命名")
	_delete_button = _management_button("删除")
	_rename_button.pressed.connect(func() -> void: _begin_edit("rename"))
	_delete_button.pressed.connect(func() -> void: _begin_edit("delete"))
	_confirm_button.set_focus_visual(true)
	_cancel_button.set_focus_visual(true)
	resized.connect(_fit_panel)
	_fit_panel()
	_panel.minimum_size_changed.connect(_fit_panel)
	_name_edit.hide()

func _management_button(label: String) -> SproutButton:
	var button := SproutButton.new()
	button.configure(label)
	button.set_icon_visible(false)
	button.set_focus_visual(true)
	button.custom_minimum_size = Vector2(120, 44)
	_manage_actions.add_child(button)
	return button

func _exit_tree() -> void:
	# 列表组件在有条目时暂时移除空提示；组合方负责释放这枚离树控件。
	if is_instance_valid(slot_list) and is_instance_valid(slot_list._empty_label) and slot_list._empty_label.get_parent() == null:
		slot_list._empty_label.free()

func _fit_panel() -> void:
	var panel_size := Vector2(minf(660, size.x - 32), minf(490, size.y - 32))
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.position = (size - _panel.size) * 0.5

func open_slots(selected_path := "") -> void:
	_mode = "list"
	_busy = false
	_name_edit.hide()
	slot_list.show()
	_manage_actions.show()
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
	_rename_button.disabled = true
	_delete_button.disabled = true
	for slot in _slots:
		if slot.id == selected_path:
			_select_slot(selected_path)
	_cancel_button.grab_focus()
	_fit_panel()

func _select_slot(path: String) -> void:
	if _busy or _mode != "list":
		return
	_selected = path
	_confirm_button.disabled = false
	_rename_button.disabled = false
	_delete_button.disabled = false
	var index := 0
	for child in slot_list._items_box.get_children():
		if child is SproutButton and not child.is_queued_for_deletion():
			child.add_theme_stylebox_override("normal", SproutTheme.selected_style() if _slots[index].id == path else SproutTheme.unselected_style())
			index += 1
	for slot in _slots:
		if slot.id == path:
			_body_label.text = "已选择：" + slot.name + ("\n此存档" + slot.problem + "，载入时将显示详细原因。" if not slot.problem.is_empty() else "")

func set_busy(value: bool) -> void:
	_busy = value
	_confirm_button.disabled = value or _selected.is_empty()
	_cancel_button.disabled = value
	_close_button.disabled = value
	_rename_button.disabled = value or _selected.is_empty()
	_delete_button.disabled = value or _selected.is_empty()

func show_problem(message: String) -> void:
	set_busy(false)
	_body_label.text = message

func _on_confirm_pressed() -> void:
	if _selected.is_empty() or _confirm_button.disabled or _busy:
		return
	if _mode == "list":
		slot_requested.emit(_selected)
		return
	set_busy(true)
	var result: Dictionary = SaveManager.rename_save_slot(_selected, _name_edit.text) if _mode == "rename" else SaveManager.delete_save_slot(_selected)
	if not result.success:
		show_problem(result.message)
		return
	var retained := _selected if _mode == "rename" else ""
	open_slots(retained)

func _begin_edit(mode: String) -> void:
	if _busy or _selected.is_empty() or _mode != "list":
		return
	_mode = mode
	var label := ""
	for slot in _slots:
		if slot.id == _selected:
			label = slot.name
	slot_list.hide()
	_manage_actions.hide()
	_name_edit.visible = mode == "rename"
	show_modal("重命名存档" if mode == "rename" else "删除存档", "为“" + label + "”输入新名称。" if mode == "rename" else "确定删除“" + label + "”？\n此操作无法撤销。", "保存名称" if mode == "rename" else "确认删除")
	if mode == "rename":
		_name_edit.text = label
		_name_edit.grab_focus()
		_name_edit.select_all()
	else:
		_cancel_button.grab_focus()

func _on_cancel_pressed() -> void:
	if _busy:
		return
	if _mode != "list":
		open_slots(_selected)
	else:
		super._on_cancel_pressed()

func _on_close_pressed() -> void:
	_on_cancel_pressed()

func _input(event: InputEvent) -> void:
	# LineEdit 会消费 Esc；在 GUI 分发之前统一处理编辑取消。
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()
