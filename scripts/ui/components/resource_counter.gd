extends HBoxContainer
## 只展示图标与数值；业务资格、位置和画布归属由调用方决定。
const GOLD: Texture2D = preload("res://assets/ui/hud_currency/gold.png")
const REPUTATION: Texture2D = preload("res://assets/ui/hud_currency/reputation.png")
var icon: TextureRect
var value_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SproutTheme.make_theme()
	add_theme_constant_override("separation", 6)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	value_label = Label.new()
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", SproutTheme.CREAM)
	value_label.add_theme_color_override("font_outline_color", SproutTheme.INK)
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.08, 0.04, 0.55))
	value_label.add_theme_constant_override("shadow_offset_x", 1)
	value_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(value_label)

func configure(texture: Texture2D) -> void:
	icon.texture = texture

func set_value(value: int) -> void:
	var next := str(value)
	if value_label.text != next:
		value_label.text = next
		reset_size()
