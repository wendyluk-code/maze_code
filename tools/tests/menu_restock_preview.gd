extends "res://tools/tests/restaurant_rest05b.gd"
func label_at(parent: Control, text: String, rect: Rect2, font_size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"预览隔离存档")
	get_window().size = Vector2i(1152,648)
	_fresh()
	sm.data.warehouse_stock = {}
	var hud = await _open_restaurant()
	hud._open_day_menu()
	await get_tree().create_timer(0.2).timeout
	var modal = hud.day_menu
	var panel = modal.empty_panel.get_parent().get_parent()
	panel.get_child(0).hide()
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(764,430)
	panel.add_child(canvas)
	label_at(canvas,"今日可做菜单",Rect2(0,0,764,34),24).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_at(canvas,"第 2 天",Rect2(0,36,764,24),16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var empty := Panel.new()
	empty.position = Vector2(0,70)
	empty.size = Vector2(764,48)
	empty.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style())
	canvas.add_child(empty)
	var empty_title := label_at(empty,"暂无可做料理",Rect2(0,0,764,48),18)
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_at(canvas,"建议补充",Rect2(0,124,180,26),18)
	var rows := [["slime_candy","slime_shell","枯水渠 · 捕获史莱姆"],["brick_snail_sashimi","brick_snail_meat","枯水渠 · 捕获砖壳蜗牛"],["lizard_tail_skewer","petrifying_lizard_tail","枯水渠 · 捕获石化蜥蜴"]]
	var book := preload("res://scripts/ui/components/recipe_book_panel.gd").new()
	modal.add_child(book)
	book.panel.hide()
	for child in book.get_children():
		if child is ColorRect: child.hide()
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var first_missing: Button
	var shared := Panel.new()
	shared.position = Vector2(0,154)
	shared.size = Vector2(764,228)
	shared.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style())
	canvas.add_child(shared)
	for i in rows.size():
		var row := Panel.new()
		row.position = Vector2(0,154+i*72)
		row.size = Vector2(764,70)
		row.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		canvas.add_child(row)
		var icon = modal._icon(rows[i][0],42)
		icon.position = Vector2(12,14)
		row.add_child(icon)
		label_at(row,Recipe.get_recipe(rows[i][0]).name,Rect2(66,23,230,28),18)
		var j := 0
		for id in Recipe.get_recipe(rows[i][0]).ingredients:
			var slot := SproutItemSlot.new()
			slot.set_grid_mode(true)
			slot.configure(id,Recipe.get_ingredient(id).name,1,0)
			slot.set_icon_texture(preload("res://scripts/ui/components/bag_icon_display.gd").texture(Recipe.item_texture(id)))
			var missing: bool = id==rows[i][1]
			if missing: slot.source_background = Color("c9cac5")
			row.add_child(slot)
			slot.scale = Vector2(0.75,0.75)
			slot.position = Vector2(354+j*184,11)
			var text := label_at(row,Recipe.get_ingredient(id).name+" ×1",Rect2(300+j*184,54,150,22),15)
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if missing:
				var badge := label_at(slot,"缺",Rect2(41,-2,22,22),16)
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				badge.add_theme_color_override("font_color",Color("874b3c"))
				if i==0: first_missing = slot._icon_button
			var source: String = str(rows[i][2]).replace(" ","") if missing else str(Recipe.get_ingredient(id).get("source","任务奖励"))
			book.bind_hint(slot._icon_button,Recipe.get_ingredient(id).name+"\n获取方式："+source)
			j += 1
	var later := Button.new()
	later.text = "稍后"
	later.position = Vector2(440,390)
	later.size = Vector2(150,38)
	canvas.add_child(later)
	var begin := Button.new()
	begin.text = "开始营业"
	begin.disabled = true
	begin.position = Vector2(598,390)
	begin.size = Vector2(166,38)
	canvas.add_child(begin)
	await get_tree().create_timer(0.2).timeout
	await _shot("restock_preview")
	book.show_hint(first_missing,"史莱姆核\n获取方式：枯水渠·捕获史莱姆")
	await _shot("restock_hover")
	await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)







