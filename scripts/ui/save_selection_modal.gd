extends SproutModal
## 组合现有弹窗、滚动列表、按钮和主题；业务状态由 SaveManager 管理。

signal slot_requested(path: String)

var slot_list: SproutScrollList
var _selected := ""
var _slots: Array = []
var _mode := "list"
var _busy := false
var _name_edit: LineEdit
var _rows: Dictionary = {}
var _edit_modal: SproutModal
var _edit_scroll := 0

## 确认后由业务结果决定是否关闭，失败时保留输入与错误提示。
class EditModal extends SproutModal:
	func _on_confirm_pressed() -> void:
		if not _confirm_button.disabled:
			confirmed.emit()

## 局部矢量图标，不依赖字体是否包含铅笔或垃圾桶字形。
class SlotAction extends Button:
	var action := "rename"

	func _ready() -> void:
		# 行内图标只用线条颜色反馈状态，不继承普通按钮的底色与边框。
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for changed in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]:
			changed.connect(queue_redraw)

	func _draw() -> void:
		var ink := SproutTheme.INK_MUTED if disabled else SproutTheme.INK
		if not disabled:
			if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED]:
				ink = Color("#284b30")
			elif is_hovered() or has_focus():
				ink = Color("#43754b")
		var origin := (size - Vector2(24, 24)) * 0.5
		draw_set_transform(origin)
		if action == "rename":
			draw_polyline(PackedVector2Array([Vector2(4, 16), Vector2(15, 5), Vector2(20, 10), Vector2(9, 21), Vector2(3, 22), Vector2(4, 16)]), ink, 2.0, true)
			draw_line(Vector2(12, 8), Vector2(17, 13), ink, 2.0, true)
		else:
			draw_polyline(PackedVector2Array([Vector2(5, 7), Vector2(6, 21), Vector2(18, 21), Vector2(19, 7)]), ink, 2.0, true)
			draw_line(Vector2(3, 6), Vector2(21, 6), ink, 2.0, true)
			draw_polyline(PackedVector2Array([Vector2(9, 6), Vector2(9, 3), Vector2(15, 3), Vector2(15, 6)]), ink, 2.0, true)
			for x in [10, 14]:
				draw_line(Vector2(x, 10), Vector2(x, 17), ink, 2.0, true)
		draw_set_transform(Vector2.ZERO)

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
	_edit_modal = EditModal.new()
	add_child(_edit_modal)
	_edit_modal._overlay.color = Color(0.08, 0.12, 0.08, 0.25)
	_edit_modal.confirmed.connect(_confirm_edit)
	_edit_modal.closed.connect(_edit_closed)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "输入存档名称（最多 40 字）"
	_name_edit.max_length = 40
	_name_edit.custom_minimum_size.y = 48
	var edit_outer := _edit_modal._body_label.get_parent()
	edit_outer.add_child(_name_edit)
	edit_outer.move_child(_name_edit, _edit_modal._body_label.get_index() + 1)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _confirm_edit())
	_confirm_button.set_focus_visual(true)
	_cancel_button.set_focus_visual(false)
	resized.connect(_fit_panel)
	_fit_panel()
	_panel.minimum_size_changed.connect(_fit_panel)
	_edit_modal._panel.minimum_size_changed.connect(_fit_panel)
	_name_edit.hide()

func _decorate_row(row: SproutButton, slot: Dictionary) -> void:
	row.text = ""
	row.set_icon_visible(false)
	row.custom_minimum_size.y = 76
	row.tooltip_text = slot.name + (" · " + slot.problem if not slot.problem.is_empty() else "")
	var labels := VBoxContainer.new()
	labels.name = "Fields"
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(labels)
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	labels.offset_left = 18
	labels.offset_right = -116
	labels.offset_top = 10
	labels.offset_bottom = -10
	for value in [slot.name, slot.time_text]:
		var label := Label.new()
		label.text = value
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		labels.add_child(label)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	actions.offset_left = -104
	actions.offset_right = -12
	actions.offset_top = -22
	actions.offset_bottom = 22
	actions.add_theme_constant_override("separation", 4)
	for kind in ["rename", "delete"]:
		var button := SlotAction.new()
		button.name = kind
		button.action = kind
		button.tooltip_text = "重命名" if kind == "rename" else "删除"
		button.custom_minimum_size = Vector2(44, 44)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void:
			_select_slot(slot.id)
			_begin_edit(kind))
		actions.add_child(button)
	_rows[slot.id] = row

func _exit_tree() -> void:
	# 列表组件在有条目时暂时移除空提示；组合方负责释放这枚离树控件。
	if is_instance_valid(slot_list) and is_instance_valid(slot_list._empty_label) and slot_list._empty_label.get_parent() == null:
		slot_list._empty_label.free()

func _fit_panel() -> void:
	var panel_size := Vector2(minf(660, size.x - 32), minf(490, size.y - 32))
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.position = (size - _panel.size) * 0.5
	if is_instance_valid(_edit_modal):
		_edit_modal._panel.custom_minimum_size = Vector2(minf(460, size.x - 64), 260)
		_edit_modal._panel.size = _edit_modal._panel.get_combined_minimum_size()
		_edit_modal._panel.position = (size - _edit_modal._panel.size) * 0.5

