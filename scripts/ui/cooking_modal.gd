extends Control
## 首单烹饪 QTE：开始时扣料一次，起锅时只锁定一次品质。

signal cooking_started
signal cooking_finished(result: Dictionary)
signal cancelled

const RECIPE_ID := "salt_grilled_rockmane"
const GaugeScript := preload("res://scripts/cooking/gauge.gd")
const Judgement := preload("res://scripts/cooking/qte_judgement.gd")
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")

var _open := false
var _started := false
var _finished := false
var _elapsed := 0.0
var _round_duration := 3.6
var _perfect_width := 0.16
var _good_width := 0.38
var _gauge: Control
var _start_button: Button
var _finish_button: Button
var _cancel_button: Button
var _message: Label
var _quality_label: Label

func _ready() -> void:
	add_to_group("cooking_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _build() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.07, 0.05, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.theme = SproutTheme.make_theme()
	panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -250)
	panel.size = Vector2(720, 500)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "料理台 · 盐烤岩鬃肉"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(title)
	var recipe := Label.new()
	recipe.text = "所需材料：岩鬃肉 ×1   岩盐 ×1\n开始前可以取消；开始后材料只扣一次，不能重试刷品质。"
	recipe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe.add_theme_font_size_override("font_size", 17)
	recipe.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	outer.add_child(recipe)
	_gauge = Control.new()
	_gauge.set_script(GaugeScript)
	_gauge.custom_minimum_size = Vector2(560, 110)
	outer.add_child(_gauge)
	var hint := Label.new()
	hint.text = "指针往返一次；中央精准区=3星，外围良好区=2星，其余=1星。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	outer.add_child(hint)
	_message = Label.new()
	_message.text = "准备好后点击开始"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 18)
	_message.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(_message)
	_quality_label = Label.new()
	_quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quality_label.add_theme_font_size_override("font_size", 23)
	_quality_label.add_theme_color_override("font_color", Color("#356849"))
	outer.add_child(_quality_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	outer.add_child(actions)
	_cancel_button = Button.new()
	_cancel_button.text = "取消"
	_cancel_button.custom_minimum_size = Vector2(130, 52)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	actions.add_child(_cancel_button)
	_start_button = Button.new()
	_start_button.text = "开始烹饪"
	_start_button.custom_minimum_size = Vector2(170, 52)
	_start_button.pressed.connect(_on_start_pressed)
	actions.add_child(_start_button)
	_finish_button = Button.new()
	_finish_button.text = "起锅"
	_finish_button.custom_minimum_size = Vector2(130, 52)
	_finish_button.disabled = true
	_finish_button.pressed.connect(_on_finish_pressed)
	actions.add_child(_finish_button)

func open_for_order() -> void:
	var recipe := Catalog.get_recipe(RECIPE_ID)
	_round_duration = float(recipe.get("round_duration", 3.6))
	_perfect_width = float(recipe.get("perfect_width", 0.16))
	_good_width = float(recipe.get("good_width", 0.38))
	_started = false
	_finished = false
	_elapsed = 0.0
	_quality_label.text = ""
	_message.text = "准备好后点击开始"
	_start_button.disabled = false
	_finish_button.disabled = true
	_cancel_button.disabled = false
	_gauge.perfect_width = _perfect_width
	_gauge.good_width = _good_width
	_gauge.set_pointer(-1.0)
	_open = true
	visible = true
	_set_tutorial_suppressed(true)

func close_modal() -> void:
	_open = false
	visible = false
	_set_tutorial_suppressed(false)

func _on_start_pressed() -> void:
	if not _open or _started or _finished:
		return
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("start_first_order_cooking"):
		_message.text = "料理台暂时无法使用"
		return
	var result: Dictionary = sm.start_first_order_cooking()
	if not bool(result.get("success", false)):
		_message.text = "无法开始：" + str(result.get("reason", "unknown"))
		return
	_started = true
	_start_button.disabled = true
	_finish_button.disabled = false
	_cancel_button.disabled = true
	_message.text = "火候进行中，点击起锅锁定当前品质"
	cooking_started.emit()

func _on_finish_pressed() -> void:
	if not _open or not _started or _finished:
		return
	_finish_result(Judgement.stars_for_position(_gauge.pointer_position, _perfect_width, _good_width))

func _finish_result(stars: int) -> void:
	if _finished:
		return
	_finished = true
	var sm := get_node_or_null("/root/SaveManager")
	var pointer := float(_gauge.pointer_position)
	var result: Dictionary = sm.finish_first_order_cooking(stars, pointer) if sm != null else {"success": false, "reason": "save_manager_missing"}
	if not bool(result.get("success", false)):
		_message.text = "保存失败，本次未结算，请重试。"
		_finished = false
		return
	_quality_label.text = "品质：%d 星" % stars
	_message.text = "【盐烤岩鬃肉】已完成，请前往前台交付"
	_finish_button.disabled = true
	cooking_finished.emit(result)

func _on_cancel_pressed() -> void:
	if not _open or _started:
		return
	close_modal()
	cancelled.emit()

func _process(delta: float) -> void:
	if not _open or not _started or _finished:
		return
	_elapsed += delta
	var pointer := Judgement.position_at(_elapsed, _round_duration)
	_gauge.set_pointer(pointer)
	# 一次完整往返无人操作自动按普通品质结算。
	if _elapsed >= _round_duration:
		_finish_result(1)

func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func _set_tutorial_suppressed(value: bool) -> void:
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide) and guide.has_method("set_modal_suppressed"):
		guide.set_modal_suppressed(value)
