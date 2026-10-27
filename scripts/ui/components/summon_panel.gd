extends Control
## 批准稿召唤页：只显示余额与发出抽取意图，经营事务由接入方负责。
signal summon_requested(count: int, cost: int)

const ART_ROOT := "res://assets/ui/summon/"
const SINGLE_COST := 1000
const TEN_COST := 9000
const PRICE_COLOR := Color("#704421")
const SHORTAGE_COLOR := Color("#ba3029")
const MUTED_COLOR := Color("#928574")

var single_button: Button
var ten_button: Button
var single_price: Label
var ten_price: RichTextLabel
var balance_reader: Callable
var rarity_badges: Dictionary = {}
var _balance := -1
var _refresh_elapsed := 0.0

# 主视觉保留批准稿坐标；姓名用头侧无花纹圆弧底板竖排，操作区上移避开原位栅栏。
const SOURCE_SCALE := Vector2(1280.0 / 1672.0, 720.0 / 941.0)

func _ready() -> void:
	name = "SummonPanel"
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SproutTheme.make_theme()
	_art("PanelBackplate", "panel_backplate", Rect2(168, 140, 1445, 635))
	# 仅保留标题左侧叶饰，以原横线纹理补齐标题及主视觉下方的空段。
	var leaf := _art("HeadingLeaf", "", Rect2(234, 162, 52, 56))
	var leaf_texture := AtlasTexture.new()
	leaf_texture.atlas = load(ART_ROOT + "heading.png")
	leaf_texture.region = Rect2(0, 0, 52, 56)
	leaf.texture = leaf_texture
	for section in [Rect2(288, 190, 112, 8), Rect2(694, 190, 273, 8)]:
		var rule := _art("HeadingRule", "", section)
		var rule_texture := AtlasTexture.new()
		rule_texture.atlas = load(ART_ROOT + "panel_backplate.png")
		rule_texture.region = Rect2(300, 50, 100, 8)
		rule.texture = rule_texture
	_art("ApprovedArtwork", "key_visual", Rect2(350, 140, 1030, 454))
	_vertical_name("DingdangName", "叮\n当", "dingdang", Rect2(447, 389, 34, 72))
	_vertical_name("SaliaName", "萨\n莉\n亚", "salia", Rect2(980, 267, 34, 106))
	_vertical_name("YufengName", "御\n风", "yufeng", Rect2(1238, 337, 34, 72))

	single_button = _make_button("SingleDraw", "抽1次", Rect2(491.5, 594, 330, 67), 1, SINGLE_COST)
	ten_button = _make_button("TenDraw", "抽10次", Rect2(849.5, 594, 331, 67), 10, TEN_COST)
	# 文案和价格统一使用游戏字体，状态变化直接作用于原生文本。
	single_price = Label.new()
	single_price.name = "SinglePrice"
	single_price.text = "1000金币"
	single_price.position = Vector2(484.5, 668) * SOURCE_SCALE
	single_price.size = Vector2(344, 31) * SOURCE_SCALE
	single_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	single_price.add_theme_font_size_override("font_size", 18)
	single_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(single_price)
	ten_price = RichTextLabel.new()
	ten_price.name = "TenPrice"
	ten_price.bbcode_enabled = true
	ten_price.scroll_active = false
	ten_price.position = Vector2(842.5, 668) * SOURCE_SCALE
	ten_price.size = Vector2(345, 31) * SOURCE_SCALE
	ten_price.add_theme_font_override("normal_font", SproutTheme.FONT_CN)
	ten_price.add_theme_font_size_override("normal_font_size", 18)
	ten_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ten_price)
	visibility_changed.connect(_visibility_changed)
	refresh_balance()

func _vertical_name(node_name: String, caption: String, id: String, rect: Rect2) -> void:
	# 同一个连续底板容纳稀有度和竖排姓名，字标不再漂浮在旁边。
	var plate := Panel.new()
	plate.name = node_name
	plate.position = (rect.position - Vector2(14, 42)) * SOURCE_SCALE
	plate.size = Vector2(62, rect.size.y + 48) * SOURCE_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := SproutTheme.thin_panel_style(Color("#fff3da"))
	backing.border_color = Color("#b78a50")
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(17)
	backing.set_content_margin_all(0)
	plate.add_theme_stylebox_override("panel", backing)
	add_child(plate)
	rarity_badges[id] = preload("res://scripts/ui/components/rarity_badge.gd").attach(plate, id, Rect2(Vector2(5, 5) * SOURCE_SCALE, Vector2(52, 34) * SOURCE_SCALE))
	var label := Label.new()
	label.text = caption
	label.position = Vector2(0, 42) * SOURCE_SCALE
	label.size = Vector2(62, rect.size.y) * SOURCE_SCALE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", SproutTheme.INK)
	label.add_theme_constant_override("line_spacing", 1)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)

func _art(node_name: String, asset: String, source_rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	if not asset.is_empty(): art.texture = load(ART_ROOT + asset + ".png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.position = source_rect.position * SOURCE_SCALE
	art.size = source_rect.size * SOURCE_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	return art

func _make_button(node_name: String, caption: String, source_rect: Rect2, count: int, cost: int) -> Button:
	var button := SproutButton.new()
	button.name = node_name
	button.configure(caption).set_icon_visible(false).set_focus_visual(false)
	add_child(button)
	button.position = source_rect.position * SOURCE_SCALE
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_size_override("font_size", 28)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, SproutTheme.INK)
	button.add_theme_color_override("font_disabled_color", Color("#82786a"))
	button.add_theme_constant_override("outline_size", 0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("#ffe0a0") if count == 10 else Color("#fff2d9")
		if state == "hover": fill = fill.lightened(0.15)
		if state == "pressed": fill = fill.darkened(0.08)
		if state == "disabled": fill = Color("#ded7c9")
		var style := SproutTheme.thin_panel_style(fill)
		style.border_color = Color("#b8ac98") if state == "disabled" else Color("#be8a43")
		style.set_corner_radius_all(26)
		style.set_content_margin_all(0)
		style.shadow_color = Color(0.36, 0.22, 0.09, 0.10 if state == "disabled" else 0.18)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
		button.add_theme_stylebox_override(state, style)
	button.size = source_rect.size * SOURCE_SCALE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#aa7327")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(28)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(_request_summon.bind(count, cost))
	return button

func refresh_balance() -> void:
	if not is_instance_valid(single_button): return
	var current := int(balance_reader.call()) if balance_reader.is_valid() else 0
	if current == _balance: return
	_balance = current
	single_button.disabled = current < SINGLE_COST
	ten_button.disabled = current < TEN_COST
	single_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if single_button.disabled else Control.CURSOR_POINTING_HAND
	ten_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if ten_button.disabled else Control.CURSOR_POINTING_HAND
	single_price.add_theme_color_override("font_color", SHORTAGE_COLOR if single_button.disabled else PRICE_COLOR)
	var price_color := SHORTAGE_COLOR if ten_button.disabled else PRICE_COLOR
	ten_price.text = "[center][color=#%s][s]10000[/s][/color] [color=#%s]9000金币[/color][/center]" % [MUTED_COLOR.to_html(false), price_color.to_html(false)]

func _request_summon(count: int, cost: int) -> void:
	# 在激活边界重读余额，避免金币变化到下一次界面刷新之间的旧状态点击。
	refresh_balance()
	if not is_visible_in_tree() or _balance < cost: return
	summon_requested.emit(count, cost)

func _visibility_changed() -> void:
	if is_visible_in_tree(): refresh_balance()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		refresh_balance()
