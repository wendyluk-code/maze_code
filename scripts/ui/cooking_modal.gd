extends Control
## 首单烹饪 QTE：开始时扣料一次，起锅时只锁定一次品质。

signal cooking_started
signal cooking_finished(result: Dictionary)
signal cancelled

const RECIPE_ID := "salt_grilled_rockmane"
const GaugeScript := preload("res://scripts/cooking/gauge.gd")
const Judgement := preload("res://scripts/cooking/qte_judgement.gd")
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")

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
var _start_button: Button
var _finish_button: Button
var _cancel_button: Button
var _message: Label
var _quality_label: Label
var _title: Label
var _recipe_label: Label

func _ready() -> void:
	add_to_group("cooking_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
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
	panel.position = Vector2(-360, -290)
	panel.size = Vector2(720, 580)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	_title = title
	title.text = "料理台"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", SproutTheme.INK)
	outer.add_child(title)
	var recipe_label := Label.new()
	_recipe_label = recipe_label
	recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_label.add_theme_font_size_override("font_size", 17)
	recipe_label.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
	outer.add_child(recipe_label)
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

func open_for_order(requested_recipe_id: String = RECIPE_ID) -> void:
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("collapse_details"):
		tracker.collapse_details()
	recipe_id = requested_recipe_id
	recipe = Catalog.get_recipe(recipe_id)
	if recipe.is_empty():
		_message.text = "暂时没有这道料理的配方。"
		return
	_round_duration = float(recipe.get("round_duration", 3.6))
	_perfect_width = float(recipe.get("perfect_width", 0.16))
	_good_width = float(recipe.get("good_width", 0.38))
	_title.text = "料理台 · %s" % str(recipe.get("name", recipe_id))
	var ingredients: Dictionary = recipe.get("ingredients", {})
	_recipe_label.text = "所需材料：" + _format_ingredients(ingredients) + "\n开始前可以取消；开始后材料只扣一次。"
	_started = false
	_finished = false
	_locked_stars = 0
	_locked_pointer = 0.0
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

func _format_ingredients(ingredients: Dictionary) -> String:
	var parts: Array[String] = []
	var names := {"rockmane_meat": "岩鬃肉", "rock_salt": "岩盐"}
	for item_id in ingredients:
		parts.append("%s ×%d" % [str(names.get(str(item_id), item_id)), int(ingredients[item_id])])
	return "   ".join(parts)

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
		var messages := {
			"no_canonical_order": "请先到前台接下首单。",
			"ingredients_not_claimed": "请先到仓库领取食材。",
			"insufficient_ingredients": "食材不足，需要岩鬃肉和岩盐。",
			"already_started": "这份料理已经开始或完成。",
			"already_cooked": "料理已经完成，请前往前台交付。",
		}
		_message.text = str(messages.get(result.get("reason", ""), "料理台暂时无法开始。"))
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
	_finished = true
	var sm := get_node_or_null("/root/SaveManager")
	var result: Dictionary = sm.finish_first_order_cooking(stars, pointer) if sm != null else {"success": false, "reason": "save_manager_missing"}
	if not bool(result.get("success", false)):
		_message.text = "保存失败，请再次点击起锅重试（品质已锁定）。"
		_finished = false
		_finish_button.disabled = false
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
	if not _open or not _started or _finished or _locked_stars > 0:
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
