extends Control
## 料理台：真实携带原料、可制作配方和一次性消耗的火候判定。
signal cooking_started
signal cooking_finished(result: Dictionary)
signal result_confirmed(result: Dictionary)
signal cancelled

const RECIPE_ID := "salt_grilled_rockmane"
const GaugeScript := preload("res://scripts/cooking/cooking_visual.gd")
const Judgement := preload("res://scripts/cooking/qte_judgement.gd")
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")
const DISH_ICON: Texture2D = preload("res://assets/ui/ingredients/salt_grilled_rockmane.png")

var recipe_id := RECIPE_ID
var recipe: Dictionary = {}
var _open := false
var _started := false
var _finished := false
var _locked_stars := 0
var _locked_pointer := 0.0
var _elapsed := 0.0
var _round_duration := 3.6
var _perfect_width := 0.16
var _good_width := 0.38
var _gauge: Control
var _panel: PanelContainer
var _panel_fill: ColorRect
var _start_button: Button
var _finish_button: Button
var _cancel_button: Button
var _message: Label
var _quality_label: Label
var _title: Label
var _recipe_label: Label
var _recipe_row: PanelContainer
var _recipe_choices: HBoxContainer
var _available_recipe_ids: Array[String] = []
var _carried: Dictionary = {}
var _result_popup: Control
var _pending_result: Dictionary = {}

func _ready() -> void:
	add_to_group("cooking_modal")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = get_viewport().get_visible_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	visible = false
	_build()
	get_viewport().size_changed.connect(_layout_panel)
	call_deferred("_layout_panel")

func _build() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.07, 0.05, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_panel_fill = ColorRect.new()
	_panel_fill.color = SproutTheme.CREAM
	_panel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_fill)
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	var frame := SproutTheme.panel_style(Color("#fff2d4"))
	frame.draw_center = false
	_panel.add_theme_stylebox_override("panel", frame)
	add_child(_panel)
	var content := Control.new()
	content.custom_minimum_size = Vector2(600, 542)
	_panel.add_child(content)
	_title = _label("料理台", 26, SproutTheme.INK)
	_place(content, _title, Rect2(45, 0, 510, 35))
	var line := ColorRect.new()
	line.color = Color("#e7d6b5")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(content, line, Rect2(10, 39, 580, 1))
	_cancel_button = Button.new()
	_cancel_button.text = "×"
	_cancel_button.tooltip_text = "关闭（Esc）"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_place(content, _cancel_button, Rect2(558, 0, 34, 34))
	_gauge = Control.new()
	_gauge.set_script(GaugeScript)
	_place(content, _gauge, Rect2(15, 43, 570, 350))
	_recipe_row = PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color("#f5e5c6")
	row_style.border_color = Color("#dfcaa5")
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(7)
	row_style.content_margin_left = 12
	row_style.content_margin_right = 12
	_recipe_row.add_theme_stylebox_override("panel", row_style)
	_place(content, _recipe_row, Rect2(60, 400, 480, 58))
	_recipe_choices = HBoxContainer.new()
	_recipe_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_recipe_choices.add_theme_constant_override("separation", 12)
	_recipe_row.add_child(_recipe_choices)
	_recipe_label = _label("可烹饪料理", 16, SproutTheme.INK_MUTED)
	_recipe_choices.add_child(_recipe_label)
	_message = _label("", 17, SproutTheme.INK_MUTED)
	_place(content, _message, Rect2(0, 462, 600, 22))
	_quality_label = _label("", 21, Color("#356849"))
	_place(content, _quality_label, Rect2(0, 462, 600, 22))
	# 两对象同位置交替可见，保留旧测试和调用方的按钮引用。
	_start_button = Button.new()
	_start_button.text = "开始烹饪"
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.pressed.connect(_on_start_pressed)
	_place(content, _start_button, Rect2(188, 488, 224, 52))
	_finish_button = Button.new()
	_finish_button.text = "结束烹饪"
	_finish_button.add_theme_font_size_override("font_size", 22)
	_finish_button.pressed.connect(_on_finish_pressed)
	_place(content, _finish_button, Rect2(188, 488, 224, 52))
	_finish_button.visible = false
	_finish_button.disabled = true
	_result_popup = Control.new()
	_result_popup.set_script(preload("res://scripts/ui/cooking_result_popup.gd"))
	add_child(_result_popup)
	_result_popup.confirmed.connect(_on_result_confirmed)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _place(parent: Node, child: Control, rect: Rect2) -> void:
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size

