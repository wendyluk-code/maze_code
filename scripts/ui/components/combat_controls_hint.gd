extends Control
## 只局部适配战斗提示；餐厅键帽资源及其他实例不变。
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	custom_minimum_size=Vector2(348,48)
	var hint := preload("res://scenes/ui/interact_button.tscn").instantiate()
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := hint.get_node("Content") as HBoxContainer
	content.alignment=BoxContainer.ALIGNMENT_CENTER
	content.offset_left=12
	content.offset_right=-12
	content.offset_top=-1
	content.offset_bottom=-1
	content.add_theme_constant_override("separation",8)
	var template := content.get_node("ActionLabel").duplicate() as Label
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for pair in [["左键","攻击"],["Tab","切换"],["Shift","加速"]]:
		var key := preload("res://scenes/ui/key_button.tscn").instantiate()
		content.add_child(key)
		_style_key(key,pair[0])
		var caption := template.duplicate() as Label
		caption.text=pair[1]
		caption.custom_minimum_size.x=42
		content.add_child(caption)
	template.free()

func _style_key(key: Control, caption: String) -> void:
	key.custom_minimum_size=Vector2(44,28)
	key.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var icon := key.get_node("KeyIcon") as TextureRect
	var cropped := AtlasTexture.new()
	cropped.atlas=preload("res://assets/ui/key_square26_frame0.png")
	cropped.region=Rect2(11,11,26,28)
	icon.texture=cropped
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_SCALE
	var label := key.get_node("KeyIcon/KeyLabel") as Label
	label.text=caption
	label.add_theme_font_override("font",ThemeDB.fallback_font if caption in ["Shift","Tab"] else SproutTheme.FONT_CN)
	label.add_theme_font_size_override("font_size",14)
