extends "res://tools/tests/restaurant_rest05b.gd"
const Sources := preload("res://scripts/cooking/ingredient_sources.gd")
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_fresh()
	sm.data.warehouse_stock = {"moondew_honey":2,"cooking_sake":1,"sour_vine_juice":1}
	sm.data.restaurant_explored_regions = ["maze_entry"]
	sm.data.restaurant_last_region = "maze_entry"
	var suggestions := Sources.suggestions(sm)
	_check(suggestions.size()==3,"现有调味料推荐三个首区配方")
	_check(not suggestions.any(func(v): return v.id=="salt_grilled_rockmane"),"未探索分水庭时不跨两区推荐盐池")
	sm.data.restaurant_explored_regions = ["maze_entry","fenshui"]
	sm.data.restaurant_last_region = "fenshui"
	sm.data.warehouse_stock = {"canal_lotus_root":1}
	_check(Sources.suggestions(sm).any(func(v): return v.id=="scorpion_lotus_fritters"),"下一地区盐池食材可推荐")
	_check(Sources.description("rockmane_meat")=="盐池·捕获岩鬃兽" and Sources.description("rock_salt")=="盐池·开采盐晶","来源为实际区域与行为")
	var before: Dictionary = sm.data.duplicate(true)
	_check(sm.record_maze_location("fenshui",sm.maze_terrain("fenshui").SPAWN).success,"实际区域保存事务记录到访")
	_check(sm.data.restaurant_last_region=="fenshui" and "fenshui" in sm.data.restaurant_explored_regions,"记录当前区域及永久探索范围")
	var saved: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not sm.record_maze_location("salt_pool",sm.maze_terrain("salt_pool").SPAWN).success and sm.data==saved,"区域保存失败不扩张推荐范围")
	sm._active_save_path = path
	sm.data = before
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		sm.data.warehouse_stock = {"moondew_honey":2,"cooking_sake":1,"sour_vine_juice":1}
		var hud = await _open_restaurant()
		hud._open_day_menu()
		await get_tree().create_timer(0.25).timeout
		var menu = hud.day_menu
		_check(menu.restock.visible and menu.restock.items.size()==3,"真实菜单显示建议")
		_check(menu.empty_panel.size.y==48,"空提示高度保持48像素")
		await _shot("restock")
		var rows = menu.restock.get_child(2).get_child(0)
		var slot = rows.get_child(0).get_child(2).get_child(0)
		_check(slot.source_background==Color("c9cac5"),"缺料灰底")
		slot._icon_button.mouse_entered.emit()
		await get_tree().process_frame
		_check(menu.restock.book.hint.visible and menu.restock.book.hint_text.text.contains("捕获"),"实际hover具体获取途径")
		await _shot("restock_hover")
		menu.close()
		_check(not menu.restock.book.hint.visible and not scene.get_node("Player").input_locked,"关闭清理提示与输入锁")
		hud._recipe_book.set_recipes(hud._recipe_data())
		hud._recipe_book.show()
		var target = hud._recipe_book.ingredient_targets[0]
		target.mouse_entered.emit()
		_check(hud._recipe_book.hint_text.text=="获取方式：盐池·捕获岩鬃兽","食谱页同步复用实际来源")
		hud._recipe_book.hide()
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