func _layout_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	size = viewport_size
	if not is_instance_valid(_panel):
		return
	_panel.size = Vector2(636, 574)
	var factor := minf(1.0, minf((viewport_size.x - 24.0) / _panel.size.x, (viewport_size.y - 24.0) / _panel.size.y))
	_panel.scale = Vector2.ONE * maxf(factor, 0.1)
	_panel.position = (viewport_size - _panel.size * _panel.scale) * 0.5
	_panel_fill.position = _panel.position + Vector2(9, 9) * _panel.scale
	_panel_fill.size = (_panel.size - Vector2(18, 18)) * _panel.scale

func open_for_order(requested_recipe_id: String = RECIPE_ID) -> void:
	_result_popup.cancel()
	_pending_result.clear()
	_panel.show()
	_panel_fill.show()
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("collapse_details"):
		tracker.collapse_details()
	_started = false
	_finished = false
	_locked_stars = 0
	_locked_pointer = 0.0
	_elapsed = 0.0
	_quality_label.text = ""
	_message.text = ""
	_start_button.visible = true
	_finish_button.visible = false
	_finish_button.disabled = true
	_cancel_button.disabled = false
	_gauge.set_running(false)
	_gauge.set_pointer(0.0)
	var sm := get_node_or_null("/root/SaveManager")
	_carried = sm.carried_ingredients() if sm != null else {}
	_available_recipe_ids.clear()
	if sm != null:
		_available_recipe_ids.assign(sm.available_cooking_recipes())
	recipe_id = requested_recipe_id if requested_recipe_id in _available_recipe_ids else (_available_recipe_ids[0] if not _available_recipe_ids.is_empty() else "")
	_apply_recipe()
	_render_recipe_choices()
	_gauge.set_ingredients(_carried)
	_start_button.disabled = recipe.is_empty()
	if recipe.is_empty():
		_message.text = "请先领取食材" if _carried.is_empty() else "暂无可制作的已解锁料理"
	_open = true
	visible = true
	_layout_panel()
	_set_tutorial_suppressed(true)
	# 中断恢复写盘失败时仅可重试固定 1 星，不能再次扣料或判定。
	if sm != null and sm.cooking_state().status == "active":
		recipe_id = str(sm.cooking_state().get("recipe_id", RECIPE_ID))
		_apply_recipe()
		_render_recipe_choices()
		_started = true
		_locked_stars = 1
		_locked_pointer = 0.0
		_gauge.set_pointer(0.0)
		_gauge.set_ingredients(recipe.get("ingredients", {}))
		_show_finish_button()
		_message.text = "烹饪已中断，以 1 星恢复；结束烹饪以保存"
	elif sm != null and (sm.cooking_state().status == "locked" or sm.cooked_quality() > 0):
		_start_button.disabled = true
		_finished = true
		_message.text = "料理已完成，请前往吧台交付"

func _apply_recipe() -> void:
	recipe = Catalog.get_recipe(recipe_id)
	_round_duration = float(recipe.get("round_duration", 3.6))
	_perfect_width = float(recipe.get("perfect_width", 0.16))
	_good_width = float(recipe.get("good_width", 0.38))
	_gauge.perfect_width = _perfect_width
	_gauge.good_width = _good_width
	_gauge.queue_redraw()

func _render_recipe_choices() -> void:
	for child in _recipe_choices.get_children():
		if child != _recipe_label:
			_recipe_choices.remove_child(child)
			child.queue_free()
	_recipe_label.text = "可烹饪料理" if not recipe.is_empty() else "暂无可烹饪料理"
	var ids: Array[String] = _available_recipe_ids.duplicate()
	if ids.is_empty() and not recipe.is_empty():
		ids.append(recipe_id)
	if ids.size() > 1:
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(260, 46)
		picker.disabled = _started
		for index in range(ids.size()):
			var entry := Catalog.get_recipe(ids[index])
			picker.add_item(str(entry.get("name", ids[index])))
			if ids[index] == recipe_id:
				picker.select(index)
		picker.item_selected.connect(func(index: int): _select_recipe(ids[index]))
		_recipe_choices.add_child(picker)
		return
	for id in ids:
		var entry := Catalog.get_recipe(id)
		var choice := Button.new()
		choice.text = str(entry.get("name", id))
		choice.add_theme_font_size_override("font_size", 20)
		choice.icon = _dish_icon(id)
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 43)
		choice.add_theme_constant_override("h_separation", 8)
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.custom_minimum_size = Vector2(176, 46)
		choice.disabled = _started
		if ids.size() == 1:
			choice.disabled = false
			choice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			choice.focus_mode = Control.FOCUS_NONE
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				choice.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		else:
			choice.toggle_mode = true
			choice.button_pressed = id == recipe_id
		choice.pressed.connect(_select_recipe.bind(id))
		_recipe_choices.add_child(choice)

