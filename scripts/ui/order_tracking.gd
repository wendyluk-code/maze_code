extends Control
## 首单任务入口：进度读取已提交的任务状态，不等同于库存。

const PANEL_WIDTH := 260.0
# 入口与详情共用左边缘，沿用16像素屏幕安全边距。
const PANEL_POSITION := Vector2(16, 66)
const EXPAND_DURATION := 0.25
const COMPLETION_COLOR := Color("#dce8c6")
const STATUS_ICON = preload("res://scripts/ui/task_status_icon.gd")
const COMPLETION_DURATION := 0.42
const DISH_ICON: Texture2D = preload("res://assets/ui/ingredients/salt_grilled_rockmane.png")
const MEAT_ICON: Texture2D = preload("res://assets/ui/ingredients/rockmane_meat.png")
const SALT_ICON: Texture2D = preload("res://assets/ui/ingredients/rock_salt.png")
var _panel: PanelContainer
var _task_button: Button
var _notification: Label
var _order_status: Button
var _meat_status: Button
var _salt_status: Button
var _cook_status: Button
var _ingredients_title: Label
var _cook_title: Label
var _expanded := false
var _expand_tween: Tween
var _known_order_id := ""
var _subtask_panels: Array[PanelContainer] = []
var _explanation_highlight := false
var _highlight_tween: Tween
var _completion_tween: Tween
var _completion_kind := ""
var _completion_waiting := false
var _status_icons: Dictionary = {}
var _presented := {"ingredients": false, "cooking": false, "order": false}
var _completion_queue: Array[String] = []
var _order_main: PanelContainer
var _order_title: Label
var _order_name: Label
var _order_subtasks: Control
var _exploration_task: PanelContainer
var _exploration_title: Label
var _exploration_name: Label
var _exploration_status: Button
var _empty_tasks: Label
var _quest_view_signature := ""
var _refresh_elapsed := 0.0

func _ready() -> void:
	add_to_group("order_tracking")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = SproutTheme.make_theme()
	visible = false
	_build()
	_set_explanation_glow(0.0)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("refresh_saved_state")

func _exit_tree() -> void:
	_immediate_cleanup()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_immediate_cleanup()

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		refresh_saved_state()
	if not _expanded:
		return
	var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
	var cooking := get_tree().get_first_node_in_group("cooking_modal")
	var departure := get_tree().get_first_node_in_group("departure_panel")
	var other_ui_open: bool = is_instance_valid(warehouse) and warehouse.visible
	other_ui_open = other_ui_open or (is_instance_valid(cooking) and cooking.visible)
	other_ui_open = other_ui_open or (is_instance_valid(departure) and bool(departure.get("_open")))
	other_ui_open = other_ui_open or (is_instance_valid(departure) and departure.has_method("_cards_open") and departure._cards_open())
	if other_ui_open:
		collapse_details()

func get_layout_side() -> String:
	return "left"

func entry_rect() -> Rect2:
	return _task_button.get_global_rect()

func _input(event: InputEvent) -> void:
	if not _expanded or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed:
		collapse_details()
	elif event is InputEventMouseButton and event.pressed:
		# 入口按钮自行切换；点击面板内部保留阅读，点击外部收起。
		if _task_button.get_global_rect().has_point(event.position) or _panel.get_global_rect().has_point(event.position):
			return
		collapse_details()
	# 不消费事件，同一次按键仍可移动角色或触发场景交互。