func open_slots(selected_path := "") -> void:
	_mode = "list"
	_busy = false
	_edit_modal.hide()
	_name_edit.hide()
	slot_list.show()
	_rows.clear()
	_selected = ""
	var result := SaveManager.list_save_slots()
	_slots = result.slots
	slot_list._empty_label.text = "还没有存档\n选择“新游戏”开始新的冒险" if result.success else "存档列表暂时不可用\n请排除读取问题后重试"
	var items: Array = []
	for slot in _slots:
		items.append({"id": slot.id, "label": ""})
	slot_list.set_items(items)
	var index := 0
	for child in slot_list._items_box.get_children():
		if child is SproutButton and not child.is_queued_for_deletion():
			_decorate_row(child, _slots[index])
			index += 1
	show_modal("继续游戏 · 选择存档", "请选择要继续的冒险" if result.success else result.message, "载入")
	_confirm_button.disabled = true
	_cancel_button.disabled = false
	_close_button.disabled = false
	for slot in _slots:
		if slot.id == selected_path:
			_select_slot(selected_path)
	_cancel_button.grab_focus()
	_fit_panel()
	set_busy(false)

func _select_slot(path: String) -> void:
	if _busy or _mode != "list":
		return
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
	_busy = value
	var blocked := value or _mode != "list"
	_confirm_button.disabled = blocked or _selected.is_empty()
	_cancel_button.disabled = blocked
	_close_button.disabled = blocked
	for row in _rows.values():
		row.disabled = blocked
		for action in row.get_node("Actions").get_children():
			action.disabled = blocked
	_edit_modal._confirm_button.disabled = value
	_edit_modal._cancel_button.disabled = value
	_edit_modal._close_button.disabled = value
	_name_edit.editable = not value

func show_problem(message: String) -> void:
	set_busy(false)
	_body_label.text = message

func _on_confirm_pressed() -> void:
	if _selected.is_empty() or _confirm_button.disabled or _busy or _mode != "list":
		return
	slot_requested.emit(_selected)

func _confirm_edit() -> void:
	if _busy or _mode == "list" or not _edit_modal.visible:
		return
	set_busy(true)
	var result: Dictionary = SaveManager.rename_save_slot(_selected, _name_edit.text) if _mode == "rename" else SaveManager.delete_save_slot(_selected)
	if not result.success:
		set_busy(false)
		_edit_modal._body_label.text = result.message
		return
	var action := _mode
	var retained := _selected if _mode == "rename" else ""
	open_slots(retained)
	slot_list._scroll.set_deferred("scroll_vertical", _edit_scroll)
	_restore_edit_focus(action)

func _begin_edit(mode: String) -> void:
	if _busy or _selected.is_empty() or _mode != "list":
		return
	_mode = mode
	_edit_scroll = slot_list._scroll.scroll_vertical
	var label := ""
	for slot in _slots:
		if slot.id == _selected:
			label = slot.name
	set_busy(false)
	_name_edit.visible = mode == "rename"
	_edit_modal.show_modal("重命名存档" if mode == "rename" else "删除存档", "为“" + label + "”输入新名称。" if mode == "rename" else "确定删除“" + label + "”？\n此操作无法撤销。", "保存名称" if mode == "rename" else "确认删除")
	# 将键盘导航约束在上层，避免 Tab 或方向键进入下层滚动区。
	var controls: Array[Control] = [_edit_modal._close_button, _edit_modal._cancel_button, _edit_modal._confirm_button]
	if mode == "rename":
		controls.push_front(_name_edit)
	for index in controls.size():
		var current := controls[index]
		var previous := current.get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
		var next := current.get_path_to(controls[(index + 1) % controls.size()])
		current.focus_previous = previous
		current.focus_next = next
		current.focus_neighbor_left = previous
		current.focus_neighbor_top = previous
		current.focus_neighbor_right = next
		current.focus_neighbor_bottom = next
	_fit_panel()
	if mode == "rename":
		_name_edit.text = label
		_name_edit.grab_focus()
		_name_edit.select_all()
	else:
		_edit_modal._cancel_button.grab_focus()

func _edit_closed() -> void:
	var action := _mode
	_mode = "list"
	set_busy(false)
	_restore_edit_focus(action)

func _restore_edit_focus(action: String) -> void:
	if _rows.has(_selected):
		_rows[_selected].get_node("Actions/" + action).grab_focus()
	else:
		_cancel_button.grab_focus()

func _on_cancel_pressed() -> void:
	if _busy:
		return
	if _mode != "list":
		_edit_modal.close_modal()
	else:
		super._on_cancel_pressed()

func _on_close_pressed() -> void:
	_on_cancel_pressed()

func _input(event: InputEvent) -> void:
	# LineEdit 会消费 Esc；在 GUI 分发之前统一处理编辑取消。
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()
