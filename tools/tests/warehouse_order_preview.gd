extends "res://tools/tests/restaurant_rest05a.gd"
const Recipes = preload("res://scripts/cooking/recipe_catalog.gd")

func label(text: String, parent: Node, font_size := 16) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",SproutTheme.INK)
	parent.add_child(node)
	return node

func icon(texture: Texture2D, parent: Node, extent := 44) -> void:
	var node := TextureRect.new()
	node.texture = texture
	node.custom_minimum_size = Vector2(extent,extent)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(node)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"预览隔离正式存档")
	if failures==0:
		for missing in [false,true]:
			_seed_cycle()
			sm.data[Lesson.KEY] = {"phase":"done"}
			for id in Recipes.INGREDIENTS: sm.data.warehouse_stock[id] = 8
			sm.data.warehouse_stock.rock_salt = 0 if missing else 6
			await _open_restaurant()
			var w = get_tree().get_first_node_in_group("warehouse_modal")
			w.open_stock()
			w._set_slot(w._slot_by_id.rock_salt,0 if missing else 6,missing,not missing)
			w._selected = {"rockmane_meat":1,"rock_salt":1}
			w._update_selection()
			var outer: VBoxContainer = w._heading.get_parent()
			var requests := VBoxContainer.new()
			requests.add_theme_constant_override("separation",6)
			outer.add_child(requests)
			outer.move_child(requests,1)
			label("当前待制作",requests,18)
			var cards := HBoxContainer.new()
			cards.add_theme_constant_override("separation",10)
			requests.add_child(cards)
			for index in 2:
				var card := PanelContainer.new()
				card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				card.add_theme_stylebox_override("panel",w._box(Color("f5e5c6") if index else Color("e3e8bb"),Color("b5996d") if index else Color("809358"),2,8))
				cards.add_child(card)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation",8)
				card.add_child(row)
				icon(Recipes.item_texture("salt_grilled_rockmane" if index==0 else "slime_candy"),row)
				var text := VBoxContainer.new()
				row.add_child(text)
				label("盐烤岩鬃肉" if index==0 else "史莱姆糖",text,18)
				var customer := HBoxContainer.new()
				text.add_child(customer)
				icon(load("res://assets/ui/character_details/tieshan_portrait_v2.png" if index==0 else "res://assets/ui/character_details/yaya_portrait_v2.png"),customer,24)
				label("待做 2 份" if index==0 else "待做 1 份",customer,14)
			var columns := HBoxContainer.new()
			columns.add_theme_constant_override("separation",16)
			outer.add_child(columns)
			var left := VBoxContainer.new()
			left.custom_minimum_size.x=312
			columns.add_child(left)
			w._tabs.reparent(left)
			w._grid_hover_region.reparent(left)
			var right := VBoxContainer.new()
			right.custom_minimum_size.x=258
			right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			columns.add_child(right)
			w._selected_title.reparent(right)
			label("盐烤岩鬃肉 · 1 份",right,16)
			w._selection_area.reparent(right)
			label("需要 / 库存",right,14)
			label("岩鬃肉    1 / 8",right,15)
			var salt := label("岩盐       1 / 0" if missing else "岩盐       1 / 6",right,15)
			if missing: salt.add_theme_color_override("font_color",Color("a44f3c"))
			label("缺岩盐 ×1" if missing else "已配齐，可领取一份食材",right,15)
			w._claim_button.configure("领取一份食材")
			w._claim_button.disabled=missing
			w._panel.custom_minimum_size.x=620
			await get_tree().process_frame
			w._panel.size=Vector2(620,w._panel.get_combined_minimum_size().y)
			w._panel.position=(w.size-w._panel.size)*0.5
			await get_tree().process_frame
			_check(w._panel.size.x<=get_viewport().get_visible_rect().size.x and w._panel.size.y<=get_viewport().get_visible_rect().size.y,"预览完整显示")
			await _shot("warehouse_order_missing" if missing else "warehouse_order_ready")
			await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
