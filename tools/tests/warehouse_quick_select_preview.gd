extends "res://tools/tests/warehouse_order_preview.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"预览隔离正式存档")
	if failures==0:
		_seed_cycle()
		sm.data[Lesson.KEY] = {"phase":"done"}
		for id in Recipes.INGREDIENTS: sm.data.warehouse_stock[id] = 8
		await _open_restaurant()
		var w = get_tree().get_first_node_in_group("warehouse_modal")
		w.open_stock()
		var outer: VBoxContainer = w._heading.get_parent()
		var quick := HBoxContainer.new()
		quick.add_theme_constant_override("separation",8)
		var quick_background := PanelContainer.new()
		quick_background.add_theme_stylebox_override("panel",w._box(Color("f5e5c6"),Color("d4b986"),1,6))
		outer.add_child(quick_background)
		outer.move_child(quick_background,w._grid_hover_region.get_index()+1)
		quick_background.add_child(quick)
		var quick_label := label("快速选择",quick,w._selected_title.get_theme_font_size("font_size"))
		quick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tiles: Array = []
		for id in ["salt_grilled_rockmane","slime_candy","brick_snail_sashimi"]:
			var tile := PanelContainer.new()
			tile.custom_minimum_size = Vector2(56,56)
			tile.tooltip_text = Recipes.get_recipe(id).name
			tile.add_theme_stylebox_override("panel",w._box(Color("e1c99e"),Color("b5996d"),1,6))
			quick.add_child(tile)
			icon(preload("res://scripts/ui/components/bag_icon_display.gd").texture(Recipes.item_texture(id)),tile,40)
			tiles.append(tile)
		for selected in [false,true]:
			if selected:
				w._selected = Recipes.get_recipe("salt_grilled_rockmane").ingredients.duplicate()
				for id in w._slot_by_id:
					w._slot_by_id[id].set_selected_quantity(int(w._selected.get(id,0)))
				w._update_selection()
				tiles[0].add_theme_stylebox_override("panel",w._box(Color("dbe4b1"),Color("809358"),2,6))
			await get_tree().process_frame
			w._layout_modal()
			await get_tree().process_frame
			_check(quick.get_child_count()==4,"最多三个快速选择料理格")
			_check(w._panel.size.y<=get_viewport().get_visible_rect().size.y,"保留原宽度且面板完整显示")
			await _shot("quick_select_selected" if selected else "quick_select_default")
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
