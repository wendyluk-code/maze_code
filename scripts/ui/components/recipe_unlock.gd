extends ColorRect
## 第一章菜谱解锁蒙层；业务状态由餐厅 HUD/SaveManager 管理。
signal closed
const ContinuePrompt := preload("res://scripts/ui/components/continue_prompt.gd")
const ModalStyle := preload("res://scripts/ui/components/modal_style.gd")
var _prompt: Control
var _icon: TextureRect
var _closing := false
var _released := false
var _target: Button
var _center: Control
var _tween: Tween
var _flying: TextureRect
static var _texture: ImageTexture

static func entry_texture() -> Texture2D:
	if _texture == null:
		var image := preload("res://assets/ui/items/recipe_book_original.png").get_image()
		image.generate_mipmaps()
		_texture = ImageTexture.create_from_image(image)
	return _texture

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = ModalStyle.BACKDROP
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
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.custom_minimum_size.x = 300
	title.text = "[center]解锁[color=#e8ba62]【菜谱】[/color][/center]"
	title.theme = SproutTheme.make_theme()
	title.add_theme_font_size_override("normal_font_size", 32)
	title.add_theme_color_override("default_color", SproutTheme.CREAM)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	_icon = TextureRect.new()
	_icon.texture = entry_texture()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.custom_minimum_size = Vector2(112, 112)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_icon)
	_prompt = ContinuePrompt.new()
	add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -84
	_prompt.offset_bottom = -40
	hide()

func present(target: Button) -> void:
	if visible or _closing: return
	_target = target
	_target.hide()
	self_modulate.a = 1.0
	_center.modulate.a = 1.0
	_prompt.modulate.a = 1.0
	_icon.show()
	_released = not Input.is_physical_key_pressed(KEY_E)
	show()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()
	if event is InputEventKey:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			if not event.pressed: _released = true
			elif not event.echo and _released: close()
	get_viewport().set_input_as_handled()

func close() -> void:
	if _closing or not visible or not is_instance_valid(_target): return
	_closing = true
	_flying = TextureRect.new()
	_flying.texture = entry_texture()
	_flying.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flying.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flying)
	_flying.position = _icon.global_position - global_position
	_flying.size = _icon.size
	_icon.hide()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "self_modulate:a", 0.0, 0.48)
	_tween.tween_property(_center, "modulate:a", 0.0, 0.2)
	_tween.tween_property(_prompt, "modulate:a", 0.0, 0.2)
	_tween.tween_property(_flying, "position", _target.get_global_rect().get_center() - global_position - Vector2(28,28), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_flying, "size", Vector2(56,56), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(func():
		_flying.queue_free()
		_flying = null
		_closing = false
		hide()
		_target.show()
		closed.emit())

func _exit_tree() -> void:
	if _tween != null: _tween.kill()

