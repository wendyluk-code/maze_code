extends "res://tools/tests/first_exploration.gd"
var preview: Control

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离预览")
	if failures == 0:
		var background := TextureRect.new()
		background.texture = load("res://assets/maps/restaurant_map.png")
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(background)
		preview = preload("res://scripts/ui/warehouse_modal.gd").new()
		add_child(preview)
		await get_tree().process_frame
		# 演示获取顺序：捕获、任务奖励、再次捕获；只用于效果预览。
		var stock := {"slime_shell":1,"slime_gel":3,"moondew_honey":3,"cooking_sake":3,"sour_vine_juice":3,"brick_snail_meat":3,"petrifying_lizard_tail":1}
		var quest_ids := ["moondew_honey","cooking_sake","sour_vine_juice"]
		preview.open_backpack(stock,true)
		preview._tabs.hide()
		preview._message.hide()
		var legend := VBoxContainer.new()
		legend.add_theme_constant_override("separation", 6)
		var outer: Node = preview._message.get_parent()
		outer.add_child(legend)
		outer.move_child(legend,preview._message.get_index())
		for i in 2:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			legend.add_child(row)
			var swatch := PanelContainer.new()
			swatch.custom_minimum_size = Vector2(30,16)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			swatch.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style(Color("d9eaf1") if i == 0 else Color("dfead3")))
			row.add_child(swatch)
			var label := Label.new()
			label.text = "捕获食材：捕获魔物获得的食材，\n放弃探索或战败将失去" if i == 0 else "任务食材：完成任务获得的食材，\n离开迷宫时将自动带回餐厅"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.add_theme_font_size_override("font_size",15)
			label.add_theme_color_override("font_color",SproutTheme.INK_MUTED)
			row.add_child(label)
		for index in stock.size():
			preview._slots_grid.move_child(preview._slot_by_id[stock.keys()[index]],index)
		await get_tree().process_frame
		preview._panel.size.y = preview._panel.get_combined_minimum_size().y
		preview._panel.position = (preview.size-preview._panel.size)*0.5
		await get_tree().process_frame
		for slot in preview._slots_grid.get_children():
			if slot is SproutItemSlot and stock.has(slot.item_id):
				var style := SproutTheme.thin_panel_style(Color("dfead3") if slot.item_id in quest_ids else Color("d9eaf1"))
				for state in ["normal","disabled","hover","pressed"]:
					slot._icon_button.add_theme_stylebox_override(state,style)
		await _shot_gate("backpack_mixed")
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