func _dish_icon(id: String) -> Texture2D:
	if id != RECIPE_ID:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = DISH_ICON
	texture.region = Rect2(279, 424, 696, 505)
	return texture

func _select_recipe(id: String) -> void:
	if _started or not id in _available_recipe_ids:
		return
	recipe_id = id
	_apply_recipe()
	_render_recipe_choices()

func close_modal() -> void:
	_result_popup.cancel()
	_pending_result.clear()
	_open = false
	visible = false
	_gauge.set_running(false)
	_set_tutorial_suppressed(false)

func _show_finish_button() -> void:
	_start_button.disabled = true
	_start_button.visible = false
	_finish_button.visible = true
	_finish_button.disabled = false
	_cancel_button.disabled = true
	for child in _recipe_choices.get_children():
		if child is Button and child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			child.disabled = true

func _on_start_pressed() -> void:
	if not _open or _started or _finished or recipe.is_empty():
		return
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		_message.text = "料理台暂时无法使用"
		return
	var result: Dictionary = sm.start_cooking(recipe_id)
	if not bool(result.get("success", false)):
		var messages := {"no_canonical_order": "请先到前台接单", "ingredients_not_claimed": "请先到仓库领取食材", "insufficient_ingredients": "携带食材不足", "recipe_locked": "这道料理尚未解锁", "already_started": "这份料理已经开始", "already_cooked": "料理已完成，请前往吧台交付", "save_failed": "保存失败，请重试开始烹饪"}
		_message.text = str(messages.get(result.get("reason", ""), "料理台暂时无法开始"))
		return
	_started = true
	_elapsed = 0.0
	_show_finish_button()
	# 已开火时展示本次投入的配方份数，而非扣除后的携带余额。
	_gauge.set_ingredients(recipe.get("ingredients", {}))
	_gauge.set_pointer(Judgement.position_at(0.0, _round_duration))
	_gauge.set_running(true)
	_message.text = ""
	cooking_started.emit()

func _on_finish_pressed() -> void:
	if not _open or not _started or _finished:
		return
	if _locked_stars > 0:
		_finish_result(_locked_stars, _locked_pointer)
	else:
		_finish_result(Judgement.stars_for_position(_gauge.pointer_position, _perfect_width, _good_width), _gauge.pointer_position)

func _finish_result(stars: int, pointer := -2.0) -> void:
	if _finished:
		return
	if _locked_stars > 0:
		stars = _locked_stars
		pointer = _locked_pointer
	elif pointer < -1.5:
		pointer = _gauge.pointer_position
	_locked_stars = clampi(stars, 1, 3)
	_locked_pointer = clampf(float(pointer), -1.0, 1.0)
	_gauge.set_pointer(_locked_pointer)
	_gauge.set_running(false)
	_finished = true
	var sm := get_node_or_null("/root/SaveManager")
	var result: Dictionary = sm.finish_first_order_cooking(_locked_stars, _locked_pointer) if sm != null else {"success": false, "reason": "save_manager_missing"}
	if not bool(result.get("success", false)):
		_message.text = "保存失败，品质已锁定；请再次结束烹饪"
		_finished = false
		_finish_button.disabled = false
		return
	_message.text = ""
	_finish_button.disabled = true
	_pending_result = result.duplicate(true)
	_panel.hide()
	_panel_fill.hide()
	_result_popup.present(str(recipe.get("name", "料理")), _dish_icon(recipe_id), int(result.get("quality", _locked_stars)))
	cooking_finished.emit(result)

func _on_result_confirmed() -> void:
	if not _open or _pending_result.is_empty():
		return
	var result := _pending_result.duplicate(true)
	close_modal()
	result_confirmed.emit(result)

func _on_cancel_pressed() -> void:
	if not _open or _started:
		return
	close_modal()
	cancelled.emit()

func _process(delta: float) -> void:
	if not _open or not _started or _finished or _locked_stars > 0:
		return
	_elapsed += delta
	_gauge.set_pointer(Judgement.position_at(_elapsed, _round_duration))
	if _elapsed >= _round_duration:
		_finish_result(1)

func _input(event: InputEvent) -> void:
	if _result_popup.visible:
		return
	if not _open or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()
	elif event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if _started:
			_on_finish_pressed()
		else:
			_on_start_pressed()

func _set_tutorial_suppressed(value: bool) -> void:
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide) and guide.has_method("set_modal_suppressed"):
		guide.set_modal_suppressed(value)