func _build() -> void:
	_task_button = Button.new()
	_task_button.name = "TaskButton"
	_task_button.custom_minimum_size = Vector2(154, 42)
	_task_button.focus_mode = Control.FOCUS_NONE
	_task_button.icon = SproutTheme.icon(21)
	_task_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_task_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_task_button.expand_icon = true
	_task_button.pressed.connect(_toggle_tasks)
	add_child(_task_button)
	_task_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_task_button.position = Vector2(16, 16)
	_notification = _make_label("●", 16, Color("#d6493e"))
	_notification.add_theme_color_override("font_outline_color", Color("#fff4dc"))
	_notification.add_theme_constant_override("outline_size", 3)
	add_child(_notification)
	_notification.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_notification.position = Vector2(11, 7)
	_notification.visible = false
	_panel = PanelContainer.new()
	_panel.name = "TaskPanel"
	_panel.size = Vector2(PANEL_WIDTH, 276.0)
	_panel.custom_minimum_size = _panel.size
	_panel.add_theme_stylebox_override("panel", _box(Color("#fff2d4"), Color("#b99055"), 1, 12))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = _panel_position()
	_panel.visible = false
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	var main := PanelContainer.new()
	_order_main = main
	main.name = "OrderTask"
	main.add_theme_stylebox_override("panel", _main_task_style())
	outer.add_child(main)
	var main_content := VBoxContainer.new()
	main_content.add_theme_constant_override("separation", 6)
	main.add_child(main_content)
	var heading := HBoxContainer.new()
	main_content.add_child(heading)
	heading.add_theme_constant_override("separation", 6)
	_add_status_icon(heading, "order")
	var title := _make_label("订单任务", 19, SproutTheme.INK)
	_order_title = title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_order_status = _make_status_button()
	heading.add_child(_order_status)
	var dish_row := HBoxContainer.new()
	dish_row.add_theme_constant_override("separation", 8)
	main_content.add_child(dish_row)
	dish_row.add_child(_make_item_icon("salt_grilled_rockmane"))
	_order_name = _make_label("交出盐烤岩鬃肉", 18, SproutTheme.INK)
	dish_row.add_child(_order_name)
	var indent := MarginContainer.new()
	_order_subtasks = indent
	indent.add_theme_constant_override("margin_left", 12)
	outer.add_child(indent)
	var subtasks := VBoxContainer.new()
	subtasks.name = "Subtasks"
	subtasks.add_theme_constant_override("separation", 8)
	indent.add_child(subtasks)
	var ingredients := _make_subtask(subtasks, "IngredientsTask")
	_ingredients_title = _make_label("领取食材", 16, SproutTheme.INK)
	_add_task_heading(ingredients, _ingredients_title, "ingredients")
	_meat_status = _add_item_row(ingredients, "岩鬃肉", "rockmane_meat")
	_salt_status = _add_item_row(ingredients, "岩盐", "rock_salt")
	var cooking := _make_subtask(subtasks, "CookingTask")
	_cook_title = _make_label("制作料理", 16, SproutTheme.INK)
	_add_task_heading(cooking, _cook_title, "cooking")
	_cook_status = _add_item_row(cooking, "盐烤岩鬃肉", "salt_grilled_rockmane")
	_build_exploration(outer)
	_empty_tasks = _make_label("暂无进行中的任务", 16, SproutTheme.INK_MUTED)
	outer.add_child(_empty_tasks)
	_update_entry()

func _panel_position() -> Vector2:
	return PANEL_POSITION

func _main_task_style() -> StyleBoxFlat:
	return _box(Color("#d8b16c"), Color("#987039"), 2, 10)

func _build_exploration(parent: Node) -> void:
	_exploration_task = PanelContainer.new()
	_exploration_task.name = "ExplorationTask"
	_exploration_task.add_theme_stylebox_override("panel", _main_task_style())
	parent.add_child(_exploration_task)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_exploration_task.add_child(content)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	content.add_child(heading)
	_add_status_icon(heading, "exploration")
	_exploration_title = _make_label("探索任务", 19, SproutTheme.INK)
	_exploration_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_exploration_title)
	_exploration_status = _make_status_button()
	heading.add_child(_exploration_status)
	_exploration_name = _make_label("", 18, SproutTheme.INK)
	_exploration_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_exploration_name.custom_minimum_size.x = PANEL_WIDTH - 48.0
	content.add_child(_exploration_name)
	# 子任务由注册表预留；未设计时不生成占位进度或虚假的完成条件。

