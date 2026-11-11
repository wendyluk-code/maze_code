extends "res://tools/tests/first_exploration.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离三种结算预览，不修改正式存档")
	if failures == 0:
		var background := TextureRect.new()
		background.texture = load("res://assets/maps/restaurant_map.png")
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(background)
		var cases := [
			{"file":"capture_only", "items":{"brick_snail_meat":1,"slime_gel":1,"slime_shell":1,"sword_beetle_leg":1}},
			{"file":"task_only", "items":{"cooking_sake":3,"moondew_honey":3,"sour_vine_juice":3}},
			{"file":"empty", "items":{}}
		]
		for example in cases:
			var preview := preload("res://scripts/ui/components/restaurant_day_loot.gd").new()
			add_child(preview)
			sm.data["restaurant_day_v1"] = {}
			preview.show_loot(example.items)
			if example.items.is_empty():
				var message := Label.new()
				message.text = "本次探索未带回食材"
				message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				message.add_theme_font_size_override("font_size", 22)
				message.add_theme_color_override("font_color", SproutTheme.INK_MUTED)
				preview._grid.add_child(message)
			await get_tree().create_timer(0.2).timeout
			var content_height := clampf(preview._grid.get_combined_minimum_size().y, 64.0, 350.0)
			preview._scroll.custom_minimum_size.y = content_height
			preview._content_center.custom_minimum_size.y = content_height
			preview._panel.custom_minimum_size.y = 0
			await get_tree().process_frame
			var panel_height: float = preview._panel.get_combined_minimum_size().y
			preview._panel.offset_top = -panel_height / 2.0
			preview._panel.offset_bottom = panel_height / 2.0
			preview._panel.size.y = panel_height
			await get_tree().create_timer(0.2).timeout
			await _shot_gate(example.file)
			preview.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
