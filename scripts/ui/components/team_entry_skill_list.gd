extends VBoxContainer
## 技能正文逐项自适应换行，分隔线属于布局而非文字占位。
var text := ""
var _entries := PackedStringArray()

func set_entries(entries: PackedStringArray) -> void:
	if _entries == entries and get_child_count() > 0: return
	_entries = entries.duplicate()
	text = "\n\n".join(entries) if not entries.is_empty() else "选择角色后显示已解锁技能"
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var values := entries if not entries.is_empty() else PackedStringArray([text])
	for i in values.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Color("#dfcba5")
			line.custom_minimum_size.y = 1
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(line)
		var label := RichTextLabel.new()
		label.fit_content = true
		label.scroll_active = false
		label.bbcode_enabled = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("normal_font_size", 18)
		label.add_theme_color_override("default_color", SproutTheme.INK_MUTED)
		label.add_theme_constant_override("line_separation", 4)
		label.text = values[i]
		add_child(label)
	add_theme_constant_override("separation", 16)
