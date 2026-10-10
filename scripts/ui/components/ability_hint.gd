extends CanvasLayer
## 原生文字能力说明，复用于图片角色卡与数据卡牌。
const COOKING_DESCRIPTION := "使用带“烹饪”能力的牌会获得一张「食材」牌；若手牌已有另外两张「食材」，三张会自动合成一张「佳肴」。"
var card: Control
var enabled := false
var ability_text := ""
var panel: PanelContainer
var description: Label
var _mouse := Vector2(-1, -1)

func _ready() -> void:
	layer = 95
	panel = PanelContainer.new()
	panel.theme = SproutTheme.make_theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff4dc")
	style.border_color = SproutTheme.INK_MUTED
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var title := Label.new()
	title.text = "烹饪"
	title.add_theme_font_size_override("font_size", 23)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	description = Label.new()
	description.text = COOKING_DESCRIPTION
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description)
	panel.hide()
	get_viewport().mouse_exited.connect(func():
		_mouse = Vector2(-1, -1)
		dismiss())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position

func dismiss() -> void:
	if is_instance_valid(panel):
		panel.hide()

func _process(_delta: float) -> void:
	if not enabled or not ability_text.contains("烹饪") or not is_instance_valid(card) or not card.is_visible_in_tree():
		dismiss()
		return
	var pointer := _mouse
	var local := card.get_global_transform_with_canvas().affine_inverse() * pointer
	if not Rect2(Vector2.ZERO, card.size).has_point(local):
		dismiss()
		return
	# 四边裁剪时，屏幕外或滚动窗口外的卡片区域不算悬停。
	var ancestor := card.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(pointer):
			dismiss()
			return
		ancestor = ancestor.get_parent()
	var viewport_size := card.get_viewport_rect().size
	var width := minf(320, viewport_size.x - 32)
	description.custom_minimum_size.x = width - 32
	panel.size = Vector2(width, 0)
	panel.reset_size()
	var mouse := _mouse
	var position := mouse + Vector2(20, 18)
	if position.x + panel.size.x > viewport_size.x - 16:
		position.x = mouse.x - panel.size.x - 20
	# 下方留出按 E 继续的固定提示区。
	position.x = clampf(position.x, 16, maxf(16, viewport_size.x - panel.size.x - 16))
	position.y = clampf(position.y, 16, maxf(16, viewport_size.y - panel.size.y - 86))
	panel.position = position
	panel.show()