func _sync_quest_content() -> void:
	var snapshot: Dictionary = SaveManager.quest_snapshot()
	_notification.visible = SaveManager.has_unread_quests()
	var signature := JSON.stringify(snapshot.active)
	if signature == _quest_view_signature:
		return
	_quest_view_signature = signature
	var order_active := false
	var exploration: Dictionary = {}
	for quest in snapshot.active:
		if quest.type == "order":
			order_active = true
			_order_title.text = str(quest.type_name)
			_order_name.text = str(quest.title)
			for subtask in quest.subtasks:
				if subtask.id == "collect_ingredients":
					_ingredients_title.text = str(subtask.title)
				elif subtask.id == "cook_dish":
					_cook_title.text = str(subtask.title)
		elif quest.type == "exploration":
			exploration = quest
	# 已完成主任务仅保留在本地日志，完成动效也不能重新显示它。
	var show_order := order_active
	_order_main.visible = show_order
	_order_subtasks.visible = show_order
	_exploration_task.visible = not exploration.is_empty()
	if not exploration.is_empty():
		_exploration_title.text = str(exploration.type_name)
		_exploration_name.text = str(exploration.title)
		_set_task_state("exploration", false)
	_empty_tasks.visible = not show_order and exploration.is_empty()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.reset_size()

func _add_status_icon(parent: Node, kind: String) -> void:
	var icon := STATUS_ICON.new()
	icon.name = kind.capitalize() + "StatusIcon"
	parent.add_child(icon)
	_status_icons[kind] = icon

