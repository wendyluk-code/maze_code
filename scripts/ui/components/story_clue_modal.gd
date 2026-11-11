extends "res://scripts/ui/components/loot_modal.gd"
## 复用宝箱面板与输入处理，只展示线索，不执行物品领取。
const CLUE_ICON := preload("res://assets/props/story_clue/cracked_stone.png")

func _build() -> void:
	super._build()
	_scroll.hide()
	var outer := _body_label.get_parent()
	outer.add_theme_constant_override("separation", 12)
	var center := CenterContainer.new()
	outer.add_child(center)
	outer.move_child(center, 1)
	var icon := TextureRect.new()
	icon.texture = display_texture(CLUE_ICON)
	icon.custom_minimum_size = Vector2(96, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	center.add_child(icon)
	_body_label.show()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var text_margin := MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left", 30)
	text_margin.add_theme_constant_override("margin_right", 30)
	outer.remove_child(_body_label)
	outer.add_child(text_margin)
	outer.move_child(text_margin, 2)
	text_margin.add_child(_body_label)
	_body_label.custom_minimum_size = Vector2(392, 0)
	_body_label.size_flags_vertical = Control.SIZE_FILL
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.add_theme_font_size_override("font_size", 18)
	_panel.custom_minimum_size = Vector2(500, 270)
	_panel.offset_left = -250
	_panel.offset_top = -135
	_panel.offset_right = 250
	_panel.offset_bottom = 135

func show_modal(title_text: String, body_text: String, confirm_text := "确认") -> void:
	super.show_modal(title_text, "　　" + body_text.strip_edges(), confirm_text)
