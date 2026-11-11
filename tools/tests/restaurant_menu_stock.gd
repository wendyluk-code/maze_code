extends "res://tools/tests/restaurant_day_r1.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_completed()
		sm.data.unlocked_recipe_ids = ["salt_grilled_rockmane", "slime_candy", "brick_snail_sashimi", "lizard_tail_skewer", "mimic_crab_gratin", "scorpion_lotus_fritters"]
		scene = RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(1.0).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var menu = hud.day_menu
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			sm.data.warehouse_stock = {"rockmane_meat": 5, "rock_salt": 3}
			sm.data[Day.KEY] = {"protection": {"rock_salt": 1}}
			menu.open()
			await get_tree().process_frame
			_check(menu.list.get_child_count() == 1, "只显示当前食材能做的料理")
			await _click(menu.list.get_node("Recipe_salt_grilled_rockmane/RecipeRow/Selected"))
			await _click(menu.list.get_node("Recipe_salt_grilled_rockmane/RecipeRow/Increase"))
			_check(menu.draft.get("salt_grilled_rockmane") == 2 and not menu.list.get_node("Recipe_salt_grilled_rockmane/RecipeRow/Increase").disabled, "旧保护数量不减少可用份数")
			_check(Day.validate_menu(sm, menu.draft).success and not menu.confirm_button.disabled, "可选份数始终可提交")
			sm.data.warehouse_stock.rock_salt = 0
			menu._rebuild()
			_check(menu.draft.is_empty() and menu.confirm_button.disabled, "库存减少时清除无效草稿并禁用营业")
			sm.data[Day.KEY] = {}
			var stock := {}
			for id in sm.unlocked_recipe_ids():
				for item in menu.Recipes.get_recipe(id).ingredients: stock[item] = 20
			sm.data.warehouse_stock = stock
			menu.open()
			await get_tree().create_timer(0.2).timeout
			var row = menu.list.get_child(0).get_node("RecipeRow")
			var price = row.get_node("Price")
			var header = menu.headers[2]
			_check(header.text == "每份售价" and absf(header.global_position.x + header.size.x / 2 - price.global_position.x - price.size.x / 2) < 2, "每份售价标题居中对齐价格列")
			var plus = row.get_node("Increase")
			_check(absf(plus.global_position.x + plus.size.x - row.global_position.x - row.size.x) < 2, "份数组件整体靠右")
			_check(menu.scroll.get_v_scroll_bar().max_value > menu.scroll.get_v_scroll_bar().page, "足量多菜支持滚动")
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "menu_stock_%dx%d" % [resolution.x,resolution.y])
			menu.close()
	var report := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	get_tree().quit(1 if failures else 0)
