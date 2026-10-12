extends HBoxContainer
## 共用继续提示：文字与用户指定的 E 键素材分开排版。

static func key_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/ui/continue_key_e.png")
	texture.region = Rect2(184, 134, 954, 928)
	texture.filter_clip = true
	return texture

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 9)
	theme = SproutTheme.make_theme()
	add_child(_text("按"))
	var icon := TextureRect.new()
	icon.name = "ContinueKeyIcon"
	icon.texture = key_texture()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	add_child(_text("继续"))

func _text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("eee8d8"))
	label.add_theme_color_override("font_outline_color", Color("302b24"))
	label.add_theme_constant_override("outline_size", 3)
	return label