func _add_task_heading(parent: Node, title: Label, kind: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	_add_status_icon(row, kind)
	row.add_child(title)

func _box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _make_subtask(parent: Node, node_name: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _box(Color("#fff8e8"), Color("#dfcaa5"), 1, 10))
	_subtask_panels.append(panel)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	return content

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_item_icon(item_id: String) -> TextureRect:
	var texture := AtlasTexture.new()
	# 收紧透明留白，仅调整显示区域，保留用户提供的原图。
	match item_id:
		"rockmane_meat":
			texture.atlas = MEAT_ICON
			texture.region = Rect2(77, 83, 106, 95)
		"rock_salt":
			texture.atlas = SALT_ICON
			texture.region = Rect2(83, 88, 97, 90)
		"salt_grilled_rockmane":
			texture.atlas = DISH_ICON
			texture.region = Rect2(279, 424, 696, 505)
	var icon := TextureRect.new()
	icon.name = item_id + "Icon"
	icon.texture = texture
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _add_item_row(parent: Node, item_name: String, item_id: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(_make_item_icon(item_id))
	var label := _make_label(item_name, 16, SproutTheme.INK_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var status := _make_status_button()
	row.add_child(status)
	return status

func _make_status_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 24)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_font_size_override("font_size", 14)
	_set_counter(button, 0)
	return button

func _set_counter(button: Button, count: int) -> void:
	var complete := count >= 1
	button.text = "1/1" if complete else "0/1"
	var style := _box(Color("#dce8c6") if complete else Color("#f4e2bd"), Color("#b7a17b"), 1, 3)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", SproutTheme.INK)

func _toggle_tasks() -> void:
	if _explanation_highlight:
		return
	if _expanded:
		collapse_details()
		return
	_expanded = true
	SaveManager.mark_active_quests_read()
	_quest_view_signature = ""
	refresh_saved_state()
	_update_entry()
	_animate_expansion()

func collapse_details() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and _panel.is_ancestor_of(focus):
		focus.release_focus()
	_cancel_completion()
	set_explanation_highlight(false)
	if not _expanded and not _panel.visible:
		return
	_expanded = false
	_update_entry()
	_animate_collapse()

## 接单说明仅以暖色外发光呼吸强调子任务，沿用原有边框与布局。
func set_explanation_highlight(enabled: bool) -> void:
	if enabled == _explanation_highlight:
		return
	_explanation_highlight = enabled
	if enabled and not _expanded:
		_expanded = true
		_update_entry()
		_animate_expansion()
	if _highlight_tween != null:
		_highlight_tween.kill()
		_highlight_tween = null
	_set_explanation_glow(1.0 if enabled else 0.0)
	if enabled:
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_highlight_tween.tween_method(_set_explanation_glow, 1.0, 0.4, 0.55)
		_highlight_tween.tween_method(_set_explanation_glow, 0.4, 1.0, 0.55)

func _set_explanation_glow(strength: float) -> void:
	for panel in _subtask_panels:
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.shadow_size = 10 if _explanation_highlight else 0
		style.shadow_color = Color(Color("#f4b83e"), 0.95 * strength if _explanation_highlight else 0.0)

func _update_entry() -> void:
	_task_button.text = "当前任务  ▴" if _expanded else "当前任务  ▾"

func _stop_expansion() -> void:
	if _expand_tween != null:
		_expand_tween.kill()
		_expand_tween = null
	_panel.position = _panel_position()
	_panel.modulate.a = 1.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _animate_expansion() -> void:
	# 整块轻移并淡入，不缩放文字；关闭时直接取消，无延迟重新显示回调。
	_stop_expansion()
	_panel.visible = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = _panel_position() - Vector2(0, 10)
	_panel.modulate.a = 0.0
	_expand_tween = create_tween().set_parallel(true)
	_expand_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_expand_tween.tween_property(_panel, "position", _panel_position(), EXPAND_DURATION)
	_expand_tween.tween_property(_panel, "modulate:a", 1.0, EXPAND_DURATION)
	_expand_tween.chain().tween_callback(_finish_expansion)

func _finish_expansion() -> void:
	_expand_tween = null
	if _completion_waiting:
		_apply_completion_feedback(_completion_kind)

func _animate_collapse() -> void:
	if not _panel.visible:
		return
	_stop_expansion()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expand_tween = create_tween().set_parallel(true)
	_expand_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_expand_tween.tween_property(_panel, "position", _panel_position() - Vector2(0, 10), EXPAND_DURATION)
	_expand_tween.tween_property(_panel, "modulate:a", 0.0, EXPAND_DURATION)
	_expand_tween.chain().tween_callback(_finish_collapse)

func _finish_collapse() -> void:
	_expand_tween = null
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = _panel_position()
	_panel.modulate.a = 1.0

func _immediate_cleanup() -> void:
	_cancel_completion()
	_explanation_highlight = false
	if _highlight_tween != null:
		_highlight_tween.kill()
		_highlight_tween = null
	if _expand_tween != null:
		_expand_tween.kill()
		_expand_tween = null
	if _completion_tween != null:
		_completion_tween.kill()
		_completion_tween = null
	_completion_kind = ""
	_completion_waiting = false
	_set_explanation_glow(0.0)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = _panel_position()
	_panel.modulate.a = 1.0
	_expanded = false
	_update_entry()

## 中央指引据此限制长文案宽度，避免与展开的任务面板重叠。
func expanded_panel_rect() -> Rect2:
	return _panel.get_global_rect() if visible and _panel.visible else Rect2()

func _restore_saved_order() -> void:
	refresh_saved_state()

func _saved_completion() -> Dictionary:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return {}
	var order: Dictionary = sm.current_order()
	if str(order.get("status", "none")) not in ["in_progress", "completed"]:
		return {}
	var completed := str(order.get("status")) == "completed"
	if str(order.get("id", "")) != sm.FIRST_ORDER_ID:
		var cooked: bool = sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) > 0
		return {"order": completed, "ingredients": cooked or sm.available_cooking_recipes().size() > 0 or sm.cooking_state().status == "active" or completed,
			"cooking": cooked or completed}
	var progress: Dictionary = sm.first_order_progress()
	return {"order": completed, "ingredients": bool(progress.get("ingredients_claimed", false)) or completed,
		"cooking": str(progress.get("next_step", "")) in ["deliver", "chapter_wrap_up"] or completed}

func refresh_saved_state() -> void:
	var state := _saved_completion()
	if not _completion_kind.is_empty() and not bool(state.get(_completion_kind, false)):
		_cancel_completion()
	if state.is_empty():
		_known_order_id = ""
		_presented = {"ingredients": false, "cooking": false, "order": false}
	else:
		_known_order_id = str(get_node("/root/SaveManager").current_order().get("id", ""))
	for kind in state:
		if kind == _completion_kind or kind in _completion_queue:
			continue
		_set_task_state(kind, bool(state[kind]))
		_presented[kind] = bool(state[kind])
	_sync_quest_content()
	var quests: Dictionary = SaveManager.quest_snapshot()
	# 首单入口建立后保留空态，但不读取历史任务来填充面板。
	visible = not quests.active.is_empty() or not _known_order_id.is_empty()
	if not _expanded and _expand_tween == null:
		_panel.visible = false

func _targets(kind: String) -> Array:
	match kind:
		"ingredients": return [_meat_status, _salt_status]
		"cooking": return [_cook_status]
		"order": return [_order_status]
		"exploration": return [_exploration_status]
	return []

func _set_task_state(kind: String, complete: bool) -> void:
	for button in _targets(kind):
		_set_counter(button, int(complete))
		button.scale = Vector2.ONE
	_status_icons[kind].progress = 1.0 if complete else 0.0

## 回执只触发一次；恢复存档只呈现最终态。展开结束才开始同步染色和描勾。
func play_completion_feedback(kind: String) -> void:
	if str(SaveManager.current_order().get("status", "")) != "in_progress":
		_cancel_completion()
		refresh_saved_state()
		return
	var state := _saved_completion()
	if not bool(state.get(kind, false)) or bool(_presented.get(kind, false)) or kind == _completion_kind or kind in _completion_queue:
		return
	if not _completion_kind.is_empty():
		_completion_queue.append(kind)
		return
	_completion_kind = kind
	visible = true
	_sync_quest_content()
	_set_task_state(kind, false)
	if not _expanded or not _panel.visible:
		_expanded = true
		_update_entry()
		_completion_waiting = true
		_animate_expansion()
	elif _expand_tween != null:
		_completion_waiting = true
	else:
		_apply_completion_feedback(kind)

func play_task_completion_feedback(kind: String) -> void:
	play_completion_feedback(kind)

func _apply_completion_feedback(kind: String) -> void:
	_completion_waiting = false
	if _completion_kind != kind or not is_inside_tree():
		return
	_completion_tween = create_tween().set_parallel(true)
	_completion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for button in _targets(kind):
		button.text = "1/1"
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		_completion_tween.tween_property(style, "bg_color", COMPLETION_COLOR, COMPLETION_DURATION)
	_completion_tween.tween_property(_status_icons[kind], "progress", 1.0, COMPLETION_DURATION)
	_completion_tween.chain().tween_callback(_finish_completion.bind(kind))

func _finish_completion(kind: String) -> void:
	_completion_tween = null
	_presented[kind] = true
	_completion_kind = ""
	_set_task_state(kind, true)
	_sync_quest_content()
	if not _completion_queue.is_empty():
		var next: String = _completion_queue.pop_front()
		play_completion_feedback(next)

func _cancel_completion() -> void:
	if _completion_tween != null:
		_completion_tween.kill()
		_completion_tween = null
	_completion_waiting = false
	_completion_kind = ""
	_completion_queue.clear()
	var state := _saved_completion()
	for kind in _status_icons:
		var completed := bool(state.get(kind, false))
		_set_task_state(kind, completed)
		_presented[kind] = completed

func cancel_feedback() -> void:
	_immediate_cleanup()

func show_order_receipt(order) -> void:
	if order is Dictionary:
		var order_id := str(order.get("id", ""))
		var is_new_receipt := not order_id.is_empty() and order_id != _known_order_id
		refresh_saved_state()
		if not is_new_receipt or not visible or order_id != _known_order_id:
			return
		_expanded = true
		_sync_quest_content()
		_update_entry()
		_animate_expansion()

func hide_tracking() -> void:
	_immediate_cleanup()
	visible = false
	_notification.visible = false
