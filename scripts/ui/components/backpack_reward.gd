extends ColorRect
## 获得背包展示，输入由老者剧情生命周期管理，不执行发奖事务。
signal collected
var custom_texture: Texture2D
var custom_title := ""
var title: RichTextLabel
var item_icon: TextureRect
var _center: CenterContainer
var _collect_tween: Tween
var _flying_icon: TextureRect
const ContinuePrompt := preload("res://scripts/ui/components/continue_prompt.gd")

static var _entry_texture: ImageTexture

static func entry_texture() -> Texture2D:
	if _entry_texture == null:
		var image := preload("res://assets/ui/items/magic_backpack_entry.png").get_image()
		image.generate_mipmaps()
		_entry_texture = ImageTexture.create_from_image(image)
	return _entry_texture

static func backpack_texture() -> Texture2D:
	return entry_texture()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	_center = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	title = RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.custom_minimum_size.x = 260
	title.text = "[center]解锁[color=#e8ba62]【背包】[/color][/center]"
	if not custom_title.is_empty(): title.text = custom_title
	title.theme = SproutTheme.make_theme()
	title.add_theme_font_size_override("normal_font_size", 32)
	title.add_theme_color_override("default_color", SproutTheme.CREAM)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var icon := TextureRect.new()
	item_icon = icon
	icon.texture = custom_texture if custom_texture != null else backpack_texture()
	icon.custom_minimum_size = Vector2(112, 112)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var prompt := ContinuePrompt.new()
	prompt.name = "ContinuePrompt"
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -84
	prompt.offset_bottom = -40
	hide()

func collect_into(entry: Button) -> void:
	if _collect_tween != null: return
	var start := item_icon.get_global_rect()
	var target := entry.get_global_rect()
	_flying_icon = TextureRect.new()
	_flying_icon.texture = custom_texture if custom_texture != null else backpack_texture()
	_flying_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flying_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flying_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_flying_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flying_icon)
	_flying_icon.position = start.position - global_position
	_flying_icon.size = start.size
	item_icon.hide()
	entry.modulate.a = 0.0
	_collect_tween = create_tween().set_parallel(true)
	_collect_tween.tween_property(self, "self_modulate:a", 0.0, 0.48)
	_collect_tween.tween_property(_center, "modulate:a", 0.0, 0.2)
	_collect_tween.tween_property(get_node("ContinuePrompt"), "modulate:a", 0.0, 0.15)
	_collect_tween.tween_property(_flying_icon, "position", target.get_center() - Vector2(28,28) - global_position, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_collect_tween.tween_property(_flying_icon, "size", Vector2(56,56), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_collect_tween.tween_property(_flying_icon, "modulate:a", 0.0, 0.12).set_delay(0.36)
	_collect_tween.tween_property(entry, "modulate:a", 1.0, 0.18).set_delay(0.3)
	_collect_tween.chain().tween_callback(func():
		_collect_tween = null
		_flying_icon.queue_free()
		_flying_icon = null
		collected.emit())

func _exit_tree() -> void:
	if _collect_tween != null: _collect_tween.kill()
