class_name SproutCard
extends PanelContainer
## 共享卡面：已批准素材切片 + 动态文字；无正式切图时保留旧通用布局。

const CARD_SIZE := Vector2(300, 500)
const LAYOUT_VERSION := "edge_icons_v4"
const EFFECT_FONT_SIZE := 20
const EFFECT_MIN_FONT_SIZE := 18
const EFFECT_WIDTH := 220.0
const READABLE_EFFECT_WIDTH := 196.0
const EFFECT_TEXT_INSET := 8.0
const EFFECT_TOP := 297.0
const EFFECT_STATS_HEIGHT := 95.0
const EFFECT_SPELL_HEIGHT := 143.0
const INK := Color("#3f2a1d")
const CREAM := Color("#fff4dc")
const MATERIAL := preload("res://scripts/ui/components/sprout_card_material.gd")
const ART_CATALOG := preload("res://scripts/ui/components/card_art_catalog.gd")
const SPROUT_BG := Color("#d9e8bb")
const SPROUT_BORDER := Color("#6d985f")
const TIESHAN_BG := Color("#d9b18c")
const TIESHAN_BORDER := Color("#8d5841")
const DESATURATE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 pixel = COLOR;
	float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray), pixel.a);
}
"""
const ART_WINDOW_SHADER := """
shader_type canvas_item;
uniform bool desaturate = false;
uniform sampler2D window_mask : filter_linear, repeat_disable;
uniform vec2 source_origin = vec2(0.0);
uniform vec2 source_extent = vec2(1.0);
uniform vec2 cover_scale = vec2(1.0);
varying vec4 art_modulate;
void vertex() {
	art_modulate = COLOR;
}
void fragment() {
	vec2 window_uv = (UV - source_origin) / source_extent;
	vec2 source_uv = source_origin + ((window_uv - vec2(0.5)) * cover_scale + vec2(0.5)) * source_extent;
	COLOR = texture(TEXTURE, source_uv) * art_modulate;
	COLOR.a *= texture(window_mask, window_uv).a;
	if (desaturate) COLOR.rgb = vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)));
}
"""

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
var _ability_hint: CanvasLayer
var _generic_content: Control
var _material_root: Control
var _material_base: TextureRect
var _material_art: TextureRect
var _material_canvas: Control
var _title_leaf_left: TextureRect
var _title_leaf_right: TextureRect
var _material_title: Label
var _material_type: Label
var _material_effect: Label
var _effect_sections: VBoxContainer
var _attack_art: TextureRect
var _health_art: TextureRect
var _satiety_art: TextureRect
var _mana_art: TextureRect
var _shield_art: TextureRect
var _material_stat_attack: Label
var _material_stat_health: Label
var _satiety_slot: Label
var _mana_slot: Label
var _shield_slot: Label
var _hunger_art: TextureRect
var _hunger_slot: Label
var _revive_art: TextureRect
var _revive_slot: Label
var _desaturate_material: ShaderMaterial
var _cost_slots: Array[Label] = []
var _ability_details_enabled := false
var _battle_context := false
var _readable_battle_text := false

func set_readable_battle_text(enabled: bool) -> void:
	_readable_battle_text = enabled
	if is_node_ready() and _data: _apply_material(_data)
var _battle_state: Dictionary = {}
var _skill_resolution: Dictionary = {}

## 仅在使用事务成功后传入条件结果；不预判、不改变业务状态。
func set_skill_resolution(values: Dictionary) -> void:
	_skill_resolution = values.duplicate(true)
	if is_node_ready() and _data:
		_apply_material(_data)

## 显示层副本：不修改共享原始卡牌数据，也不参与战斗结算。
func set_battle_state(values: Dictionary) -> void:
	_battle_state = values.duplicate(true)
	if is_node_ready() and _data:
		_apply_material(_data)
		_apply_battle_state()

func _apply_battle_state() -> void:
	if not _battle_context or _battle_state.is_empty() or not _data.is_role_card:
		_apply_status_display()
		return
	# 实时状态只覆盖已获显示资格的数字，不能让源表缺值重新出现。
	if _material_stat_attack.visible: _material_stat_attack.text = str(_battle_state.get("attack", _data.attack))
	if _material_stat_health.visible: _material_stat_health.text = str(_battle_state.get("hp", _data.health))
	if _satiety_slot.visible: _satiety_slot.text = _number_text(int(_battle_state.get("satiety", -1)))
	if _mana_slot.visible: _mana_slot.text = _number_text(int(_battle_state.get("mana", -1)))
	if _shield_slot.visible: _shield_slot.text = str(int(_battle_state.get("shield", 0)))
	_satiety_slot.add_theme_color_override("font_color", Color("#ad3434") if _battle_state.get("satiety", -1) == 0 else Color("#462618"))
	# 卡面正文只由名称、类型和技能组成；护盾仅通过右下图标/数值显示。
	_value_label.text = ""
	_apply_status_display()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()

func _ready() -> void:
	theme = SproutTheme.make_theme()
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build()
	_ability_hint = preload("res://scripts/ui/components/ability_hint.gd").new()
	_ability_hint.card = self
	_ability_hint.enabled = _ability_details_enabled
	add_child(_ability_hint)
	if _data:
		_apply_data(_data)

func configure(data: SproutCardData) -> SproutCard:
	if _data == null or _data.id != data.id:
		_skill_resolution.clear()
	_data = data
	if is_node_ready():
		_apply_data(data)
	return self

func set_battle_context(value: bool, _legacy_level: int = 0) -> void:
	# 第二参数仅兼容旧调用；战斗与收录都不存在等级。
	_battle_context = value
	if is_node_ready() and _data:
		_apply_material(_data)

## 仅由冒险者之家查看卡牌，或战斗点击展开详情的调用方显式开启。
## 普通列表与入队展示不自动启用；退出详情时调用 false。
func set_ability_details_enabled(value: bool) -> void:
	_ability_details_enabled = value
	if is_instance_valid(_ability_hint):
		_ability_hint.enabled = value
		if not value:
			_ability_hint.dismiss()

func _build() -> void:
	var content := VBoxContainer.new()
	_generic_content = content
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	_material_root = Control.new()
	_material_root.name = "MaterialCard"
	_material_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material_root.visible = false
	add_child(_material_root)
	_material_canvas = Control.new()
	_material_canvas.size = CARD_SIZE
	_material_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material_root.add_child(_material_canvas)
	_material_art = _material_texture("", MATERIAL.edge_rect("illustration_yaya"))
	_material_base = _edge_texture("frame")
	_build_material_labels()

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
	_ability_hint.ability_text = data.effect
	var tieshan := data.faction == "tieshan"
	var bg := TIESHAN_BG if tieshan else SPROUT_BG
	var border := TIESHAN_BORDER if tieshan else SPROUT_BORDER
	add_theme_stylebox_override("panel", _flat(bg, border, 4, 10))
	_character_label.text = data.character_name
	_role_label.text = "定位：" + data.role
	_title_label.text = data.title
	_cost_label.text = ""
	_cost_label.visible = false
	_type_label.text = "类型：" + data.card_type
	_effect_label.text = "效果\n" + data.effect
	_value_label.text = ""
	_rarity_label.text = data.rarity
	_number_label.text = "No.%02d" % data.number
	_portrait.texture = data.portrait
	_apply_material(data)
	for label in [_character_label, _role_label, _title_label, _cost_label, _type_label, _effect_label, _value_label, _rarity_label, _number_label]:
		label.add_theme_color_override("font_color", INK)
	_refresh_layout()

func _material_texture(path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not path.is_empty():
		node.texture = load(path) as Texture2D
	_material_canvas.add_child(node)
	return node

func _edge_texture(id: String) -> TextureRect:
	return _material_texture(MATERIAL.EDGE_ROOT + MATERIAL.edge_layer(id).file, MATERIAL.edge_rect(id))

func _build_material_labels() -> void:
	_title_leaf_left = _edge_texture("title_leaf_left")
	_title_leaf_right = _edge_texture("title_leaf_right")
	_edge_texture("type_rule_left")
	_edge_texture("type_rule_right")
	_attack_art = _edge_texture("attack")
	_health_art = _edge_texture("health")
	_satiety_art = _edge_texture("satiety")
	_mana_art = _edge_texture("mana")
	for entry in [[_attack_art, "attack"], [_health_art, "health"], [_satiety_art, "satiety"], [_mana_art, "mana"]]:
		entry[0].texture = MATERIAL.status_icon(entry[1])
		entry[0].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 金盾只新增独立属性层，原件与edge_v4卡框保持原样。
	# 护盾复用生命值槽：无生命值时落在红框位置，有生命值时上移到蓝框位置。
	_shield_art = _material_texture("res://assets/ui/card_materials/card_display_v2/gold_shield.png", Rect2(228, 398, 54, 54))
	_shield_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_material_title = _material_label("", Rect2(58, 223.5, 184, 31), 24)
	_material_type = _material_label("", Rect2(118, 258.5, 64, 22), 14)
	_material_type.add_theme_color_override("font_color", Color("#926044"))
	_material_effect = _material_label("", Rect2((CARD_SIZE.x - EFFECT_WIDTH) / 2, EFFECT_TOP, EFFECT_WIDTH, EFFECT_STATS_HEIGHT), EFFECT_FONT_SIZE)
	_material_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_material_effect.add_theme_constant_override("line_spacing", 0)
	# 字形绘制保留安全留白；实际换行宽度扣除左右相同的内边距。
	var effect_style := StyleBoxEmpty.new()
	effect_style.content_margin_left = EFFECT_TEXT_INSET
	effect_style.content_margin_right = EFFECT_TEXT_INSET
	_material_effect.add_theme_stylebox_override("normal", effect_style)
	_material_stat_attack = _material_label("", Rect2(22.8, 414.3, 39, 38), 32)
	_material_stat_health = _material_label("", Rect2(235.4, 414.3, 39, 38), 32)
	_satiety_slot = _material_label("", Rect2(252.1, 93.7, 39, 38), 30)
	_mana_slot = _material_label("", Rect2(253.3, 168.8, 39, 38), 30)
	var number_font := FontVariation.new()
	number_font.base_font = ThemeDB.fallback_font
	number_font.variation_embolden = 0.8
	for label in [_material_stat_attack, _material_stat_health, _satiety_slot, _mana_slot]:
		label.add_theme_font_override("font", number_font)
		label.add_theme_color_override("font_color", Color("#fff7df"))
		label.add_theme_color_override("font_outline_color", Color("#22506e") if label == _mana_slot else (Color("#3b4930") if label == _material_stat_attack else Color("#8c3328")))
		label.add_theme_constant_override("outline_size", 2)
	_satiety_slot.add_theme_color_override("font_color", Color("#462618"))
	_satiety_slot.add_theme_constant_override("outline_size", 0)
	_shield_slot = _material_label("", Rect2(235.4, 414.3, 39, 38), 30)
	_shield_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_slot.add_theme_font_override("font", number_font)
	_shield_slot.add_theme_color_override("font_color", Color("#fff7df"))
	_shield_slot.add_theme_color_override("font_outline_color", Color("#805124"))
	_shield_slot.add_theme_constant_override("outline_size", 2)
	for index in 2:
		_cost_slots.append(_resource_slot(Rect2(115 + index * 75, 287, 70, 23), Color("#f3e6cc")))
	_hunger_art = _material_texture("", Rect2(153, 0, 60, 60))
	_hunger_art.texture = MATERIAL.status_icon("hunger")
	_hunger_slot = _material_label("+2", Rect2(159, 10, 48, 40), 27)
	_revive_art = _material_texture("", Rect2(0, 0, 90, 120))
	_revive_art.texture = MATERIAL.status_icon("revive")
	_hunger_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_revive_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_revive_slot = _material_label("", Rect2(0, 0, 80, 64), 46)
	for label in [_hunger_slot, _revive_slot]:
		label.add_theme_font_override("font", number_font)
		label.add_theme_color_override("font_color", Color("#fff7df"))
		label.add_theme_color_override("font_outline_color", Color("#6318b6"))
		label.add_theme_constant_override("outline_size", 2)
	var shader := Shader.new()
	shader.code = DESATURATE_SHADER
	_desaturate_material = ShaderMaterial.new()
	_desaturate_material.shader = shader
	_apply_status_display()

func _layout_shield_slot(has_health: bool) -> void:
	# 属性轻微跨出可见卡框，仍完全位于300×500设计画布内。
	_attack_art.position = Vector2(8, 409)
	_attack_art.size = Vector2(62, 68)
	_material_stat_attack.position = Vector2(19, 430)
	_health_art.position = Vector2(239, 409)
	_health_art.size = Vector2(54, 68)
	_material_stat_health.position = Vector2(247, 433)
	_mana_art.position = Vector2(78 if _attack_art.visible else 12, 409)
	_mana_art.size = Vector2(54, 68)
	_mana_slot.position = _mana_art.position + Vector2(8, 24)
	var shield_size := Vector2(54, 54)
	var lift := 64.0 if has_health else 0.0
	_shield_art.size = shield_size
	_shield_art.position = Vector2(241, 477 - shield_size.y - lift)
	_shield_slot.size = Vector2(39, 38)
	_shield_slot.position = _shield_art.position + (shield_size - _shield_slot.size) * 0.5

## 显示状态只读取副本；alive缺失默认存活，revive只负责剩余回合数字。
func _apply_status_display() -> void:
	if not is_instance_valid(_revive_art): return
	var active := _battle_context and _data != null and _data.is_role_card
	var dead := active and not bool(_battle_state.get("alive", true))
	var hungry := active and _satiety_slot.visible and _satiety_slot.text == "0"
	_hunger_art.visible = hungry
	_hunger_slot.visible = hungry
	_satiety_art.size = Vector2(62, 65)
	_satiety_art.position = Vector2(86 if hungry else 119, 0)
	_satiety_slot.position = _satiety_art.position + Vector2(11, 8)
	_satiety_slot.size = Vector2(40, 38)
	# 以原卡框可见区域中心定位，而非插画开窗中心。
	var center := MATERIAL.edge_rect("frame").get_center()
	_revive_art.position = center - _revive_art.size * 0.5
	_revive_slot.position = center - _revive_slot.size * 0.5
	var remaining := int(_battle_state.get("revive", 0))
	_revive_art.visible = dead and remaining > 0
	_revive_slot.visible = _revive_art.visible
	_revive_slot.text = str(remaining)
	for child in _material_canvas.get_children():
		if child == _revive_art or child == _revive_slot: continue
		if child == _material_art:
			if child.material is ShaderMaterial: child.material.set_shader_parameter("desaturate", dead)
		elif child is CanvasItem:
			child.material = _desaturate_material if dead else null

func _resource_slot(rect: Rect2, fill: Color) -> Label:
	var slot := _material_label("", rect, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("#c7aa7e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("normal", style)
	slot.add_theme_constant_override("line_spacing", 1)
	return slot

func _material_label(value: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#462618"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material_canvas.add_child(label)
	return label

func _apply_material(data: SproutCardData) -> void:
	var source := data.material_path
	if source.is_empty():
		source = MATERIAL.path_for(data.character_name, data.title, data.card_type, data.is_role_card)
	# 有统一插画的怪物同样使用已批准模板，而不是回退通用卡面。
	if source.is_empty() and not ART_CATALOG.path_for(data.id).is_empty():
		source = MATERIAL.YAYA_ROLE
	var art_path := MATERIAL.art_path_for(source)
	if art_path.is_empty() or not ResourceLoader.exists(art_path):
		_generic_content.visible = true
		_material_root.visible = false
		return
	_generic_content.visible = false
	_material_root.visible = true
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_material_art.texture = data.illustration_override if data.illustration_override else load(art_path) as Texture2D
	var art_id: String = {"yaya_role": "yaya", "tieshan_role": "tieshan"}.get(data.id, data.id)
	var unified_art := ART_CATALOG.path_for(art_id)
	if not unified_art.is_empty() and ResourceLoader.exists(unified_art):
		_material_art.texture = load(unified_art) as Texture2D
	if not data.illustration_path.is_empty() and ResourceLoader.exists(data.illustration_path):
		_material_art.texture = load(data.illustration_path) as Texture2D
	_apply_art_window()
	_material_title.text = data.title if not data.is_role_card or data.card_type == "赋形牌" else data.character_name
	_material_type.text = data.card_type
	_material_effect.text = effect_display_text(data)
	var title_size := 24
	while title_size > 14 and SproutTheme.FONT_CN.get_string_size(_material_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 173:
		title_size -= 1
	_material_title.add_theme_font_size_override("font_size", title_size)
	var title_width := SproutTheme.FONT_CN.get_string_size(_material_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	_title_leaf_left.position.x = 150 - title_width / 2 - 21
	_title_leaf_right.position.x = 150 + title_width / 2 + 7
	var attack_text := display_number(data, "attack")
	var health_text := display_number(data, "health")
	if attack_text.contains("条件"):
		attack_text = attack_text.get_slice("（", 0) if _skill_resolution.get("conditional_attack_active", false) else "-"
	_attack_art.visible = _stat_visible(data, "attack", attack_text)
	_material_stat_attack.visible = _attack_art.visible
	_health_art.visible = _stat_visible(data, "health", health_text)
	_material_stat_health.visible = _health_art.visible
	_layout_shield_slot(_health_art.visible)
	_material_effect.position = Vector2((CARD_SIZE.x - EFFECT_WIDTH) / 2, EFFECT_TOP if data.is_role_card else 316.0)
	_material_effect.add_theme_font_size_override("font_size", effect_font_size(data))
	_material_effect.size = Vector2(EFFECT_WIDTH, effect_area_height(data))
	_material_effect.set_deferred("size", Vector2(EFFECT_WIDTH, effect_area_height(data)))
	if _readable_battle_text:
		# 战斗牌优先利用标题下方空白，增大正文实际像素；不改技能原文。
		var text_width := READABLE_EFFECT_WIDTH
		# 正文止于底部属性上方，避免新魔力位置遮挡长技能。
		var text_height := 125.0
		var font_size := 30
		while font_size > 18:
			var paragraph := TextParagraph.new()
			paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			paragraph.width = text_width - EFFECT_TEXT_INSET * 2
			paragraph.add_string(effect_display_text(data), SproutTheme.FONT_CN, font_size)
			if paragraph.get_size().y <= text_height: break
			font_size -= 1
		_material_effect.position = Vector2((CARD_SIZE.x - text_width) / 2, 280)
		_material_effect.size = Vector2(text_width, text_height)
		_material_effect.set_deferred("size", Vector2(text_width, text_height))
		_material_effect.add_theme_font_size_override("font_size", font_size)
	_material_stat_attack.text = attack_text
	_apply_effect_sections(data)
	_material_stat_health.text = health_text
	_material_stat_attack.add_theme_font_size_override("font_size", 32 if data.attack < 10 else 26)
	_material_stat_health.add_theme_font_size_override("font_size", 32 if data.health < 10 else 26)
	# 收录角色显示基础资源，技能显示消耗；战斗资源先设占位，再由状态副本覆盖。
	var battle_stats := _battle_context and data.is_role_card
	_satiety_slot.visible = _stat_visible(data, "satiety", display_number(data, "satiety"))
	_satiety_slot.add_theme_color_override("font_color", Color("#462618"))
	_satiety_slot.text = display_number(data, "satiety")
	if battle_stats and _satiety_slot.visible:
		_satiety_slot.text = "—"
	_mana_slot.visible = _stat_visible(data, "mana", display_number(data, "mana"))
	_mana_slot.text = display_number(data, "mana")
	if battle_stats and _mana_slot.visible:
		_mana_slot.text = "—"
	_satiety_art.visible = _satiety_slot.visible
	_mana_art.visible = _mana_slot.visible
	_satiety_slot.add_theme_font_size_override("font_size", 30 if _satiety_slot.text.length() <= 1 else 24)
	_mana_slot.add_theme_font_size_override("font_size", 30 if _mana_slot.text.length() <= 1 else 24)
	_shield_slot.visible = _stat_visible(data, "shield", display_number(data, "shield"))
	_shield_art.visible = _shield_slot.visible
	_shield_slot.text = "—" if battle_stats and _shield_slot.visible else display_number(data, "shield")
	for slot in _cost_slots:
		slot.visible = false
	if not data.is_role_card:
		if data.card_type == "料理":
			_cost_slots[1].visible = true
			_cost_slots[1].position.x = 155
			_cost_slots[1].text = {"可携带": "可携带", "不可携带": "不可携带"}.get(data.portable_dish, "携带待定")
	_apply_battle_state()

func _stat_visible(data: SproutCardData, key: String, display_text: String) -> bool:
	# 明确的源表缺值与未提供原值不同；后者兼容旧卡牌调用方。
	if data.display_values.has(key): return display_text != "-"
	var skill := data.card_type in ["赋形牌", "法术牌", "战斗牌"]
	match key:
		"attack", "health": return data.is_role_card or display_text != "-"
		"satiety": return data.is_role_card or skill
		"mana": return data.mana_enabled if data.is_role_card else (skill and display_text != "-")
		"shield": return (_battle_context and data.is_role_card) or display_text != "-"
	return false

func _apply_art_window() -> void:
	# 原批准插画的透明alpha即开窗轮廓；只读复用，不重画卡框或素材。
	var shader_material := _material_art.material as ShaderMaterial
	if shader_material == null:
		shader_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = ART_WINDOW_SHADER
		shader_material.shader = shader
		shader_material.set_shader_parameter("window_mask", load(MATERIAL.EDGE_ROOT + "layers/illustration_yaya.png"))
		_material_art.material = shader_material
	var texture := _material_art.texture
	var source_size := texture.get_size()
	var origin := Vector2.ZERO
	var extent := Vector2.ONE
	if texture is AtlasTexture:
		source_size = texture.region.size
		origin = texture.region.position / texture.atlas.get_size()
		extent = source_size / texture.atlas.get_size()
	var source_aspect := source_size.x / source_size.y
	var window_aspect := _material_art.size.x / _material_art.size.y
	var cover := Vector2(window_aspect / source_aspect, 1) if source_aspect > window_aspect else Vector2(1, source_aspect / window_aspect)
	shader_material.set_shader_parameter("source_origin", origin)
	shader_material.set_shader_parameter("source_extent", extent)
	shader_material.set_shader_parameter("cover_scale", cover)

func battle_stats_for_text(data: SproutCardData) -> bool:
	return _battle_context and data.is_role_card

static func _number_text(value: int) -> String:
	return str(value) if value >= 0 else "—"

static func display_number(data: SproutCardData, key: String) -> String:
	if data.display_values.has(key):
		return str(data.display_values[key])
	match key:
		"attack": return str(data.attack) if data.is_role_card or data.card_type == "赋形牌" else "-"
		"health": return str(data.health) if data.is_role_card or data.card_type == "赋形牌" else "-"
		"shield": return "-"
		"satiety": return _number_text(data.satiety_max) if data.is_role_card else (str(-data.satiety_cost) if data.satiety_cost >= 0 else "-")
		"mana": return _number_text(data.mana_initial) if data.is_role_card else (str(-data.mana_cost) if data.mana_cost != 0 else "-")
	return "-"

static func effect_area_height(data: SproutCardData) -> float:
	if data.is_role_card:
		return EFFECT_STATS_HEIGHT
	return 75.0 if data.card_type == "赋形牌" else 109.0


func _apply_effect_sections(data: SproutCardData) -> void:
	if not is_instance_valid(_effect_sections):
		_effect_sections = VBoxContainer.new()
		_effect_sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_effect_sections.add_theme_constant_override("separation", 5)
		_material_canvas.add_child(_effect_sections)
	for child in _effect_sections.get_children():
		_effect_sections.remove_child(child)
		child.queue_free()
	_effect_sections.visible = data.effect_sections.size() == 2
	_material_effect.visible = not _effect_sections.visible
	if not _effect_sections.visible: return
	_effect_sections.position = _material_effect.position
	_effect_sections.size = _material_effect.size
	var font_size := 24
	while font_size > 16:
		var height := 12.0
		for section in data.effect_sections:
			var paragraph := TextParagraph.new()
			paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			paragraph.width = _material_effect.size.x - EFFECT_TEXT_INSET * 2
			paragraph.add_string(str(section), SproutTheme.FONT_CN, font_size)
			height += paragraph.get_size().y
		if height <= _material_effect.size.y: break
		font_size -= 1
	for index in range(2):
		if index == 1:
			var separator := HSeparator.new()
			var line := StyleBoxLine.new()
			line.color = Color("#927349")
			line.thickness = 2
			separator.add_theme_stylebox_override("separator", line)
			separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_effect_sections.add_child(separator)
		var label := Label.new()
		label.text = str(data.effect_sections[index])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color("#462618"))
		label.add_theme_stylebox_override("normal", _material_effect.get_theme_stylebox("normal"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_effect_sections.add_child(label)

static func effect_display_text(data: SproutCardData) -> String:
	# 已批准原稿沿用原稿断句；只改变显示，不改变规则数据。
	var approved_lines := {
		"每回合一次，芽芽出击时，烹饪。": "每回合一次，\n芽芽出击时，烹饪。",
		"为你或任意一名己方角色恢复2生命。": "为你或任意一名己方角色\n恢复2生命。",
		"己方回合结束时，若芽芽在战斗区，烹饪。": "己方回合结束时，\n若芽芽在战斗区，烹饪。",
		"选择一张食材，让一名其他己方角色使用并出击。": "选择一张食材，\n让一名其他己方角色\n使用并出击。",
	}
	return approved_lines.get(data.effect, data.effect)

static func effect_font_size(data: SproutCardData) -> int:
	var available := effect_area_height(data)
	for font_size in range(EFFECT_FONT_SIZE, EFFECT_MIN_FONT_SIZE - 1, -1):
		if _effect_text_height(data, font_size) <= available:
			return font_size
	return EFFECT_MIN_FONT_SIZE

static func effect_fits(data: SproutCardData) -> bool:
	var available := effect_area_height(data)
	return _effect_text_height(data, effect_font_size(data)) <= available

static func _effect_text_height(data: SproutCardData, font_size: int) -> float:
	# 与Label中文智能换行一致；离树Label还没有主题布局，不能用于测高。
	var paragraph := TextParagraph.new()
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.width = EFFECT_WIDTH - EFFECT_TEXT_INSET * 2
	paragraph.add_string(effect_display_text(data), SproutTheme.FONT_CN, font_size)
	return paragraph.get_size().y

func _refresh_layout() -> void:
	if is_instance_valid(_material_canvas):
		var factor := minf(size.x / CARD_SIZE.x, size.y / CARD_SIZE.y)
		_material_canvas.scale = Vector2.ONE * factor
		_material_canvas.position = (size - CARD_SIZE * factor) / 2

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
