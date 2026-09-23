class_name SproutCard
extends PanelContainer
## Sprout Lands 像素卡面：纯视觉组件，可由 SproutCardData 替换占位数据。

const CARD_SIZE := Vector2(340, 420)
const INK := Color("#3f2a1d")
const CREAM := Color("#fff4dc")
const SPROUT_BG := Color("#d9e8bb")
const SPROUT_BORDER := Color("#6d985f")
const TIESHAN_BG := Color("#d9b18c")
const TIESHAN_BORDER := Color("#8d5841")

var _data: SproutCardData
var _portrait: TextureRect
var _character_label: Label
var _role_label: Label
var _title_label: Label
var _cost_label: Label
var _type_label: Label
var _effect_label: Label
var _value_label: Label
var _rarity_label: Label
var _number_label: Label

func _ready() -> void:
	theme = SproutTheme.make_theme()
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build()
	if _data:
		_apply_data(_data)

func configure(data: SproutCardData) -> SproutCard:
	_data = data
	if is_node_ready():
		_apply_data(data)
	return self

func _build() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)

	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 34
	content.add_child(top)
	_character_label = _label("", 22)
	_character_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_character_label)
	_role_label = _label("", 18)
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_role_label)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(0, 136)
	portrait_frame.add_theme_stylebox_override("panel", _flat(Color("#fff8e7"), Color("#a07c4e"), 2, 8))
	content.add_child(portrait_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.custom_minimum_size = Vector2(0, 130)
	portrait_frame.add_child(_portrait)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 43
	content.add_child(title_row)
	_title_label = _label("", 25)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.clip_text = false
	title_row.add_child(_title_label)
	_cost_label = _label("", 17)
	_cost_label.custom_minimum_size = Vector2(82, 38)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_cost_label)

	var type_panel := PanelContainer.new()
	type_panel.add_theme_stylebox_override("panel", _flat(Color("#fff8e7"), Color("#a07c4e"), 1, 5))
	content.add_child(type_panel)
	_type_label = _label("", 16)
	_type_label.custom_minimum_size.y = 27
	type_panel.add_child(_type_label)

	var effect_panel := PanelContainer.new()
	effect_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_panel.add_theme_stylebox_override("panel", _flat(Color("#fff8e7"), Color("#a07c4e"), 1, 6))
	content.add_child(effect_panel)
	_effect_label = _label("", 18)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_label.custom_minimum_size = Vector2(0, 67)
	effect_panel.add_child(_effect_label)

	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size.y = 42
	content.add_child(bottom)
	_value_label = _label("", 16)
	_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_value_label)
	_rarity_label = _label("", 15)
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_rarity_label)
	_number_label = _label("", 15)
	_number_label.custom_minimum_size.x = 54
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_number_label)

func _apply_data(data: SproutCardData) -> void:
	var tieshan := data.faction == "tieshan"
	var bg := TIESHAN_BG if tieshan else SPROUT_BG
	var border := TIESHAN_BORDER if tieshan else SPROUT_BORDER
	add_theme_stylebox_override("panel", _flat(bg, border, 4, 10))
	_character_label.text = data.character_name
	_role_label.text = "定位：" + data.role
	_title_label.text = data.title
	_cost_label.text = "费用\n" + data.cost
	_type_label.text = "类型：" + data.card_type
	_effect_label.text = "效果\n" + data.effect
	_value_label.text = "核心数值：" + data.value
	_rarity_label.text = data.rarity
	_number_label.text = "No.%02d" % data.number
	_portrait.texture = data.portrait
	for label in [_character_label, _role_label, _title_label, _cost_label, _type_label, _effect_label, _value_label, _rarity_label, _number_label]:
		label.add_theme_color_override("font_color", INK)

func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _flat(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
